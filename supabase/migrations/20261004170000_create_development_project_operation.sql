begin;
-- One narrow, identity-bound transaction. Definer avoids broad client INSERT
-- grants and uses fixed search_path and fully qualified relations/functions.
create function public.create_development_project(project_name text,kind public.development_project_type,target_workspace uuid,
 project_description text default null,target_owner_user uuid default null,target_owner_team uuid default null)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;w public.workspaces;t public.teams;scope uuid;org uuid;p public.development_projects;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 if kind is null or project_name is null or length(btrim(project_name)) not between 1 and 200 or target_workspace is null
 then raise exception 'Invalid Project input' using errcode='22023';end if;
 if kind='team' then
  if target_owner_team is null or target_owner_user is not null or not public.can_manage_team(target_owner_team)
  then raise exception 'Access denied' using errcode='42501';end if;
  -- Match Team lifecycle operations: Cohort first, Team second. Hold eligibility
  -- rows through insert to prevent concurrent archive or authority revocation.
  select c.id into scope from public.cohorts c join public.teams t0 on t0.cohort_id=c.id where t0.id=target_owner_team for share of c;
  select * into t from public.teams where id=target_owner_team for share;
  if not found or t.cohort_id is distinct from scope or t.status not in ('created','active') or t.workspace_id<>target_workspace
  or not public.can_manage_team(t.id) then raise exception 'Access denied' using errcode='42501';end if;
  select p0.organization_id into org from public.programs p0 join public.cohorts c on c.program_id=p0.id where c.id=scope for share of p0;
  perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
   where a.user_id=actor and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp())
   and a.program_id is null and a.project_id is null and (
    (r.code='ADMIN' and a.organization_id=org and a.cohort_id is null and a.team_id is null)
    or (r.code='MASTER' and a.organization_id is null and a.cohort_id=scope and a.team_id is null)
    or (r.code='MASTER' and a.organization_id is null and a.cohort_id is null and a.team_id=t.id)) for share of a;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
 elsif kind='individual' then
  if target_owner_team is not null or (target_owner_user is not null and target_owner_user<>actor)
  then raise exception 'Access denied' using errcode='42501';end if;
  target_owner_user:=actor;
 else
  if target_owner_team is not null or target_owner_user is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
  select cohort_id into scope from public.workspaces where id=target_workspace and workspace_type='CASE_STUDY' and owner_user_id=actor;
  if scope is null or not public.has_active_role_in_cohort('MASTER',scope) then raise exception 'Access denied' using errcode='42501';end if;
  perform 1 from public.cohorts where id=scope for share;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
  perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.user_id=actor and r.code='MASTER'
   and a.cohort_id=scope and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null
   and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp()) for share of a;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 select * into w from public.workspaces where id=target_workspace for share;
 if not found or w.status<>'active' or w.visibility<>'private' then raise exception 'Access denied' using errcode='42501';end if;
 if kind='team' then
  if w.workspace_type<>'TEAM' or w.team_id is distinct from t.id or w.cohort_id is distinct from scope then raise exception 'Access denied' using errcode='42501';end if;
 elsif w.owner_user_id is distinct from actor or w.team_id is not null or
  (kind='individual' and w.workspace_type<>'PERSONAL') or
  (kind='instructor_case_study' and (w.workspace_type<>'CASE_STUDY' or w.cohort_id is distinct from scope or not public.has_active_role_in_cohort('MASTER',scope)))
 then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found or public.current_platform_user_id() is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 insert into public.development_projects(name,description,project_type,owner_user_id,owner_team_id,primary_workspace_id)
 values(btrim(project_name),project_description,kind,target_owner_user,target_owner_team,target_workspace) returning * into p;
 -- No automatic memberships, Workspace creation, Team audit reuse or change log.
 -- Project creation history is deferred to the approved M6.10 foundation.
 return to_jsonb(p);
end $$;
revoke all on function public.create_development_project(text,public.development_project_type,uuid,text,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_development_project(text,public.development_project_type,uuid,text,uuid,uuid) to authenticated;
commit;
