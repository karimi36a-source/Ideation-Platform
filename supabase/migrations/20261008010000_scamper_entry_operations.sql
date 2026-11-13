begin;
create schema if not exists private;
revoke all on schema private from public,anon,authenticated,service_role;
-- Owner-executed RPCs are needed because M9.1 denies all ordinary table CRUD.
-- This private validator has no caller identity argument or executable client grant.
create function private.require_scamper_write(target_instance uuid) returns public.activity_instances
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;checked_at timestamptz;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if current_setting('transaction_isolation')<>'read committed' or not public.can_read_activity_instance(target_instance) then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into a from public.activity_instances where id=target_instance;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Same contribution authority and lock order as M7 input/output operations.
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 perform 1 from public.cohorts where id=a.cohort_id for share;
 perform 1 from public.project_program_links where project_id=a.project_id for share;
 select * into a from public.activity_instances where id=target_instance for share;
 if public.current_platform_user_id() is distinct from actor or not public.can_read_activity_instance(a.id) then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if a.status<>'active' then raise exception 'Activity not writable' using errcode='55000';end if;
 if not exists(select 1 from public.activity_definitions d where d.id=a.activity_definition_id and d.method_type='scamper')
  or (a.configuration_snapshot ? 'method_type' and a.configuration_snapshot->>'method_type' is distinct from 'scamper') then
  raise exception 'Invalid Activity method' using errcode='22023';end if;
 checked_at:=pg_catalog.clock_timestamp();
 -- Recheck temporal authority at actual write time after all lock waits.
 if a.team_id is not null and not exists(select 1 from public.project_memberships m where m.project_id=a.project_id and m.user_id=actor
  and m.status='active' and m.starts_at<=checked_at and (m.ends_at is null or m.ends_at>checked_at)) then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if not exists(select 1 from public.enrollments e where e.user_id=actor and e.cohort_id=a.cohort_id and e.status='active')
  and not exists(select 1 from public.role_assignments ra join public.roles r on r.id=ra.role_id
   where ra.user_id=actor and r.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.cohort_id=a.cohort_id and ra.team_id is null) or (ra.team_id=a.team_id and ra.cohort_id is null))) then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if exists(select 1 from public.development_projects p where p.id=a.project_id and p.project_type='instructor_case_study')
  and not exists(select 1 from public.role_assignments ra join public.roles r on r.id=ra.role_id
   where ra.user_id=actor and r.code='MASTER' and ra.cohort_id=a.cohort_id and ra.status='active'
   and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
   and ra.organization_id is null and ra.program_id is null and ra.team_id is null and ra.project_id is null) then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 return a;
end $$;
revoke all on function private.require_scamper_write(uuid) from public,anon,authenticated,service_role;

create function public.create_scamper_entry(target_instance uuid,lens public.scamper_lens,original_value text,proposed_value text,result_value text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.activity_instances;entry public.scamper_entries;
begin
 a:=private.require_scamper_write(target_instance);
 if lens is null or original_value is null or proposed_value is null or result_value is null then
  raise exception 'Invalid input' using errcode='22023';end if;
 insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
 values(a.id,a.project_id,a.workspace_id,public.current_platform_user_id(),lens,original_value,proposed_value,result_value) returning * into entry;
 return to_jsonb(entry);
end $$;
create function public.update_scamper_entry(target_entry uuid,changes jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();entry public.scamper_entries;a public.activity_instances;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into entry from public.scamper_entries where id=target_entry;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_scamper_write(entry.activity_instance_id);
 select * into entry from public.scamper_entries where id=target_entry for update;
 if not found or entry.activity_instance_id<>a.id or entry.project_id<>a.project_id or entry.workspace_id<>a.workspace_id then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Entry-row contention can outlast a timed assignment; recheck after that wait too.
 a:=private.require_scamper_write(entry.activity_instance_id);
 if entry.status<>'active' then raise exception 'Entry not writable' using errcode='55000';end if;
 if changes is null or jsonb_typeof(changes)<>'object' or changes='{}'::jsonb then raise exception 'Invalid update' using errcode='22023';end if;
 if exists(select 1 from jsonb_each(changes) x where x.key not in ('scamperType','originalElement','proposedChange','resultText') or jsonb_typeof(x.value)<>'string') then
  raise exception 'Invalid update' using errcode='22023';end if;
 update public.scamper_entries set
  scamper_type=case when changes ? 'scamperType' then (changes->>'scamperType')::public.scamper_lens else scamper_type end,
  original_element=case when changes ? 'originalElement' then changes->>'originalElement' else original_element end,
  proposed_change=case when changes ? 'proposedChange' then changes->>'proposedChange' else proposed_change end,
  result_text=case when changes ? 'resultText' then changes->>'resultText' else result_text end,
  updated_by=actor
 where id=entry.id returning * into entry;
 -- No Artifact, Version, Submission, Object, baseline or Activity I/O writes.
 return to_jsonb(entry);
end $$;
revoke all on function public.create_scamper_entry(uuid,public.scamper_lens,text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.update_scamper_entry(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_scamper_entry(uuid,public.scamper_lens,text,text,text) to authenticated;
grant execute on function public.update_scamper_entry(uuid,jsonb) to authenticated;
comment on function public.create_scamper_entry(uuid,public.scamper_lens,text,text,text) is 'M9.2 verified actor, canonical active SCAMPER Activity scope only. Narrow definer RPC retains M9.1 default-deny table posture.';
comment on function public.update_scamper_entry(uuid,jsonb) is 'M9.2 partial four-field source edit only. Active entry/Activity, exact current contribution authority. No lifecycle, promotion, version synchronization or output side effects.';
commit;
