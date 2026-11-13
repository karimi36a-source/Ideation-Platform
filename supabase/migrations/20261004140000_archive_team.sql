begin;
-- Cohort-first locking serializes archive with membership/enrollment operations;
-- Team UPDATE lock also waits for in-flight Chat send/Broadcast reader locks.
-- Narrow definer rechecks verified actor/profile/exact scope under held locks.
create function public.archive_team(target_team uuid)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;t public.teams;c public.cohorts;org uuid;archived_time timestamptz;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 if not public.can_manage_team(target_team) then raise exception 'Access denied' using errcode='42501';end if;
 -- Match existing cohort-first locking for enrollment/Primary Master changes.
 select c0.* into c from public.cohorts c0 join public.teams t0 on t0.cohort_id=c0.id where t0.id=target_team for update of c0;
 select * into t from public.teams where id=target_team for update;
 if not found or t.cohort_id<>c.id then raise exception 'Access denied' using errcode='42501';end if;
 select organization_id into org from public.programs where id=c.program_id for share;
 if not found or not public.can_manage_team(t.id) then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
 where a.user_id=actor and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp())
  and a.program_id is null and a.project_id is null and (
   (r.code='ADMIN' and a.organization_id=org and a.cohort_id is null and a.team_id is null)
   or (r.code='MASTER' and a.organization_id is null and a.cohort_id=t.cohort_id and a.team_id is null)
   or (r.code='MASTER' and a.organization_id is null and a.cohort_id is null and a.team_id=t.id)) for share of a;
 if not found then raise exception 'Access denied' using errcode='42501';end if;

 if t.status='archived' then
  return jsonb_build_object('teamId',t.id,'status','archived','archivedAt',t.archived_at);
 end if;
 archived_time:=clock_timestamp();
 update public.teams set status='archived',archived_at=archived_time,updated_at=archived_time where id=t.id;
 -- Scope authorization does not grant private historical content access.
 -- Existing Team lifecycle predicates revoke Workspace/Chat access immediately.
 perform public.persist_m5_team_event('TEAM_ARCHIVED',t.id);
 return jsonb_build_object('teamId',t.id,'status','archived','archivedAt',archived_time);
end $$;
revoke all on function public.archive_team(uuid) from public,anon,authenticated,service_role;
grant execute on function public.archive_team(uuid) to authenticated;
comment on function public.archive_team(uuid) is 'M5.13 identity-bound archive; preserves collaboration rows. No restore, historical browsing or archive notifications.';
commit;
