begin;
-- Caller-bound projection for token issuance only; no mapping read grants.
create function public.authorize_live_session_join(target_room uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare room public.live_session_rooms; actor uuid; participant_role text; display text;
begin
 actor:=public.current_platform_user_id();
 select * into room from public.live_session_rooms where id=target_room and provider='DAILY' and status='ACTIVE' and ended_at is null;
 if actor is null or room.id is null then raise exception 'Access denied' using errcode='42501';end if;
 if public.can_join_live_session(target_room) then participant_role:='STUDENT';
 else
  perform private.master_live_room_context(room.cohort_id,room.session_definition_id,null,actor);
  -- Scoped Admin room management alone does not grant a Master participant role.
  if not exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.user_id=actor and r.code='MASTER' and r.is_system_role and a.cohort_id=room.cohort_id and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp()) and num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id)=1) then raise exception 'Access denied' using errcode='42501';end if;
  participant_role:='MASTER';
 end if;
 select coalesce(nullif(btrim(display_name),''),'FICI participant') into display from public.users where id=actor and account_status='active';
 if display is null then raise exception 'Access denied' using errcode='42501';end if;
 return jsonb_build_object('liveSessionRoomId',room.id,'providerRoomRef',room.provider_room_ref,'userId',actor,'displayName',left(display,255),'participantRole',participant_role);
end $$;
revoke all on function public.authorize_live_session_join(uuid) from public,anon,authenticated,service_role;
grant execute on function public.authorize_live_session_join(uuid) to authenticated;
commit;
