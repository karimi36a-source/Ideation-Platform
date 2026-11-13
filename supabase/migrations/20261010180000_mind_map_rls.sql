begin;
-- Normalized map access is narrower than an exact submitted-Version review
-- exception: reviewing a Version never grants the whole private map/room.
create function public.can_read_mind_map(target_map uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.mind_maps m
 join public.artifacts b on b.id=m.artifact_id and b.artifact_type='MIND_MAP'
 join public.development_projects p on p.id=b.project_id and p.primary_workspace_id=b.workspace_id
 join public.artifact_versions v on v.id=m.artifact_version_id and v.artifact_id=b.id
 where m.id=target_map and b.status='ACTIVE' and b.archived_at is null
 and public.can_read_private_mind_map(b.id)
 and private.mind_map_scope_allowed(b.workspace_id,false)
 and (b.activity_instance_id is null or exists(select 1 from public.activity_instances a
  where a.id=b.activity_instance_id and (a.project_id,a.workspace_id)=(b.project_id,b.workspace_id)
  and public.can_read_activity_instance(a.id))));
$$;
-- Internal compatibility predicate only. Its callers must first authorize the
-- owning map. Exact equal Project/Workspace IDs inherit that already-verified
-- Project access; do not repeat the full role/membership graph per node.
create function private.mind_map_source_compatible(target_node uuid) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from public.mind_map_nodes n join public.mind_maps m on m.id=n.mind_map_id
 join public.artifacts b on b.id=m.artifact_id where n.id=target_node
 and (n.development_object_id is null or exists(select 1 from public.development_objects o
  where o.id=n.development_object_id and (o.project_id,o.workspace_id)=(b.project_id,b.workspace_id))));
$$;
revoke all on function private.mind_map_source_compatible(uuid) from public,anon,authenticated,service_role;
create function public.can_read_mind_map_node(target_node uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.mind_map_nodes n where n.id=target_node
 and public.can_read_mind_map(n.mind_map_id) and private.mind_map_source_compatible(n.id));
$$;
create function public.can_read_mind_map_edge(target_edge uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.mind_map_edges e
 join public.mind_map_nodes s on s.id=e.source_node_id and s.mind_map_id=e.mind_map_id
 join public.mind_map_nodes t on t.id=e.target_node_id and t.mind_map_id=e.mind_map_id
 where e.id=target_edge and public.can_read_mind_map(e.mind_map_id)
 and private.mind_map_source_compatible(s.id) and private.mind_map_source_compatible(t.id));
$$;
revoke all on function public.can_read_mind_map(uuid),public.can_read_mind_map_node(uuid),public.can_read_mind_map_edge(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_mind_map(uuid),public.can_read_mind_map_node(uuid),public.can_read_mind_map_edge(uuid) to authenticated;
do $$declare t text;predicate text;begin
 foreach t in array array['mind_maps','mind_map_nodes','mind_map_edges'] loop
  predicate:=case t when 'mind_maps' then 'can_read_mind_map' when 'mind_map_nodes' then 'can_read_mind_map_node' else 'can_read_mind_map_edge' end;
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('drop policy %I on public.%I',t||'_client_deny',t);
  execute format('create policy %I on public.%I for select to authenticated using(public.%I(id))',t||'_scoped_read',t,predicate);
  execute format('create policy %I on public.%I as restrictive for select to authenticated using(public.%I(id))',t||'_read_guard',t,predicate);
  execute format('create policy %I on public.%I as restrictive for insert to authenticated with check(false)',t||'_insert_deny',t);
  execute format('create policy %I on public.%I as restrictive for update to authenticated using(false) with check(false)',t||'_update_deny',t);
  execute format('create policy %I on public.%I as restrictive for delete to authenticated using(false)',t||'_delete_deny',t);
  execute format('create policy %I on public.%I as restrictive for all to anon using(false) with check(false)',t||'_anon_deny',t);
 end loop;
end $$;
comment on table public.mind_maps is 'Canonical Artifact/Version-bound map. Current private scope authorizes reads of current/historical maps; mutations use validated RPCs only.';
-- Definer reads must enforce the same source guard as direct RLS.
create or replace function public.get_mind_map_editor(target_activity uuid) returns jsonb
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
 select mm.* into m from public.mind_maps mm join public.artifact_versions vv on vv.id=mm.artifact_version_id where mm.artifact_id=b.id order by vv.version_number desc limit 1;
 select * into v from public.artifact_versions where id=m.artifact_version_id and artifact_id=b.id;
 if not public.can_read_mind_map(m.id) or not private.mind_map_scope_allowed(b.workspace_id,false) or a.id is null or b.id is null or m.id is null or v.id is null or b.status<>'ACTIVE' or b.archived_at is not null
 or (b.project_id,b.workspace_id) is distinct from (a.project_id,a.workspace_id)
 or not exists(select 1 from public.mind_map_nodes n where n.id=m.root_node_id and n.mind_map_id=m.id and n.node_type='CENTRAL_INVENTION')
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 begin perform private.require_mind_map_node_edit(m.id); editable:=true;
 exception when others then editable:=false;end;
 if not public.can_read_activity_instance(a.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 return jsonb_build_object(
  'mindMap',to_jsonb(m),'nodes',coalesce((select jsonb_agg(to_jsonb(n)||jsonb_build_object('product_classification',case when n.development_object_id is null then n.product_classification else (select o.product_classification from public.development_objects o where o.id=n.development_object_id) end) order by n.id) from public.mind_map_nodes n where n.mind_map_id=m.id and private.mind_map_source_compatible(n.id)),'[]'::jsonb),
  'edges',coalesce((select jsonb_agg(to_jsonb(e) order by e.id) from public.mind_map_edges e where e.mind_map_id=m.id and private.mind_map_source_compatible(e.source_node_id) and private.mind_map_source_compatible(e.target_node_id)),'[]'::jsonb),
  'objects',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'object_type',o.object_type,'title',o.title,'product_classification',o.product_classification,'classification_revision',o.classification_revision) order by o.object_type,o.title,o.id)
   from public.development_objects o where o.project_id=a.project_id and o.workspace_id=a.workspace_id and o.archived_at is null
   and o.object_type::text in('SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP') and public.can_read_development_project(o.project_id)),'[]'::jsonb),
  'editable',editable);
end $$;
commit;
