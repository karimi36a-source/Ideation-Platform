begin;
-- Resource-only helpers derive the caller from verified auth context. Definers
-- avoid Team/Workspace/membership RLS recursion; no caller user ID is accepted.
create function public.can_manage_team(target_team uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.teams t join public.cohorts c on c.id=t.cohort_id
  join public.programs p on p.id=c.program_id where t.id=target_team and (
   public.has_active_role_in_organization('ADMIN',p.organization_id)
   or public.has_active_role_in_cohort('MASTER',c.id)
   or public.has_active_role_in_team('MASTER',t.id)));
$$;
create function public.get_team_workspace_access(target_workspace uuid) returns text
 language sql stable security definer set search_path='' as $$
 select m.membership_role::text from public.workspaces w
 join public.teams t on t.id=w.team_id and t.workspace_id=w.id and t.cohort_id=w.cohort_id
 join public.team_memberships m on m.team_id=t.id
 where w.id=target_workspace and w.workspace_type='TEAM' and w.status='active' and w.visibility='private'
  and t.status in ('created','active') and m.user_id=public.current_platform_user_id()
  and m.status='active' and m.left_at is null and m.joined_at<=statement_timestamp()
  and exists(select 1 from public.enrollments e where e.user_id=m.user_id and e.cohort_id=t.cohort_id
   and e.status='active' and e.enrollment_role='participant');
$$;
create function public.can_access_team_chat(target_channel uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_channels ch join public.chat_memberships cm on cm.chat_channel_id=ch.id
  where ch.id=target_channel and ch.channel_type='TEAM' and ch.status='active'
   and public.get_team_workspace_access(ch.workspace_id) is not null
   and cm.user_id=public.current_platform_user_id() and cm.left_at is null and cm.joined_at<=statement_timestamp());
$$;
-- Safe role/capability metadata only; inaccessible and nonexistent channels both
-- return null, and platform Admin/Master roles do not confer Chat access.
create function public.get_team_chat_access(target_channel uuid) returns text
 language sql stable security definer set search_path='' as $$
 select case when public.get_team_workspace_access(ch.workspace_id)='mentor' then 'read' else cm.access_level::text end
 from public.chat_channels ch join public.chat_memberships cm on cm.chat_channel_id=ch.id
 where ch.id=target_channel and cm.user_id=public.current_platform_user_id() and cm.left_at is null
  and public.can_access_team_chat(ch.id);
$$;
create function public.team_workspace_has_chat_access(target_workspace uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_channels ch where ch.workspace_id=target_workspace
  and public.can_access_team_chat(ch.id));
$$;
revoke all on function public.can_manage_team(uuid),public.get_team_workspace_access(uuid),public.can_access_team_chat(uuid),public.get_team_chat_access(uuid),public.team_workspace_has_chat_access(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_manage_team(uuid),public.get_team_workspace_access(uuid),public.can_access_team_chat(uuid),public.get_team_chat_access(uuid),public.team_workspace_has_chat_access(uuid) to authenticated;
-- Only operational Team metadata is exposed to mutation-authorized actors.
grant select on public.teams,public.chat_channels,public.chat_memberships,public.chat_messages to authenticated;
create policy teams_scoped_operational_read on public.teams for select to authenticated using(public.can_manage_team(id));
create policy workspaces_active_team_member_read on public.workspaces for select to authenticated
 using(workspace_type='TEAM' and public.get_team_workspace_access(id) is not null);
create policy chat_channels_active_team_member_read on public.chat_channels for select to authenticated using(public.can_access_team_chat(id));
create policy chat_memberships_own_active_team_read on public.chat_memberships for select to authenticated
 using(user_id=public.current_platform_user_id() and left_at is null and public.can_access_team_chat(chat_channel_id));
create policy chat_messages_active_team_read on public.chat_messages for select to authenticated using(public.can_access_team_chat(chat_channel_id));
-- No direct client mutation grants/policies and no message operations.
create function public.add_team_member(target_team uuid,target_user uuid,kind public.team_membership_role)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; t public.teams; c public.cohorts; org uuid; ch public.chat_channels;
 mid uuid; cmid uuid;
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
 if kind is null or t.status not in ('created','active') then raise exception 'Invalid membership input' using errcode='22023';end if;
 perform 1 from public.users where id=target_user and account_status='active' for share;
 if not found then raise exception 'Invalid member' using errcode='22023';end if;
 perform 1 from public.enrollments where cohort_id=t.cohort_id and user_id=target_user and status='active' and enrollment_role='participant' for share;
 if not found then raise exception 'Invalid member' using errcode='22023';end if;
 perform 1 from public.workspaces where id=t.workspace_id and team_id=t.id and cohort_id=t.cohort_id
  and workspace_type='TEAM' and status='active' and visibility='private' for share;
 if not found then raise exception 'Invalid Team Workspace' using errcode='22023';end if;
 if exists(select 1 from public.team_memberships where team_id=t.id and user_id=target_user and status='active') then
  raise exception 'Duplicate active membership' using errcode='23505';end if;
 if t.team_lead_user_id=target_user and kind<>'team_lead' then raise exception 'Invalid Team Lead role' using errcode='22023';end if;
 if kind='team_lead' and ((t.team_lead_user_id is not null and t.team_lead_user_id<>target_user)
  or exists(select 1 from public.team_memberships where team_id=t.id and status='active' and membership_role='team_lead' and user_id<>target_user)) then
  raise exception 'Team Lead replacement requires explicit operation' using errcode='22023';end if;
 if (select count(*) from public.chat_channels where channel_type='TEAM' and team_id=t.id and workspace_id=t.workspace_id and cohort_id=t.cohort_id and status='active')<>1 then
  raise exception 'Invalid Team Chat' using errcode='22023';end if;
 select * into ch from public.chat_channels where channel_type='TEAM' and team_id=t.id and workspace_id=t.workspace_id and cohort_id=t.cohort_id and status='active' for update;
 insert into public.team_memberships(team_id,user_id,membership_role,joined_at,status,added_by)
  values(t.id,target_user,kind,statement_timestamp(),'active',actor) returning id into mid;
 -- Reuse a current open Chat membership; never reopen a historical closed row.
 select id into cmid from public.chat_memberships where chat_channel_id=ch.id and user_id=target_user and left_at is null for update;
 if cmid is null then
  insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at)
   values(ch.id,target_user,case when kind='mentor' then 'read'::public.chat_access_level else 'read_write'::public.chat_access_level end,statement_timestamp()) returning id into cmid;
 else
  if exists(select 1 from public.chat_memberships where id=cmid and joined_at>statement_timestamp()) then raise exception 'Invalid Chat membership' using errcode='22023';end if;
  update public.chat_memberships set access_level=case when kind='mentor' then 'read'::public.chat_access_level else 'read_write'::public.chat_access_level end where id=cmid;
 end if;
 if kind='team_lead' then update public.teams set team_lead_user_id=target_user,updated_at=clock_timestamp() where id=t.id;end if;
 -- Audit MEMBER_ADDED and notifications deferred to M5.12.
 return jsonb_build_object('teamId',t.id,'membershipId',mid,'chatMembershipId',cmid);
end $$;
revoke all on function public.add_team_member(uuid,uuid,public.team_membership_role) from public,anon,authenticated,service_role;
grant execute on function public.add_team_member(uuid,uuid,public.team_membership_role) to authenticated;
-- A single current Chat access record per identity/channel; old rows are retained.
create unique index chat_memberships_one_open on public.chat_memberships(chat_channel_id,user_id) where left_at is null;
commit;
