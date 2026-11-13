begin;
-- Narrow authenticated RPC: operational Team management does not grant content
-- read access. Empty search_path; authorization rows locked through transaction.
create function public.archive_development_project(target_project uuid) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare actor uuid;p public.development_projects;w public.workspaces;t public.teams;scope uuid;org uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 select * into p from public.development_projects where id=target_project;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 -- Same Cohort -> Team -> Project lock ordering as existing Project writers.
 perform 1 from public.cohorts where id=(select cohort_id from public.workspaces where id=p.primary_workspace_id) for share;
 if p.owner_team_id is not null then perform 1 from public.teams where id=p.owner_team_id for share;end if;
 select * into p from public.development_projects where id=target_project for update;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 if p.project_type='team' then
  if p.owner_team_id is null or p.owner_user_id is not null or not public.can_manage_team(p.owner_team_id)
  then raise exception 'Access denied' using errcode='42501';end if;
  -- Match Team lifecycle operations: Cohort first, Team second. Hold eligibility
  -- rows through insert to prevent concurrent archive or authority revocation.
  select c.id into scope from public.cohorts c join public.teams t0 on t0.cohort_id=c.id where t0.id=p.owner_team_id for share of c;
  select * into t from public.teams where id=p.owner_team_id for share;
  if not found or t.cohort_id is distinct from scope or t.status not in ('created','active') or t.workspace_id<>p.primary_workspace_id
  or not public.can_manage_team(t.id) then raise exception 'Access denied' using errcode='42501';end if;
  select p0.organization_id into org from public.programs p0 join public.cohorts c on c.program_id=p0.id where c.id=scope for share of p0;
  perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
   where a.user_id=actor and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp())
   and a.program_id is null and a.project_id is null and (
    (r.code='ADMIN' and a.organization_id=org and a.cohort_id is null and a.team_id is null)
    or (r.code='MASTER' and a.organization_id is null and a.cohort_id=scope and a.team_id is null)
    or (r.code='MASTER' and a.organization_id is null and a.cohort_id is null and a.team_id=t.id)) for share of a;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
 elsif p.project_type='individual' then
  if p.owner_team_id is not null or (p.owner_user_id is not null and p.owner_user_id<>actor)
  then raise exception 'Access denied' using errcode='42501';end if;

 else
  if p.owner_team_id is not null or p.owner_user_id is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
  select cohort_id into scope from public.workspaces where id=p.primary_workspace_id and workspace_type='CASE_STUDY' and owner_user_id=actor;
  if scope is null or not public.has_active_role_in_cohort('MASTER',scope) then raise exception 'Access denied' using errcode='42501';end if;
  perform 1 from public.cohorts where id=scope for share;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
  perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.user_id=actor and r.code='MASTER'
   and a.cohort_id=scope and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null
   and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp()) for share of a;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 select * into w from public.workspaces where id=p.primary_workspace_id for share;
 if not found or w.status<>'active' or w.visibility<>'private' then raise exception 'Access denied' using errcode='42501';end if;
 if p.project_type='team' then
  if w.workspace_type<>'TEAM' or w.team_id is distinct from t.id or w.cohort_id is distinct from scope then raise exception 'Access denied' using errcode='42501';end if;
 elsif w.owner_user_id is distinct from actor or w.team_id is not null or
  (p.project_type='individual' and w.workspace_type<>'PERSONAL') or
  (p.project_type='instructor_case_study' and (w.workspace_type<>'CASE_STUDY' or w.cohort_id is distinct from scope or not public.has_active_role_in_cohort('MASTER',scope)))
 then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found or public.current_platform_user_id() is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;

 -- Retry must reauthorize, and must preserve original timestamp/history.
 if p.status='archived' then return to_jsonb(p);end if;
 if p.archived_at is not null then raise exception 'Access denied' using errcode='42501';end if;
 update public.development_projects set status='archived',archived_at=clock_timestamp(),updated_at=clock_timestamp()
 where id=p.id returning * into p;
 perform public.append_project_change(p.id,'PROJECT',p.id,'PROJECT_ARCHIVED');
 return to_jsonb(p);
end $$;
revoke all on function public.archive_development_project(uuid) from public,anon,authenticated,service_role;
grant execute on function public.archive_development_project(uuid) to authenticated;
comment on function public.archive_development_project(uuid) is 'Identity-bound archive only; no restore, cascade or historical read grant. Team uses exact scoped management authority.';
commit;
