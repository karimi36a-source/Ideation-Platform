begin;
create type public.development_project_type as enum ('individual','team','instructor_case_study');
create type public.development_project_status as enum ('active','paused','completed','archived');
alter table public.workspaces add constraint workspaces_id_type_unique unique(id,workspace_type);
alter table public.workspaces add constraint workspaces_id_owner_unique unique(id,owner_user_id);
alter table public.teams add constraint teams_id_workspace_unique unique(id,workspace_id);
create table public.development_projects (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(btrim(name)) between 1 and 200), description text,
 project_type public.development_project_type not null,
 owner_user_id uuid references public.users(id) on delete restrict,
 owner_team_id uuid references public.teams(id) on delete restrict,
 primary_workspace_id uuid not null references public.workspaces(id) on delete restrict,
 status public.development_project_status not null default 'active',
 current_stage text check(current_stage is null or length(btrim(current_stage))>0),
 confidentiality_level text check(confidentiality_level is null or length(btrim(confidentiality_level))>0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), archived_at timestamptz,
 required_workspace_type public.workspace_type generated always as
 (case project_type when 'individual' then 'PERSONAL'::public.workspace_type when 'team' then 'TEAM'::public.workspace_type else 'CASE_STUDY'::public.workspace_type end) stored not null,
 constraint development_projects_owner_shape check
 ((project_type='team' and owner_team_id is not null and owner_user_id is null) or
 (project_type in ('individual','instructor_case_study') and owner_user_id is not null and owner_team_id is null)),
 constraint development_projects_workspace_type foreign key(primary_workspace_id,required_workspace_type) references public.workspaces(id,workspace_type) on delete restrict,
 constraint development_projects_workspace_owner foreign key(primary_workspace_id,owner_user_id) references public.workspaces(id,owner_user_id) on delete restrict,
 constraint development_projects_team_workspace foreign key(owner_team_id,primary_workspace_id) references public.teams(id,workspace_id) on delete restrict
);
create index development_projects_user_lookup on public.development_projects(owner_user_id);
create index development_projects_team_lookup on public.development_projects(owner_team_id);
create index development_projects_workspace_lookup on public.development_projects(primary_workspace_id);
create index development_projects_status_lookup on public.development_projects(status);
create index development_projects_type_lookup on public.development_projects(project_type);
comment on column public.development_projects.current_stage is 'Nullable nonblank metadata; approved stage vocabulary and transitions deferred. Does not authorize access.';
comment on column public.development_projects.confidentiality_level is 'Nullable nonblank metadata pending vocabulary policy; never a permission grant.';
-- Trusted schema writes validate eligibility, not caller authorization. M6.3 owns creation.
create function public.validate_development_project_binding() returns trigger language plpgsql set search_path='' as $$
declare w public.workspaces;
begin
 if tg_op='UPDATE' and new.project_type=old.project_type and new.owner_user_id is not distinct from old.owner_user_id
 and new.owner_team_id is not distinct from old.owner_team_id and new.primary_workspace_id=old.primary_workspace_id then return new;end if;
 select * into w from public.workspaces where id=new.primary_workspace_id for share;
 if not found then raise exception 'Invalid Project Workspace' using errcode='23503';end if;
 if w.status<>'active' or w.visibility<>'private' then raise exception 'Invalid Project Workspace' using errcode='23514';end if;
 if new.project_type='team' then
  if not exists(select 1 from public.teams t where t.id=new.owner_team_id and t.status in ('created','active') and t.workspace_id=w.id
   and w.workspace_type='TEAM' and w.team_id=t.id and w.cohort_id=t.cohort_id) then raise exception 'Invalid Project Team' using errcode='23514';end if;
 else
  if not exists(select 1 from public.users u where u.id=new.owner_user_id and u.account_status='active') then raise exception 'Invalid Project owner' using errcode='23514';end if;
  if w.owner_user_id is distinct from new.owner_user_id or w.team_id is not null then raise exception 'Invalid Project Workspace' using errcode='23514';end if;
  if new.project_type='instructor_case_study' and (w.cohort_id is null or not exists
   (select 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.user_id=new.owner_user_id and r.code='MASTER'
    and a.cohort_id=w.cohort_id and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null
    and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp()))) then
   raise exception 'Invalid Project Master scope' using errcode='23514';end if;
 end if;
 return new;
end $$;
revoke all on function public.validate_development_project_binding() from public,anon,authenticated,service_role;
create trigger development_projects_validate_binding before insert or update of project_type,owner_user_id,owner_team_id,primary_workspace_id on public.development_projects
 for each row execute function public.validate_development_project_binding();
-- Protect referenced Workspace scope from later rebinding; lifecycle may change,
-- but archived/inactive Workspaces lose access through the read predicate.
create function public.preserve_project_workspace_binding() returns trigger language plpgsql set search_path='' as $$
begin
 if (new.workspace_type,new.owner_user_id,new.team_id,new.cohort_id) is distinct from (old.workspace_type,old.owner_user_id,old.team_id,old.cohort_id)
 and exists(select 1 from public.development_projects where primary_workspace_id=old.id) then raise exception 'Referenced Project scope is immutable' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_project_workspace_binding() from public,anon,authenticated,service_role;
create trigger workspaces_preserve_project_scope before update of workspace_type,owner_user_id,team_id,cohort_id on public.workspaces for each row execute function public.preserve_project_workspace_binding();
-- Definer avoids recursive RLS and reads only a capability. No caller identity parameter.
create function public.can_read_development_project(target_project uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.development_projects p join public.workspaces w on w.id=p.primary_workspace_id
 where p.id=target_project and p.status='active' and w.status='active' and w.visibility='private' and public.current_platform_user_id() is not null and (
  (p.project_type='individual' and p.owner_user_id=public.current_platform_user_id() and p.owner_team_id is null
   and w.workspace_type='PERSONAL' and w.owner_user_id=p.owner_user_id and w.team_id is null)
  or (p.project_type='team' and w.workspace_type='TEAM' and w.team_id=p.owner_team_id and public.get_team_workspace_access(w.id) is not null)
  or (p.project_type='instructor_case_study' and p.owner_user_id=public.current_platform_user_id() and p.owner_team_id is null
   and w.workspace_type='CASE_STUDY' and w.owner_user_id=p.owner_user_id and w.team_id is null
   and w.cohort_id is not null and public.has_active_role_in_cohort('MASTER',w.cohort_id))));
$$;
revoke all on function public.can_read_development_project(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_development_project(uuid) to authenticated;
alter table public.development_projects enable row level security;
revoke all on public.development_projects from public,anon,authenticated,service_role;
grant select on public.development_projects to authenticated;
create policy development_projects_scoped_read on public.development_projects for select to authenticated using(public.can_read_development_project(id));
create policy development_projects_read_guard on public.development_projects as restrictive for select to authenticated using(public.can_read_development_project(id));
create policy development_projects_insert_deny on public.development_projects as restrictive for insert to authenticated with check(false);
create policy development_projects_update_deny on public.development_projects as restrictive for update to authenticated using(false) with check(false);
create policy development_projects_delete_deny on public.development_projects as restrictive for delete to authenticated using(false);
create policy development_projects_anonymous_deny on public.development_projects as restrictive for all to anon using(false) with check(false);
commit;
