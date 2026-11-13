begin;
-- M11.5/M11.6 already gate automatic registration on the execution snapshot.
-- Apply that same gate to direct calls of the shared M7/M8 registration RPC.
-- Other Activity methods retain their accepted output contracts.
create or replace function public.add_activity_artifact_output(target_instance uuid,target_artifact uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare i public.activity_instances;a public.artifacts;result public.activity_outputs;types jsonb;
begin
 i:=public.lock_activity_artifact_contribution(target_instance);
 select * into a from public.artifacts where id=target_artifact for share;
 if a.id is null or a.status<>'ACTIVE' or a.archived_at is not null or a.project_id<>i.project_id or a.workspace_id<>i.workspace_id
 or a.activity_instance_id is distinct from i.id or not public.can_read_development_project(a.project_id)
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fici-artifact-output:'||i.id::text||':'||a.id::text,814));
 i:=public.lock_activity_artifact_contribution(target_instance);
 if i.configuration_snapshot->>'method_type'='affinity' then
  types:=i.configuration_snapshot#>'{configuration,outputs,artifact_types}';
  if types is null or jsonb_typeof(types) is distinct from 'array' then
   raise exception 'Resource unavailable' using errcode='42501';
  end if;
  if exists(select 1 from jsonb_array_elements(types) x where jsonb_typeof(x)<>'string'
   or not exists(select 1 from unnest(enum_range(null::public.artifact_type)) k where k::text=x#>>'{}')) then
   raise exception 'Invalid output configuration' using errcode='55000';
  end if;
  if not types @> jsonb_build_array(a.artifact_type::text) then
   raise exception 'Resource unavailable' using errcode='42501';
  end if;
 end if;
 select * into result from public.activity_outputs where activity_instance_id=i.id and artifact_id=a.id and output_type='artifact';
 if result.id is not null then return to_jsonb(result);end if;
 insert into public.activity_outputs(activity_instance_id,output_type,artifact_id) values(i.id,'artifact',a.id) returning * into result;
 return to_jsonb(result);
end $$;
revoke all on function public.add_activity_artifact_output(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.add_activity_artifact_output(uuid,uuid) to authenticated;
comment on function public.add_activity_artifact_output(uuid,uuid) is 'Canonical scope-bound Artifact output registration. Affinity outputs require the exact Artifact type in the immutable execution snapshot configuration.outputs.artifact_types; retries preserve the stable output identity.';
commit;
