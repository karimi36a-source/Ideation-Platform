begin;
-- Approved M15.28 operational roster. No profile policy/grant changes and no
-- educational-content authority. All association checks stay inside this query.
create function public.list_pilot_active_users(target_organization uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if target_organization is null
  or not public.has_active_role_in_organization('ADMIN',target_organization)
  or not exists(select 1 from public.organizations o where o.id=target_organization and o.status='active')
 then raise exception 'Access denied' using errcode='42501';end if;
 with current_programs as (
  select p.id from public.programs p where p.organization_id=target_organization and p.status='active'
 ), current_cohorts as (
  select c.id from public.cohorts c join current_programs p on p.id=c.program_id where c.status in ('planned','active')
 ), current_teams as (
  select t.id from public.teams t join current_cohorts c on c.id=t.cohort_id where t.status in ('created','active') and t.archived_at is null
 ), current_projects as (
  select d.id from public.development_projects d
  where d.status in ('active','paused') and d.archived_at is null and exists(
   select 1 from public.project_program_links l join current_programs p on p.id=l.program_id
   join current_cohorts c on c.id=l.cohort_id
   where l.project_id=d.id and l.entered_at<=pg_catalog.statement_timestamp() and l.completed_at is null
  )
 ), associated_users as (
  select a.user_id from public.role_assignments a join public.roles r on r.id=a.role_id
  where r.is_system_role and a.status='active' and a.starts_at<=pg_catalog.statement_timestamp()
   and (a.ends_at is null or a.ends_at>pg_catalog.statement_timestamp())
   and pg_catalog.num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id)=1
   and (a.organization_id=target_organization or a.program_id in(select id from current_programs)
    or a.cohort_id in(select id from current_cohorts) or a.team_id in(select id from current_teams)
    or a.project_id in(select id from current_projects))
  union
  select e.user_id from public.enrollments e join current_cohorts c on c.id=e.cohort_id
   where e.status='active' and e.joined_at<=pg_catalog.statement_timestamp()
  union
  select m.user_id from public.team_memberships m join current_teams t on t.id=m.team_id
   where m.status='active' and m.left_at is null and m.joined_at<=pg_catalog.statement_timestamp()
  union
  select m.user_id from public.project_memberships m join current_projects p on p.id=m.project_id
   where m.status='active' and m.starts_at<=pg_catalog.statement_timestamp()
    and (m.ends_at is null or m.ends_at>pg_catalog.statement_timestamp())
 )
 select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'display_name',u.display_name,'email',u.email,'account_status',u.account_status) order by u.id),'[]'::jsonb)
 into result from public.users u where u.account_status='active' and u.id in(select user_id from associated_users);
 return result;
end $$;
revoke all on function public.list_pilot_active_users(uuid) from public,anon,authenticated,service_role;
grant execute on function public.list_pilot_active_users(uuid) to authenticated;
comment on function public.list_pilot_active_users(uuid) is 'M15.28 exact active organization Admin roster; four approved fields only, no source-content access.';
commit;
