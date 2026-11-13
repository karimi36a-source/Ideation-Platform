begin;
create type public.enrollment_role as enum ('participant','instructor');
create type public.enrollment_status as enum ('invited','active','completed','withdrawn','removed');
create table public.enrollments (
 id uuid primary key default gen_random_uuid(),
 cohort_id uuid not null references public.cohorts(id) on delete restrict,
 user_id uuid not null references public.users(id) on delete restrict,
 enrollment_role public.enrollment_role not null,
 status public.enrollment_status not null,
 joined_at timestamptz,completed_at timestamptz,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(status not in ('active','completed') or joined_at is not null),
 check(status<>'completed' or completed_at is not null),
 check(status not in ('invited','active') or completed_at is null),
 check(status<>'invited' or joined_at is null),
 check(completed_at is null or (joined_at is not null and completed_at>=joined_at))
);
create unique index enrollments_one_active on public.enrollments(user_id,cohort_id) where status='active';
create function public.protect_enrollment_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Preserve enrollment history' using errcode='23514';end if;
 if tg_op='INSERT' then
  if new.status not in ('invited','active') then raise exception 'Invalid initial enrollment state' using errcode='23514';end if;
  new.joined_at:=case when new.status='active' then pg_catalog.statement_timestamp() else null end;new.completed_at:=null;
 else
  if new.id is distinct from old.id or new.user_id is distinct from old.user_id or new.cohort_id is distinct from old.cohort_id or new.enrollment_role is distinct from old.enrollment_role or new.created_at is distinct from old.created_at or new.joined_at is distinct from old.joined_at or new.completed_at is distinct from old.completed_at then
   raise exception 'Enrollment identity and historical timestamps are immutable' using errcode='23514';end if;
  if new.status is distinct from old.status then
   if not (new.status='removed' or (old.status='invited' and new.status in ('active','withdrawn')) or (old.status='active' and new.status in ('completed','withdrawn')) or (old.status='completed' and new.status='withdrawn')) then
    raise exception 'Re-enrollment requires a new row' using errcode='23514';end if;
   if new.status='active' then new.joined_at:=pg_catalog.statement_timestamp();end if;
   if new.status='completed' then new.completed_at:=pg_catalog.statement_timestamp();end if;
  end if;new.updated_at:=pg_catalog.clock_timestamp();
 end if;return new;
end $$;
create trigger enrollment_history before insert or update or delete on public.enrollments for each row execute function public.protect_enrollment_history();
revoke all on function public.protect_enrollment_history() from public,anon,authenticated,service_role;
alter table public.enrollments enable row level security;
revoke all on public.enrollments from public,anon,authenticated,service_role;
grant select on public.enrollments to authenticated;
-- Definers avoid cohort/enrollment RLS recursion. Each derives authenticated
-- identity, has fixed search_path and accepts only resource/metadata parameters.
create function public.has_enrollment_read_access(scope_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.enrollments e where e.cohort_id=scope_id and e.user_id=public.current_platform_user_id() and e.status in ('active','completed'));
$$;
create function public.has_active_enrollment(scope_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.enrollments e where e.cohort_id=scope_id and e.user_id=public.current_platform_user_id() and e.status='active');
$$;
create function public.can_manage_enrollment(scope_id uuid,kind public.enrollment_role) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.cohorts c join public.programs p on p.id=c.program_id where c.id=scope_id and (
  public.has_active_role_in_organization('ADMIN',p.organization_id) or
  (kind='participant' and c.primary_master_id=public.current_platform_user_id() and public.has_active_role_in_cohort('MASTER',c.id))
 ));
$$;
revoke all on function public.has_enrollment_read_access(uuid),public.has_active_enrollment(uuid),public.can_manage_enrollment(uuid,public.enrollment_role) from public,anon,authenticated,service_role;
grant execute on function public.has_enrollment_read_access(uuid),public.has_active_enrollment(uuid),public.can_manage_enrollment(uuid,public.enrollment_role) to authenticated;
create policy enrollments_scoped_read on public.enrollments for select to authenticated using(
 user_id=public.current_platform_user_id() or public.has_active_role_in_cohort('MASTER',cohort_id) or exists(
  select 1 from public.cohorts c join public.programs p on p.id=c.program_id where c.id=cohort_id and public.has_active_role_in_organization('ADMIN',p.organization_id)
 )
);
create policy cohorts_enrollment_read on public.cohorts for select to authenticated using(public.has_enrollment_read_access(id));
create function public.enroll_user(target_cohort uuid,target_user uuid,kind public.enrollment_role,initial_status public.enrollment_status)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.cohorts; result public.enrollments;
begin
 select * into c from public.cohorts where id=target_cohort for update;
 if not found or not public.can_manage_enrollment(target_cohort,kind) then raise exception 'Access denied' using errcode='42501';end if;
 if initial_status is null or initial_status not in ('invited','active') then raise exception 'Invalid initial status' using errcode='22023';end if;
 perform 1 from public.users where id=target_user and (account_status='active' or (initial_status='invited' and account_status='invited')) for share;
 if not found then raise exception 'Invalid enrollment target' using errcode='22023';end if;
 if kind='instructor' and (target_user<>c.primary_master_id or not exists(
  select 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.user_id=target_user and a.cohort_id=c.id and r.code='MASTER' and a.status='active'
  and a.starts_at<=pg_catalog.statement_timestamp() and (a.ends_at is null or a.ends_at>pg_catalog.statement_timestamp()) and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null
 )) then raise exception 'Invalid instructor target' using errcode='22023';end if;
 insert into public.enrollments(cohort_id,user_id,enrollment_role,status) values(target_cohort,target_user,kind,initial_status) returning * into result;
 return pg_catalog.to_jsonb(result);
end $$;
-- Lifecycle transitions are trusted Admin-only. Removal alone may also be
-- performed by the current Primary Master for participant records.
create function public.transition_enrollment(target_enrollment uuid,next_status public.enrollment_status)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.cohorts; e public.enrollments; org uuid;
begin
 select * into e from public.enrollments where id=target_enrollment;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.cohorts where id=e.cohort_id for update;
 select organization_id into org from public.programs where id=c.program_id;
 if not public.has_active_role_in_organization('ADMIN',org) and not (next_status='removed' and public.can_manage_enrollment(c.id,e.enrollment_role)) then raise exception 'Access denied' using errcode='42501';end if;
 select * into e from public.enrollments where id=target_enrollment for update;
 if next_status is null then raise exception 'Invalid transition' using errcode='22023';end if;
 if next_status='active' and e.status<>'active' then
  perform 1 from public.users where id=e.user_id and account_status='active' for share;
  if not found then raise exception 'Invalid enrollment target' using errcode='22023';end if;
  if e.enrollment_role='instructor' and (e.user_id<>c.primary_master_id or not exists(
   select 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.user_id=e.user_id and a.cohort_id=c.id and r.code='MASTER' and a.status='active'
   and a.starts_at<=pg_catalog.statement_timestamp() and (a.ends_at is null or a.ends_at>pg_catalog.statement_timestamp()) and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null
  )) then raise exception 'Invalid instructor target' using errcode='22023';end if;
 end if;
 update public.enrollments set status=next_status where id=e.id returning * into e;
 return pg_catalog.to_jsonb(e);
end $$;
create function public.remove_enrollment(target_enrollment uuid) returns jsonb language sql security invoker set search_path='' as $$
 select public.transition_enrollment(target_enrollment,'removed');
$$;
revoke all on function public.enroll_user(uuid,uuid,public.enrollment_role,public.enrollment_status),public.transition_enrollment(uuid,public.enrollment_status),public.remove_enrollment(uuid) from public,anon,authenticated,service_role;
grant execute on function public.enroll_user(uuid,uuid,public.enrollment_role,public.enrollment_status),public.transition_enrollment(uuid,public.enrollment_status),public.remove_enrollment(uuid) to authenticated;
-- No fixture/production users or enrollment seeds; audit events remain deferred.
commit;
