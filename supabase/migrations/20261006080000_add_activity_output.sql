begin;
-- Existing contradictory/duplicate trusted data must be resolved explicitly,
-- never silently consolidated. This key protects every write, including retries.
alter table public.activity_outputs add constraint activity_outputs_canonical_unique unique(activity_instance_id,development_object_id,output_type);
-- Normal roles have no table writes. Narrow elevated RPC owns only one output
-- insertion; auth identity is never an argument. Existing RLS/grants unchanged.
create function public.add_activity_output(target_instance uuid,target_object uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid;a public.activity_instances;o public.development_objects;result public.activity_outputs;checked_at timestamptz;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';
 end if;
 if target_instance is null or target_object is null then raise exception 'Invalid input' using errcode='22023';end if;
 if current_setting('transaction_isolation')<>'read committed' then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Gate before locking or revealing lifecycle/duplicate information.
 if not public.can_read_activity_instance(target_instance) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fici-activity-output:'||target_instance::text||':'||target_object::text,79));
 select * into a from public.activity_instances where id=target_instance;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Reuse exact existing contribution authority; Mentor read access is insufficient.
 -- Validator locks parent and identity/membership state against revocation.
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 perform 1 from public.cohorts where id=a.cohort_id for share;
 perform 1 from public.project_program_links where project_id=a.project_id for share;
 select * into a from public.activity_instances where id=target_instance for share;
 if not public.can_read_activity_instance(a.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Independent Object authorization composes the same canonical Project/Workspace
 -- predicate as Object RLS. Exact binding to the locked writable parent prevents
 -- definer privileges from admitting foreign/private sources.
 select * into o from public.development_objects where id=target_object for share;
 if not found or o.project_id is distinct from a.project_id or o.workspace_id is distinct from a.workspace_id
  or not public.can_read_development_project(o.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
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
 select * into result from public.activity_outputs where activity_instance_id=a.id and development_object_id=o.id and output_type='development_object';
 if found then
  return to_jsonb(result);
 end if;
 insert into public.activity_outputs(activity_instance_id,development_object_id,output_type)
 values(a.id,o.id,'development_object') returning * into result;
 return to_jsonb(result);
end $$;
revoke all on function public.add_activity_output(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.add_activity_output(uuid,uuid) to authenticated;
comment on function public.add_activity_output(uuid,uuid) is 'M7.9 identity-bound contribution RPC: canonical same Project/Workspace Object reference, active Activity, locked current authorization, idempotent canonical output. No participant/Object/history writes. READ COMMITTED only.';
commit;
