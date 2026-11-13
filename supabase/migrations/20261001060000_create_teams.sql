begin;
create type public.team_status as enum ('created','active','completed','archived');
alter table public.workspaces add constraint workspaces_id_cohort_type_unique unique(id,cohort_id,workspace_type);
create table public.teams (
 id uuid primary key default gen_random_uuid(),
 cohort_id uuid not null references public.cohorts(id) on delete restrict,
 name text not null check(length(btrim(name)) between 1 and 200),description text,
 status public.team_status not null default 'created',
 team_lead_user_id uuid references public.users(id) on delete restrict,
 master_user_id uuid not null references public.users(id) on delete restrict,
 workspace_id uuid not null unique references public.workspaces(id) on delete restrict,
 workspace_type public.workspace_type generated always as ('TEAM'::public.workspace_type) stored not null,
 created_by uuid not null references public.users(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),archived_at timestamptz,
 constraint teams_workspace_cohort_type foreign key(workspace_id,cohort_id,workspace_type)
  references public.workspaces(id,cohort_id,workspace_type) on delete restrict
);
create index teams_cohort_lookup on public.teams(cohort_id);
create index teams_master_lookup on public.teams(master_user_id);
-- workspace_id's unique constraint supplies its lookup index.
alter table public.workspaces add constraint workspaces_team_id_fkey
 foreign key(team_id) references public.teams(id) on delete restrict deferrable initially deferred;
comment on column public.workspaces.team_id is 'FK to Teams introduced in M5.1; operational Team Workspace provisioning remains deferred.';
comment on table public.teams is 'M5.1 schema only. Name uniqueness deferred pending an approved lifecycle/name policy. No membership or client CRUD.';
-- Validate new/reassigned bindings. Preserve history when grants later expire.
-- This validates stored data; it never grants permission from master_user_id.
create function public.validate_team_master_binding() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='UPDATE' and new.master_user_id=old.master_user_id and new.cohort_id=old.cohort_id then return new;end if;
 if not exists(
  select 1 from public.users u join public.role_assignments a on a.user_id=u.id join public.roles r on r.id=a.role_id
  where u.id=new.master_user_id and u.account_status='active' and r.code='MASTER'
   and a.status='active' and a.starts_at<=now() and (a.ends_at is null or a.ends_at>now())
   and a.cohort_id=new.cohort_id and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null
 ) then raise exception 'Invalid Team Master binding' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.validate_team_master_binding() from public,anon,authenticated,service_role;
create trigger teams_validate_master before insert or update of master_user_id,cohort_id on public.teams
 for each row execute function public.validate_team_master_binding();
alter table public.teams enable row level security;
revoke all on public.teams from public,anon,authenticated,service_role;
-- No client access, membership authorization or creation RPC introduced.
commit;
