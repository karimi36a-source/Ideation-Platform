begin;
-- Narrow definer: verified actor and exact scope, no client mutation privileges.
-- The fixed path and cohort-first locks match the M5.5 transaction.
create function public.remove_team_member(target_team uuid,target_user uuid,removal_reason text default null)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; t public.teams; c public.cohorts; org uuid;
 m public.team_memberships; removed_at timestamptz;
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
 if t.status not in ('created','active') then raise exception 'Invalid membership input' using errcode='22023';end if;
 select * into m from public.team_memberships where team_id=t.id and user_id=target_user and status='active' for update;
 if not found then raise exception 'No active membership' using errcode='22023';end if;
 removed_at:=clock_timestamp();
 update public.team_memberships set status='removed',left_at=greatest(removed_at,joined_at),removed_by=actor where id=m.id;
 -- Close every corresponding open TEAM Chat record, including archived channels.
 -- No Chat record is required for older M5.4 Lead membership; absence is already
 -- deny-by-default. Historical closed rows and other Teams remain untouched.
 update public.chat_memberships cm set left_at=greatest(removed_at,cm.joined_at)
 from public.chat_channels ch where ch.id=cm.chat_channel_id and ch.channel_type='TEAM'
  and ch.team_id=t.id and ch.workspace_id=t.workspace_id and ch.cohort_id=t.cohort_id
  and cm.user_id=target_user and cm.left_at is null;
 if t.team_lead_user_id=target_user then
  update public.teams set team_lead_user_id=null,updated_at=removed_at where id=t.id;
 end if;
 -- MEMBER_REMOVED, optional reason persistence and notifications defer to M5.12.
 -- Never delete/rewrite messages, user records, Personal Workspaces or history.
 return jsonb_build_object('teamId',t.id,'membershipId',m.id);
end $$;
revoke all on function public.remove_team_member(uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.remove_team_member(uuid,uuid,text) to authenticated;
commit;
