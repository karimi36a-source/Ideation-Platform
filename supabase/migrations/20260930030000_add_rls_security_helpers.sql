-- M2.4: boolean/identity primitives only; no resource authorization or new policies.
begin;
-- Definer reads avoid granting the role catalog to clients and avoid recursive RLS.
-- No dynamic SQL, caller identity parameter, or unqualified relation/function names.
create function public.current_platform_user_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select u.id from public.users u
  where u.id = (select auth.uid()) and u.account_status = 'active';
$$;
revoke all on function public.current_platform_user_id() from public, anon, authenticated, service_role;
grant execute on function public.current_platform_user_id() to authenticated;
create function public.has_active_role(role_code text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.role_assignments a
    join public.roles r on r.id = a.role_id
    join public.users u on u.id = a.user_id
    where a.user_id = (select auth.uid()) and u.account_status = 'active'
      and r.code = role_code and r.is_system_role
      and a.status = 'active' and a.starts_at <= pg_catalog.statement_timestamp()
      and (a.ends_at is null or a.ends_at > pg_catalog.statement_timestamp())
      and pg_catalog.num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id) = 1
      
  );
$$;
revoke all on function public.has_active_role(text) from public, anon, authenticated, service_role;
grant execute on function public.has_active_role(text) to authenticated;
create function public.has_active_role_in_organization(role_code text, scope_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.role_assignments a
    join public.roles r on r.id = a.role_id
    join public.users u on u.id = a.user_id
    where a.user_id = (select auth.uid()) and u.account_status = 'active'
      and r.code = role_code and r.is_system_role
      and a.status = 'active' and a.starts_at <= pg_catalog.statement_timestamp()
      and (a.ends_at is null or a.ends_at > pg_catalog.statement_timestamp())
      and pg_catalog.num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id) = 1
      and a.organization_id = scope_id
  );
$$;
revoke all on function public.has_active_role_in_organization(text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.has_active_role_in_organization(text, uuid) to authenticated;
create function public.has_active_role_in_program(role_code text, scope_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.role_assignments a
    join public.roles r on r.id = a.role_id
    join public.users u on u.id = a.user_id
    where a.user_id = (select auth.uid()) and u.account_status = 'active'
      and r.code = role_code and r.is_system_role
      and a.status = 'active' and a.starts_at <= pg_catalog.statement_timestamp()
      and (a.ends_at is null or a.ends_at > pg_catalog.statement_timestamp())
      and pg_catalog.num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id) = 1
      and a.program_id = scope_id
  );
$$;
revoke all on function public.has_active_role_in_program(text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.has_active_role_in_program(text, uuid) to authenticated;
create function public.has_active_role_in_cohort(role_code text, scope_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.role_assignments a
    join public.roles r on r.id = a.role_id
    join public.users u on u.id = a.user_id
    where a.user_id = (select auth.uid()) and u.account_status = 'active'
      and r.code = role_code and r.is_system_role
      and a.status = 'active' and a.starts_at <= pg_catalog.statement_timestamp()
      and (a.ends_at is null or a.ends_at > pg_catalog.statement_timestamp())
      and pg_catalog.num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id) = 1
      and a.cohort_id = scope_id
  );
$$;
revoke all on function public.has_active_role_in_cohort(text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.has_active_role_in_cohort(text, uuid) to authenticated;
create function public.has_active_role_in_team(role_code text, scope_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.role_assignments a
    join public.roles r on r.id = a.role_id
    join public.users u on u.id = a.user_id
    where a.user_id = (select auth.uid()) and u.account_status = 'active'
      and r.code = role_code and r.is_system_role
      and a.status = 'active' and a.starts_at <= pg_catalog.statement_timestamp()
      and (a.ends_at is null or a.ends_at > pg_catalog.statement_timestamp())
      and pg_catalog.num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id) = 1
      and a.team_id = scope_id
  );
$$;
revoke all on function public.has_active_role_in_team(text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.has_active_role_in_team(text, uuid) to authenticated;
create function public.has_active_role_in_project(role_code text, scope_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.role_assignments a
    join public.roles r on r.id = a.role_id
    join public.users u on u.id = a.user_id
    where a.user_id = (select auth.uid()) and u.account_status = 'active'
      and r.code = role_code and r.is_system_role
      and a.status = 'active' and a.starts_at <= pg_catalog.statement_timestamp()
      and (a.ends_at is null or a.ends_at > pg_catalog.statement_timestamp())
      and pg_catalog.num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id) = 1
      and a.project_id = scope_id
  );
$$;
revoke all on function public.has_active_role_in_project(text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.has_active_role_in_project(text, uuid) to authenticated;
comment on function public.has_active_role(text) is 'Diagnostic role presence only. Never authorizes scoped product access or educational content.';
commit;
