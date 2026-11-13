begin;
-- Read-only projection. No new source authority, writes, context or provider use.
create function public.resolve_activity_ai_configuration(target_instance uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.activity_instances;d public.activity_definitions;proof boolean:=false;rule0 jsonb;ni numeric;no0 numeric;
begin
 if public.current_platform_user_id() is null or not public.can_read_activity_instance(target_instance) then return null;end if;
 select * into a from public.activity_instances where id=target_instance;
 if not found or not public.can_read_development_project(a.project_id) or not exists(select 1 from public.development_projects p where p.id=a.project_id and p.primary_workspace_id=a.workspace_id) then return null;end if;
 select * into d from public.activity_definitions where id=a.activity_definition_id;
 if not found then return null;end if;
 -- Only an explicitly configured AI completion rule can prove independent work.
 -- Reuse M7's min_required_inputs/min_outputs grammar, never general completion.
 rule0:=a.configuration_snapshot #> '{configuration,ai,completion_rule}';
 if jsonb_typeof(rule0)='object' and rule0 ?& array['min_required_inputs','min_outputs'] and not exists(select 1 from jsonb_object_keys(rule0) k where k not in ('min_required_inputs','min_outputs')) then
  if jsonb_typeof(rule0->'min_required_inputs')='number' and jsonb_typeof(rule0->'min_outputs')='number' then
   ni:=(rule0->>'min_required_inputs')::numeric;no0:=(rule0->>'min_outputs')::numeric;
   if ni>=0 and no0>=0 and ni=floor(ni) and no0=floor(no0) and ni+no0>0 then
    proof:=(select count(*) from public.activity_inputs i join public.development_objects o on o.id=i.development_object_id where i.activity_instance_id=a.id and i.required and i.input_type='development_object' and o.project_id=a.project_id and o.workspace_id=a.workspace_id and public.can_read_development_project(o.project_id))>=ni
     and (select count(*) from public.activity_outputs i join public.development_objects o on o.id=i.development_object_id where i.activity_instance_id=a.id and i.output_type='development_object' and o.project_id=a.project_id and o.workspace_id=a.workspace_id and o.created_by=auth.uid() and public.can_read_development_project(o.project_id))>=no0;
   end if;
  end if;
 end if;
 if coalesce((d.configuration #> '{ai,independent_work_required}')='true'::jsonb,false) and d.configuration #> '{ai,completion_rule}' is distinct from rule0 then proof:=false;end if;
 return jsonb_build_object('project_id',a.project_id,'workspace_id',a.workspace_id,'status',a.status,'definition_status',d.status,'method_type',a.configuration_snapshot->>'method_type','ai_role_code',a.configuration_snapshot->>'ai_role_code','configuration',jsonb_build_object('ai',a.configuration_snapshot #> '{configuration,ai}'),'current_ai',d.configuration->'ai','current_role',d.ai_role_code,'current_method',d.method_type,'independent_work_satisfied',proof,
 -- A nonempty canonically revealed pool proves reveal, never hidden row counts.
 'revealed_pool_satisfied',exists(select 1 from public.brainstorm_entries b where b.activity_instance_id=a.id and b.project_id=a.project_id and b.workspace_id=a.workspace_id and b.revealed_at is not null and public.can_read_brainstorm_entry(b.id)));
end$$;
revoke all on function public.resolve_activity_ai_configuration(uuid) from public,anon,authenticated,service_role;
grant execute on function public.resolve_activity_ai_configuration(uuid) to authenticated;
commit;

