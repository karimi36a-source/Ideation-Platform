begin;
create schema if not exists private;
revoke all on schema private from public,anon,authenticated,service_role;
-- Owner-executed RPCs are needed because M9.1 denies all ordinary table CRUD.
-- This private validator has no caller identity argument or executable client grant.
create function private.require_brainstorm_write(target_instance uuid) returns public.activity_instances
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
 if not exists(select 1 from public.activity_definitions d where d.id=a.activity_definition_id and d.method_type='brainstorming')
  or a.configuration_snapshot->>'method_type' is distinct from 'brainstorming' then
  raise exception 'Invalid Activity method' using errcode='22023';end if;
 checked_at:=pg_catalog.clock_timestamp();
 -- Read only the immutable execution configuration, never the current Definition configuration.
 if a.configuration_snapshot #>> '{configuration,brainstorming,visibility_mode}' is distinct from 'private_before_reveal' then
  raise exception 'Required Activity configuration unavailable' using errcode='0A000';end if;
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
revoke all on function private.require_brainstorm_write(uuid) from public,anon,authenticated,service_role;

-- Narrow identity-bound creation; ordinary clients retain no table mutation grants.
create function public.create_brainstorm_entry(target_instance uuid,entry_content text,visibility_state text,parent_entry uuid default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;actor uuid;parent public.brainstorm_entries;entry public.brainstorm_entries;
begin
 a:=private.require_brainstorm_write(target_instance);
 actor:=public.current_platform_user_id();
 if entry_content is null or visibility_state is distinct from 'private' then raise exception 'Invalid input' using errcode='22023';end if;
 if parent_entry is not null then
  -- Exact current M9.5 read predicate plus matching canonical scope. No foreign
  -- parent lock, content, existence distinction or lifecycle diagnostic escapes.
  select * into parent from public.brainstorm_entries p where p.id=parent_entry and p.created_by=actor
   and p.activity_instance_id=a.id and p.project_id=a.project_id and p.workspace_id=a.workspace_id and p.status='active'
   and public.can_read_activity_instance(p.activity_instance_id) for share;
  if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 -- Revalidate time-sensitive contribution authority after a possible parent lock wait.
 a:=private.require_brainstorm_write(target_instance);
 insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,created_by,content,parent_entry_id,
  status,archived_at,revealed_at,development_object_id)
 values(a.id,a.project_id,a.workspace_id,actor,entry_content,parent_entry,'active',null,null,null) returning * into entry;
 return to_jsonb(entry);
end $$;
revoke all on function public.create_brainstorm_entry(uuid,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_brainstorm_entry(uuid,text,text,uuid) to authenticated;
comment on function public.create_brainstorm_entry(uuid,text,text,uuid) is 'M9.6 private creation only. Immutable snapshot.configuration.brainstorming.visibility_mode must be private_before_reveal. Verified actor and locked canonical contribution scope; no reveal/promotion/output mutation.';
commit;
