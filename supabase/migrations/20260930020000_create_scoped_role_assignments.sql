-- M2.2: scoped binding storage/read foundation, not an authorization engine.
begin;
create type public.role_assignment_status as enum ('active', 'inactive');

create table public.role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  role_id uuid not null references public.roles(id) on delete restrict,
  -- Deferred FKs: organizations/programs/cohorts/teams/development_projects are M3+.
  -- Multiple scope columns are retained, not interpreted as AND/OR permissions.
  organization_id uuid,
  program_id uuid,
  cohort_id uuid,
  team_id uuid,
  project_id uuid,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  status public.role_assignment_status not null default 'active',
  assigned_by uuid not null references public.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint role_assignments_scope_required check (
    num_nonnulls(organization_id, program_id, cohort_id, team_id, project_id) >= 1
  ),
  constraint role_assignments_valid_window check (ends_at is null or ends_at > starts_at)
);

-- PostgreSQL 17: treat nullable scope/end values as equal for exact retries.
-- Distinct validity windows are not collapsed, and inactive history is retained.
create unique index role_assignments_exact_active_unique on public.role_assignments (
  user_id, role_id, organization_id, program_id, cohort_id, team_id, project_id,
  starts_at, ends_at
) nulls not distinct where status = 'active';

alter table public.role_assignments enable row level security;
revoke all on public.role_assignments from public, anon, authenticated, service_role;
grant select on public.role_assignments to authenticated;
create policy role_assignments_select_own_active on public.role_assignments
  for select to authenticated using (
    (select auth.uid()) = user_id
    and status = 'active'
    and starts_at <= statement_timestamp()
    and (ends_at is null or ends_at > statement_timestamp())
    and exists (
      select 1 from public.users u where u.id = (select auth.uid()) and u.account_status = 'active'
    )
  );

create function public.touch_role_assignment_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;
revoke all on function public.touch_role_assignment_updated_at() from public, anon, authenticated, service_role;
create trigger role_assignments_updated_at before update on public.role_assignments
  for each row execute function public.touch_role_assignment_updated_at();

-- No user ID/time/scope arguments can be supplied by a caller.
-- SECURITY INVOKER retains RLS; database time, not browser/app clocks, is used.
create function public.get_active_role_assignments()
returns setof public.role_assignments language sql stable security invoker set search_path = '' as $$
  select a.* from public.role_assignments a
  where a.user_id = (select auth.uid())
    and a.status = 'active'
    and a.starts_at <= statement_timestamp()
    and (a.ends_at is null or a.ends_at > statement_timestamp())
  order by a.id;
$$;
revoke all on function public.get_active_role_assignments() from public, anon, authenticated, service_role;
grant execute on function public.get_active_role_assignments() to authenticated;
commit;
