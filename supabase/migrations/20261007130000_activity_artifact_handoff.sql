begin;
alter table public.activity_inputs drop constraint activity_inputs_input_type_check,drop constraint activity_inputs_supported_target;
alter table public.activity_inputs add constraint activity_inputs_supported_target check (
 (input_type='development_object' and development_object_id is not null and artifact_id is null and artifact_version_id is null and evidence_id is null)
 or (input_type='artifact' and artifact_id is not null and artifact_version_id is null and development_object_id is null and evidence_id is null)
 or (input_type='artifact_version' and artifact_id is not null and artifact_version_id is not null and development_object_id is null and evidence_id is null));
alter table public.activity_inputs add foreign key(artifact_id) references public.artifacts(id) on delete restrict,
 add foreign key(artifact_version_id,artifact_id) references public.artifact_versions(id,artifact_id) on delete restrict;
alter table public.activity_outputs drop constraint activity_outputs_output_type_check,drop constraint activity_outputs_supported_target;
alter table public.activity_outputs add constraint activity_outputs_supported_target check (
 (output_type='development_object' and development_object_id is not null and artifact_id is null and decision_id is null and evidence_id is null)
 or (output_type='artifact' and artifact_id is not null and development_object_id is null and decision_id is null and evidence_id is null));
alter table public.activity_outputs add foreign key(artifact_id) references public.artifacts(id) on delete restrict;
create unique index activity_inputs_artifact_unique on public.activity_inputs(activity_instance_id,artifact_id,artifact_version_id,input_type) nulls not distinct where artifact_id is not null;
create unique index activity_outputs_artifact_unique on public.activity_outputs(activity_instance_id,artifact_id) where artifact_id is not null;
comment on column public.activity_inputs.artifact_id is 'M8.14 canonical Artifact identity, same Activity Project/Workspace; no content copy.';
comment on column public.activity_inputs.artifact_version_id is 'M8.14 fixed same-Artifact Version reference. Never automatically retargeted on supersession.';
comment on column public.activity_outputs.artifact_id is 'M8.14 stable Artifact output with exact originating Activity provenance.';

-- Private read-only source resolver. Count all compatible executions: ambiguity
-- must fail closed, rather than choosing latest or ignoring inaccessible history.
create function public.activity_artifact_candidates_in_context(target_definition uuid,target_project uuid,target_workspace uuid,target_team uuid,target_cohort uuid)
returns table(dependency_id uuid,dependency_type text,artifact_id uuid,artifact_version_id uuid,artifact_type text)
language sql stable set search_path='' as $$
 select d.id,d.dependency_type::text,a.id,case when d.dependency_type='approved_output' then v.id end,a.artifact_type::text
 from public.activity_dependencies d
 join public.activity_instances i on i.activity_definition_id=d.required_activity_definition_id and i.project_id=target_project and i.workspace_id=target_workspace and i.team_id is not distinct from target_team and i.cohort_id=target_cohort
 join public.artifacts a on a.activity_instance_id=i.id and a.project_id=target_project and a.workspace_id=target_workspace
 left join public.artifact_versions v on v.id=a.current_version_id and v.artifact_id=a.id
 where d.activity_definition_id=target_definition and d.dependency_type in ('approved_output','artifact_available')
 and (select count(*) from public.activity_instances x where x.activity_definition_id=d.required_activity_definition_id and x.project_id=target_project and x.workspace_id=target_workspace and x.team_id is not distinct from target_team and x.cohort_id=target_cohort)=1
 and public.can_read_activity_instance(i.id) and public.can_read_development_project(a.project_id)
 and a.status='ACTIVE' and a.archived_at is null
 and (d.required_artifact_type is null or d.required_artifact_type=a.artifact_type::text)
 and (d.dependency_type='artifact_available' or (v.status='CURRENT' and v.approved_by is not null and v.approved_at is not null));
$$;
revoke all on function public.activity_artifact_candidates_in_context(uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function public.list_activity_artifact_candidates(target_definition uuid,target_project uuid,target_workspace uuid,target_team uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare ctx jsonb;result jsonb;begin
 ctx:=public.activity_execution_context(target_definition,target_project,target_workspace,target_team);
 if ctx->>'available'<>'true' then raise exception 'Resource unavailable' using errcode='42501';end if;
 select coalesce(jsonb_agg(jsonb_build_object('dependencyId',dependency_id,'dependencyType',dependency_type,'artifactId',artifact_id,'artifactVersionId',artifact_version_id,'artifactType',artifact_type) order by dependency_id,artifact_id),'[]'::jsonb) into result
 from public.activity_artifact_candidates_in_context(target_definition,target_project,target_workspace,target_team,(ctx->>'cohort')::uuid);
 return result;
end $$;
revoke all on function public.list_activity_artifact_candidates(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.list_activity_artifact_candidates(uuid,uuid,uuid,uuid) to authenticated;

create or replace function public.validate_activity_object_link() returns trigger language plpgsql set search_path='' as $$
declare i public.activity_instances;o public.development_objects;a public.artifacts;begin
 select * into i from public.activity_instances where id=new.activity_instance_id for share;
 if not found then raise exception 'Invalid Activity reference' using errcode='23503';end if;
 if new.development_object_id is not null then
  select * into o from public.development_objects where id=new.development_object_id for share;
  if not found then raise exception 'Invalid Object reference' using errcode='23503';end if;
  if i.project_id<>o.project_id or i.workspace_id<>o.workspace_id then raise exception 'Activity/Object scope mismatch' using errcode='23514';end if;
 elsif new.artifact_id is not null then
  select * into a from public.artifacts where id=new.artifact_id for share;
  if not found then raise exception 'Invalid Artifact reference' using errcode='23503';end if;
  if i.project_id<>a.project_id or i.workspace_id<>a.workspace_id or (tg_table_name='activity_outputs' and a.activity_instance_id is distinct from i.id)
  then raise exception 'Activity/Artifact scope mismatch' using errcode='23514';end if;
 end if;
 return new;
end $$;
-- Only new Artifact links are append-only; existing Object behavior is unchanged.
create function public.preserve_activity_artifact_link() returns trigger language plpgsql set search_path='' as $$begin
 if old.artifact_id is not null then raise exception 'Artifact handoff history is immutable' using errcode='23514';end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
revoke all on function public.preserve_activity_artifact_link() from public,anon,authenticated,service_role;
create trigger activity_inputs_artifact_history before update or delete on public.activity_inputs for each row execute function public.preserve_activity_artifact_link();
create trigger activity_outputs_artifact_history before update or delete on public.activity_outputs for each row execute function public.preserve_activity_artifact_link();

-- Preserve independent source RLS and historical fixed Version readability.
drop policy activity_inputs_read on public.activity_inputs;
drop policy activity_inputs_read_guard on public.activity_inputs;
create policy activity_inputs_read on public.activity_inputs for select to authenticated using(public.can_read_activity_instance(activity_instance_id) and (
 (development_object_id is not null and exists(select 1 from public.development_objects o join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where o.id=activity_inputs.development_object_id and o.project_id=ai.project_id and o.workspace_id=ai.workspace_id))
 or (artifact_id is not null and exists(select 1 from public.artifacts a join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where a.id=activity_inputs.artifact_id and a.project_id=ai.project_id and a.workspace_id=ai.workspace_id) and (artifact_version_id is null or exists(select 1 from public.artifact_versions v where v.id=activity_inputs.artifact_version_id and v.artifact_id=activity_inputs.artifact_id)))));
create policy activity_inputs_read_guard on public.activity_inputs as restrictive for select to authenticated using(public.can_read_activity_instance(activity_instance_id) and (
 (development_object_id is not null and exists(select 1 from public.development_objects o join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where o.id=activity_inputs.development_object_id and o.project_id=ai.project_id and o.workspace_id=ai.workspace_id))
 or (artifact_id is not null and exists(select 1 from public.artifacts a join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where a.id=activity_inputs.artifact_id and a.project_id=ai.project_id and a.workspace_id=ai.workspace_id) and (artifact_version_id is null or exists(select 1 from public.artifact_versions v where v.id=activity_inputs.artifact_version_id and v.artifact_id=activity_inputs.artifact_id)))));
drop policy activity_outputs_read on public.activity_outputs;
drop policy activity_outputs_read_guard on public.activity_outputs;
create policy activity_outputs_read on public.activity_outputs for select to authenticated using(public.can_read_activity_instance(activity_instance_id) and (
 (development_object_id is not null and exists(select 1 from public.development_objects o join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where o.id=activity_outputs.development_object_id and o.project_id=ai.project_id and o.workspace_id=ai.workspace_id))
 or (artifact_id is not null and exists(select 1 from public.artifacts a join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where a.id=activity_outputs.artifact_id and a.activity_instance_id=ai.id and a.project_id=ai.project_id and a.workspace_id=ai.workspace_id))));
create policy activity_outputs_read_guard on public.activity_outputs as restrictive for select to authenticated using(public.can_read_activity_instance(activity_instance_id) and (
 (development_object_id is not null and exists(select 1 from public.development_objects o join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where o.id=activity_outputs.development_object_id and o.project_id=ai.project_id and o.workspace_id=ai.workspace_id))
 or (artifact_id is not null and exists(select 1 from public.artifacts a join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where a.id=activity_outputs.artifact_id and a.activity_instance_id=ai.id and a.project_id=ai.project_id and a.workspace_id=ai.workspace_id))));

create or replace function public.activity_dependencies_in_context(target_definition uuid,target_project uuid,target_workspace uuid,target_team uuid,target_cohort uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare d record;ok boolean;missing jsonb:='[]';optional jsonb:='[]';requirement jsonb;
begin
 for d in select * from public.activity_dependencies where activity_definition_id=target_definition order by id loop
  ok:=false;
  case d.dependency_type::text
   when 'completion' then
    select exists(select 1 from public.activity_instances i where i.activity_definition_id=d.required_activity_definition_id
     and i.project_id=target_project and i.workspace_id=target_workspace and i.team_id is not distinct from target_team
     and i.cohort_id=target_cohort and i.status='completed' and i.completed_at is not null
     and public.can_read_activity_instance(i.id)) into ok;
   when 'approved_output' then select exists(select 1 from public.activity_artifact_candidates_in_context(target_definition,target_project,target_workspace,target_team,target_cohort) c where c.dependency_id=d.id) into ok;
   when 'artifact_available' then select exists(select 1 from public.activity_artifact_candidates_in_context(target_definition,target_project,target_workspace,target_team,target_cohort) c where c.dependency_id=d.id) into ok;
   when 'gate_passed' then ok:=false; -- Gate owning milestone.
   else ok:=false;
  end case;
  if not ok then
   requirement:=jsonb_build_object('dependencyId',d.id,'requiredActivityDefinitionId',d.required_activity_definition_id);
   if d.is_mandatory then missing:=missing||jsonb_build_array(requirement);else optional:=optional||jsonb_build_array(requirement);end if;
  end if;
 end loop;
 if jsonb_array_length(missing)>0 then return jsonb_build_object('satisfied',false,'blockingReason','DEPENDENCY_NOT_MET','missingRequiredDependencies',missing,'optionalUnsatisfiedDependencies',optional);end if;
 return jsonb_build_object('satisfied',true,'missingRequiredDependencies',missing,'optionalUnsatisfiedDependencies',optional);
end $$;

-- Reuse M7 contribution authority, lifecycle, actual-time expiry and lock order.
create function public.lock_activity_artifact_contribution(target_instance uuid) returns public.activity_instances
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid;a public.activity_instances;checked_at timestamptz;begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';
 end if;
 if target_instance is null then raise exception 'Invalid input' using errcode='22023';end if;
 if current_setting('transaction_isolation')<>'read committed' then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Gate before locking or revealing lifecycle/duplicate information.
 if not public.can_read_activity_instance(target_instance) then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into a from public.activity_instances where id=target_instance;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Reuse exact existing contribution authority; Mentor read access is insufficient.
 -- Validator locks parent and identity/membership state against revocation.
 perform 1 from public.cohorts where id=a.cohort_id for share;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 perform 1 from public.cohorts where id=a.cohort_id for share;
 perform 1 from public.project_program_links where project_id=a.project_id for share;
 select * into a from public.activity_instances where id=target_instance for share;
 if not public.can_read_activity_instance(a.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if a.status<>'active' then raise exception 'Activity not writable' using errcode='55000';end if;
 checked_at:=pg_catalog.clock_timestamp();
 -- Statement-time helpers must not preserve authority that expired while waiting.
 if a.team_id is not null and not exists(select 1 from public.project_memberships m where m.project_id=a.project_id and m.user_id=actor and m.status='active' and m.starts_at<=checked_at and (m.ends_at is null or m.ends_at>checked_at)) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if not exists(select 1 from public.enrollments e where e.user_id=actor and e.cohort_id=a.cohort_id and e.status='active')
  and not exists(select 1 from public.role_assignments ra join public.roles role0 on role0.id=ra.role_id
   where ra.user_id=actor and role0.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.cohort_id=a.cohort_id and ra.team_id is null) or (ra.team_id=a.team_id and ra.cohort_id is null))) then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Case Study ownership also requires its exact Master scope at actual write time.
 if exists(select 1 from public.development_projects p where p.id=a.project_id and p.project_type='instructor_case_study')
  and not exists(select 1 from public.role_assignments ra join public.roles role0 on role0.id=ra.role_id
   where ra.user_id=actor and role0.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
   and ra.organization_id is null and ra.program_id is null and ra.team_id is null and ra.project_id is null and ra.cohort_id=a.cohort_id) then raise exception 'Resource unavailable' using errcode='42501';end if;

 return a;end $$;
revoke all on function public.lock_activity_artifact_contribution(uuid) from public,anon,authenticated,service_role;

create function public.add_activity_artifact_input(target_instance uuid,target_artifact uuid,target_version uuid,is_required boolean)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare i public.activity_instances;a public.artifacts;v public.artifact_versions;result public.activity_inputs;kind text;begin
 if target_artifact is null or is_required is null then raise exception 'Invalid input' using errcode='22023';end if;
 i:=public.lock_activity_artifact_contribution(target_instance);
 select * into a from public.artifacts where id=target_artifact for share;
 if a.id is null or a.status<>'ACTIVE' or a.archived_at is not null or a.project_id<>i.project_id or a.workspace_id<>i.workspace_id
 or not public.can_read_development_project(a.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 kind:=case when target_version is null then 'artifact' else 'artifact_version' end;
 if target_version is not null then
  select * into v from public.artifact_versions where id=target_version for share;
  if v.id is null or v.artifact_id<>a.id or a.current_version_id is distinct from v.id or v.status<>'CURRENT' or v.approved_by is null or v.approved_at is null
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 -- If configured Artifact prerequisites exist, require an exact authorized match.
 -- No invented input DSL: M7's explicit required flag remains authoritative.
 if exists(select 1 from public.activity_dependencies d where d.activity_definition_id=i.activity_definition_id and d.dependency_type in ('approved_output','artifact_available'))
 and not exists(select 1 from public.activity_artifact_candidates_in_context(i.activity_definition_id,i.project_id,i.workspace_id,i.team_id,i.cohort_id) c
  where c.artifact_id=a.id and (c.dependency_type='artifact_available' or c.artifact_version_id=target_version))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Artifact SHARE serializes pointer changes/archive. Same-Artifact registration
 -- serializes retries, but never locks or edits source bodies/history.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fici-artifact-input:'||i.id::text||':'||a.id::text||':'||coalesce(target_version::text,''),814));
 i:=public.lock_activity_artifact_contribution(target_instance);
 select * into result from public.activity_inputs where activity_instance_id=i.id and artifact_id=a.id and artifact_version_id is not distinct from target_version and input_type=kind;
 if result.id is not null then
  if result.required is distinct from is_required then raise exception 'Input conflict' using errcode='23505';end if;
  return to_jsonb(result);
 end if;
 insert into public.activity_inputs(activity_instance_id,input_type,artifact_id,artifact_version_id,required) values(i.id,kind,a.id,target_version,is_required) returning * into result;
 return to_jsonb(result);
end $$;
revoke all on function public.add_activity_artifact_input(uuid,uuid,uuid,boolean) from public,anon,authenticated,service_role;
grant execute on function public.add_activity_artifact_input(uuid,uuid,uuid,boolean) to authenticated;

create function public.add_activity_artifact_output(target_instance uuid,target_artifact uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare i public.activity_instances;a public.artifacts;result public.activity_outputs;begin
 i:=public.lock_activity_artifact_contribution(target_instance);
 select * into a from public.artifacts where id=target_artifact for share;
 if a.id is null or a.status<>'ACTIVE' or a.archived_at is not null or a.project_id<>i.project_id or a.workspace_id<>i.workspace_id
 or a.activity_instance_id is distinct from i.id or not public.can_read_development_project(a.project_id)
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fici-artifact-output:'||i.id::text||':'||a.id::text,814));
 i:=public.lock_activity_artifact_contribution(target_instance);
 select * into result from public.activity_outputs where activity_instance_id=i.id and artifact_id=a.id and output_type='artifact';
 if result.id is not null then return to_jsonb(result);end if;
 insert into public.activity_outputs(activity_instance_id,output_type,artifact_id) values(i.id,'artifact',a.id) returning * into result;
 return to_jsonb(result);
end $$;
revoke all on function public.add_activity_artifact_output(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.add_activity_artifact_output(uuid,uuid) to authenticated;
commit;
