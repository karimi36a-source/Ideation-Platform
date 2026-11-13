begin;
create type public.workspace_type as enum ('PERSONAL','TEAM','MASTER','SHARED','CASE_STUDY');
create type public.workspace_status as enum ('active','inactive','archived');
create type public.workspace_visibility as enum ('private');
create table public.workspaces (
 id uuid primary key default gen_random_uuid(),
 workspace_type public.workspace_type not null,
 name text not null check(length(btrim(name)) between 1 and 200),
 owner_user_id uuid references public.users(id) on delete restrict,
 team_id uuid,
 cohort_id uuid references public.cohorts(id) on delete restrict,
 project_id uuid,
 status public.workspace_status not null default 'active',
 visibility public.workspace_visibility not null default 'private',
 settings jsonb not null default '{}'::jsonb check(jsonb_typeof(settings)='object'),
 created_at timestamptz not null default now(),
 created_by uuid not null references public.users(id) on delete restrict,
 updated_at timestamptz not null default now(),
 updated_by uuid not null references public.users(id) on delete restrict,
 archived_at timestamptz,
 check(workspace_type<>'PERSONAL' or owner_user_id is not null)
);
comment on column public.workspaces.team_id is 'Deferred FK: Teams are owned by M5; UUID preserved without inventing a resource.';
comment on column public.workspaces.project_id is 'Deferred FK: Development Projects are owned by M6; UUID preserved without inventing a resource.';
create index workspaces_owner_lookup on public.workspaces(owner_user_id);
create index workspaces_cohort_lookup on public.workspaces(cohort_id);
create index workspaces_type_lookup on public.workspaces(workspace_type);
create unique index workspaces_one_active_personal on public.workspaces(owner_user_id)
 where workspace_type='PERSONAL' and status='active';
-- Schema-only: deny client access until approved provisioning/access/RLS tasks.
alter table public.workspaces enable row level security;
revoke all on public.workspaces from public,anon,authenticated,service_role;
commit;
