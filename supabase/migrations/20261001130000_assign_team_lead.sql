begin;
-- Narrow definer avoids RLS recursion while retaining verified actor/scope checks.
create function public.assign_team_lead(target_team uuid,target_user uuid)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; t public.teams; c public.cohorts; org uuid; ch public.chat_channels;
 m public.team_memberships; cm public.chat_memberships;
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
 if t.status not in ('created','active') then raise exception 'Invalid Team state' using errcode='22023';end if;
 perform 1 from public.users where id=target_user and account_status='active' for share;
 if not found then raise exception 'Invalid member' using errcode='22023';end if;
 select * into m from public.team_memberships where team_id=t.id and user_id=target_user and status='active' and left_at is null and joined_at<=statement_timestamp() for update;
 if not found then raise exception 'Invalid active membership' using errcode='22023';end if;
 -- Retain the approved current enrollment gate used for Team access/role changes.
 perform 1 from public.enrollments where cohort_id=t.cohort_id and user_id=target_user and status='active' and enrollment_role='participant' for share;
 if not found then raise exception 'Invalid member' using errcode='22023';end if;
 if (t.team_lead_user_id is not null and t.team_lead_user_id<>target_user)
  or exists(select 1 from public.team_memberships where team_id=t.id and status='active' and membership_role='team_lead' and user_id<>target_user)
 then raise exception 'Team Lead conflict' using errcode='23505';end if;
 perform 1 from public.workspaces where id=t.workspace_id and team_id=t.id and cohort_id=t.cohort_id and workspace_type='TEAM' and status='active' and visibility='private' for share;
 if not found then raise exception 'Invalid Team Workspace' using errcode='22023';end if;
 if (select count(*) from public.chat_channels where channel_type='TEAM' and team_id=t.id and workspace_id=t.workspace_id and cohort_id=t.cohort_id and status='active')<>1 then raise exception 'Invalid Team Chat' using errcode='22023';end if;
 select * into ch from public.chat_channels where channel_type='TEAM' and team_id=t.id and workspace_id=t.workspace_id and cohort_id=t.cohort_id and status='active' for update;
 -- Assignment never provisions missing Chat access or reopens historical rows.
 select * into cm from public.chat_memberships where chat_channel_id=ch.id and user_id=target_user and left_at is null and joined_at<=statement_timestamp() for update;
 if not found then raise exception 'Invalid Chat membership' using errcode='22023';end if;
 if t.team_lead_user_id is distinct from target_user then
  update public.teams set team_lead_user_id=target_user,updated_at=clock_timestamp() where id=t.id;
 end if;
 if m.membership_role<>'team_lead' then update public.team_memberships set membership_role='team_lead' where id=m.id;end if;
 if cm.access_level<>'read_write' then update public.chat_memberships set access_level='read_write' where id=cm.id;end if;
 -- TEAM_LEAD_ASSIGNED audit deferred to M5.12; no platform role changes.
 return jsonb_build_object('teamId',t.id,'userId',target_user,'membershipId',m.id);
end $$;
revoke all on function public.assign_team_lead(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.assign_team_lead(uuid,uuid) to authenticated;
commit;
