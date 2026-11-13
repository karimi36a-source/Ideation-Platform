begin;
-- Boolean eligibility only. No mapping read grants, provider calls, token
-- issuance, membership changes, or changes to the M16 room lifecycle.
create function public.can_join_live_session(target_room uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.live_session_rooms r
  join public.cohorts c on c.id=r.cohort_id
  join public.session_definitions s on s.id=r.session_definition_id and s.curriculum_version_id=c.curriculum_version_id
  join public.enrollments e on e.cohort_id=c.id
  where r.id=target_room and r.provider='DAILY' and r.status='ACTIVE' and r.ended_at is null
   and c.status='active' and s.status='active'
   and e.user_id=public.current_platform_user_id() and e.enrollment_role='participant'
   and e.status='active' and e.joined_at<=statement_timestamp()
 );
$$;
revoke all on function public.can_join_live_session(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_join_live_session(uuid) to authenticated;
comment on function public.can_join_live_session(uuid) is 'M16.4 caller-bound current Student eligibility only. Room IDs/references confer no authority; does not issue provider tokens or grant source/room row access.';
commit;
