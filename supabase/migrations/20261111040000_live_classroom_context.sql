begin;
-- Safe classroom headings only, under the existing M16.5 caller-bound gate.
create function public.get_live_classroom_context(target_room uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform public.authorize_live_session_join(target_room);
 select jsonb_build_object('liveSessionRoomId',r.id,'cohortId',c.id,'cohortName',c.name,'sessionDefinitionId',s.id,'sessionTitle',s.title)
 into result from public.live_session_rooms r join public.cohorts c on c.id=r.cohort_id join public.session_definitions s on s.id=r.session_definition_id where r.id=target_room;
 return result;
end $$;
revoke all on function public.get_live_classroom_context(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_live_classroom_context(uuid) to authenticated;
commit;
