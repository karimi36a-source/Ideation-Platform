begin;
-- M10.20: normalize delegated scope denials so a direct public RPC cannot
-- distinguish an inaccessible existing Decision from a nonexistent ID.
-- Preserve all identity, scope, lifecycle, lock and grant semantics.

create or replace function private.require_decision_creation(target_project uuid,target_workspace uuid,target_activity uuid) returns void
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();p public.development_projects;w public.workspaces;a public.activity_instances;checked_at timestamptz;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if current_setting('transaction_isolation')<>'read committed' then raise exception 'Resource unavailable' using errcode='42501';end if;
 begin
  perform public.require_development_object_write(target_project,target_workspace);
 exception when insufficient_privilege then
  raise exception 'Resource unavailable' using errcode='42501';
 end;
 select * into p from public.development_projects where id=target_project;
 select * into w from public.workspaces where id=target_workspace;
 checked_at:=clock_timestamp();
 if w.workspace_type='PERSONAL' then
  if p.project_type<>'individual' or p.owner_user_id is distinct from actor or w.owner_user_id is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 elsif w.workspace_type='TEAM' then
  if not exists(select 1 from public.role_assignments ra join public.roles rr on rr.id=ra.role_id
   where ra.user_id=actor and rr.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.cohort_id=w.cohort_id and ra.team_id is null) or (ra.team_id=w.team_id and ra.cohort_id is null)))
  and not exists(select 1 from public.teams t join public.team_memberships m on m.team_id=t.id
   where t.id=w.team_id and t.team_lead_user_id=actor and m.user_id=actor and m.membership_role='team_lead' and m.status='active' and m.left_at is null and m.joined_at<=checked_at)
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 else raise exception 'Resource unavailable' using errcode='42501';end if;
 if target_activity is not null then
  perform 1 from public.project_program_links where project_id=p.id for share;
  select * into a from public.activity_instances where id=target_activity for share;
  if not found or a.project_id<>p.id or a.workspace_id<>w.id or a.team_id is distinct from p.owner_team_id or not public.can_read_activity_instance(a.id)
  then raise exception 'Resource unavailable' using errcode='42501';end if;
  if a.status<>'active' then raise exception 'Activity is not writable' using errcode='55000';end if;
 end if;
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
end $$;
revoke all on function private.require_decision_creation(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create or replace function private.require_decision_finalization(target_project uuid,target_workspace uuid,target_activity uuid,first_transition boolean) returns void
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();p public.development_projects;w public.workspaces;a public.activity_instances;checked_at timestamptz;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if current_setting('transaction_isolation')<>'read committed' then raise exception 'Resource unavailable' using errcode='42501';end if;
 begin
  perform public.require_development_object_write(target_project,target_workspace);
 exception when insufficient_privilege then
  raise exception 'Resource unavailable' using errcode='42501';
 end;
 select * into p from public.development_projects where id=target_project;
 select * into w from public.workspaces where id=target_workspace;
 checked_at:=clock_timestamp();
 if w.workspace_type='PERSONAL' then
  if p.project_type<>'individual' or p.owner_user_id is distinct from actor or w.owner_user_id is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 elsif w.workspace_type='TEAM' then
  if not exists(select 1 from public.role_assignments ra join public.roles rr on rr.id=ra.role_id
   where ra.user_id=actor and rr.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.cohort_id=w.cohort_id and ra.team_id is null) or (ra.team_id=w.team_id and ra.cohort_id is null)))
  and not exists(select 1 from public.teams t join public.team_memberships m on m.team_id=t.id
   where t.id=w.team_id and t.team_lead_user_id=actor and m.user_id=actor and m.membership_role='team_lead' and m.status='active' and m.left_at is null and m.joined_at<=checked_at)
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 else raise exception 'Resource unavailable' using errcode='42501';end if;
 if target_activity is not null then
  perform 1 from public.project_program_links where project_id=p.id for share;
  select * into a from public.activity_instances where id=target_activity for share;
  if not found or a.project_id<>p.id or a.workspace_id<>w.id or a.team_id is distinct from p.owner_team_id or not public.can_read_activity_instance(a.id)
  then raise exception 'Resource unavailable' using errcode='42501';end if;
  if first_transition and a.status<>'active' then raise exception 'Activity is not writable' using errcode='55000';end if;
 end if;
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
end $$;
revoke all on function private.require_decision_finalization(uuid,uuid,uuid,boolean) from public,anon,authenticated,service_role;

commit;
