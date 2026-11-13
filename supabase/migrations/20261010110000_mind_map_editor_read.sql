begin;

create function public.get_mind_map_editor(target_activity uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id(); a public.activity_instances;
 b public.artifacts; v public.artifact_versions; m public.mind_maps; editable boolean:=false;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';
 end if;
 if target_activity is null or not public.can_read_activity_instance(target_activity) then
  raise exception 'Resource unavailable' using errcode='42501';
 end if;
 select * into a from public.activity_instances where id=target_activity;
 select * into b from public.artifacts where activity_instance_id=a.id and artifact_type='MIND_MAP';
 select * into m from public.mind_maps where artifact_id=b.id;
 select * into v from public.artifact_versions where id=m.artifact_version_id and artifact_id=b.id;
 if a.id is null or b.id is null or m.id is null or v.id is null or b.status<>'ACTIVE' or b.archived_at is not null
 or (b.project_id,b.workspace_id) is distinct from (a.project_id,a.workspace_id)
 or not exists(select 1 from public.mind_map_nodes n where n.id=m.root_node_id and n.mind_map_id=m.id and n.node_type='CENTRAL_INVENTION')
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 begin perform private.require_mind_map_node_edit(m.id); editable:=true;
 exception when others then editable:=false;end;
 if not public.can_read_activity_instance(a.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 return jsonb_build_object(
  'mindMap',to_jsonb(m),'nodes',coalesce((select jsonb_agg(to_jsonb(n) order by n.id) from public.mind_map_nodes n where n.mind_map_id=m.id),'[]'::jsonb),
  'edges',coalesce((select jsonb_agg(to_jsonb(e) order by e.id) from public.mind_map_edges e where e.mind_map_id=m.id),'[]'::jsonb),
  'objects',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'object_type',o.object_type,'title',o.title) order by o.object_type,o.title,o.id)
   from public.development_objects o where o.project_id=a.project_id and o.workspace_id=a.workspace_id and o.archived_at is null
   and o.object_type::text in('SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP') and public.can_read_development_project(o.project_id)),'[]'::jsonb),
  'editable',editable);
end $$;

revoke all on function public.get_mind_map_editor(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_mind_map_editor(uuid) to authenticated;
comment on function public.get_mind_map_editor(uuid) is 'M11.12 authorized Activity-scoped normalized Mind Map UI payload. Safe Object labels/types only; current write state is server-derived.';
commit;
