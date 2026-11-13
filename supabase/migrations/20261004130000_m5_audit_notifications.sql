begin;
create table public.audit_events (
 id uuid primary key default gen_random_uuid(),
 actor_user_id uuid not null references public.users(id) on delete restrict,
 event_type text not null check(event_type in ('TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED')),
 entity_type text not null check(entity_type='team'),entity_id uuid not null references public.teams(id) on delete restrict,
 scope_type text not null check(scope_type='team'),scope_id uuid not null references public.teams(id) on delete restrict,
 metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
 created_at timestamptz not null default clock_timestamp(),check(entity_id=scope_id)
);
create index audit_events_team_time on public.audit_events(scope_id,created_at,id);
create index audit_events_actor_time on public.audit_events(actor_user_id,created_at,id);
create table public.notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_user_id uuid not null references public.users(id) on delete restrict,
 notification_type text not null check(notification_type in ('MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED')),
 entity_type text not null check(entity_type='team'),entity_id uuid not null references public.teams(id) on delete restrict,
 metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
 created_at timestamptz not null default clock_timestamp()
);
create index notifications_recipient_time on public.notifications(recipient_user_id,created_at,id);
create function public.preserve_m5_event_history() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Lifecycle history is immutable' using errcode='23514';end $$;
revoke all on function public.preserve_m5_event_history() from public,anon,authenticated,service_role;
create trigger audit_events_immutable before update or delete on public.audit_events for each row execute function public.preserve_m5_event_history();
create trigger notifications_immutable before update or delete on public.notifications for each row execute function public.preserve_m5_event_history();
alter table public.audit_events enable row level security;
alter table public.notifications enable row level security;
revoke all on public.audit_events,public.notifications from public,anon,authenticated,service_role;
create policy audit_events_client_deny on public.audit_events as restrictive for all to anon,authenticated using(false) with check(false);
create policy notifications_client_insert_deny on public.notifications as restrictive for insert to anon,authenticated with check(false);
create policy notifications_client_update_deny on public.notifications as restrictive for update to anon,authenticated using(false) with check(false);
create policy notifications_client_delete_deny on public.notifications as restrictive for delete to anon,authenticated using(false);
grant select on public.notifications to authenticated;
create policy notifications_own_read on public.notifications for select to authenticated using(recipient_user_id=public.current_platform_user_id());
create policy notifications_own_read_guard on public.notifications as restrictive for select to authenticated using(recipient_user_id=public.current_platform_user_id());
create policy notifications_anonymous_deny on public.notifications as restrictive for all to anon using(false) with check(false);
-- Internal invoker: only definer transactions can reach this helper. Metadata
-- keys/values are constrained; no free-text reason, names, content, or secrets.
create function public.persist_m5_team_event(code text,target_team uuid,event_metadata jsonb default '{}',recipient uuid default null)
 returns void language plpgsql security invoker set search_path='' as $$
declare actor uuid;cohort uuid;k text;v jsonb;
begin
 actor:=public.current_platform_user_id();
 if actor is null or not public.can_manage_team(target_team) then raise exception 'Access denied' using errcode='42501';end if;
 select cohort_id into cohort from public.teams where id=target_team;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 if event_metadata is null or jsonb_typeof(event_metadata)<>'object' then raise exception 'Invalid event metadata' using errcode='22023';end if;
 for k,v in select key,value from jsonb_each(event_metadata) loop
  if k not in ('userId','membershipId','sourceTeamId','sourceMembershipId','targetMembershipId','previousLeadUserId','newLeadUserId','membershipRole') then raise exception 'Invalid event metadata' using errcode='22023';end if;
  if k='membershipRole' then
   if v#>>'{}' not in ('member','team_lead','mentor') then raise exception 'Invalid event role' using errcode='22023';end if;
  elsif v<>'null'::jsonb then
   if jsonb_typeof(v)<>'string' or v#>>'{}' !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'Invalid event identifier' using errcode='22023';end if;
  end if;
 end loop;
 if code in ('MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED') then
  if recipient is null or recipient::text is distinct from event_metadata->>'userId' then raise exception 'Invalid event recipient' using errcode='22023';end if;
 elsif recipient is not null then raise exception 'Invalid event recipient' using errcode='22023';end if;
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata)
 values(actor,code,'team',target_team,'team',target_team,event_metadata||jsonb_build_object('cohortId',cohort));
 if recipient is not null then
  insert into public.notifications(recipient_user_id,notification_type,entity_type,entity_id,metadata)
  values(recipient,code,'team',target_team,jsonb_strip_nulls(jsonb_build_object('sourceTeamId',event_metadata->'sourceTeamId')));
 end if;
end $$;
revoke all on function public.persist_m5_team_event(text,uuid,jsonb,uuid) from public,anon,authenticated,service_role;
create function public.m5_move_add_team_member_internal(target_team uuid,target_user uuid,kind public.team_membership_role)
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
 -- Canonical audit/notification persistence belongs to the enclosing move.
 return jsonb_build_object('teamId',t.id,'membershipId',mid,'chatMembershipId',cmid);
end $$;
revoke all on function public.m5_move_add_team_member_internal(uuid,uuid,public.team_membership_role) from public,anon,authenticated,service_role;
create function public.m5_move_remove_team_member_internal(target_team uuid,target_user uuid,removal_reason text default null)
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
 -- Canonical move history is persisted by the enclosing move; raw reasons are omitted.
 -- Never delete/rewrite messages, user records, Personal Workspaces or history.
 return jsonb_build_object('teamId',t.id,'membershipId',m.id);
end $$;
revoke all on function public.m5_move_remove_team_member_internal(uuid,uuid,text) from public,anon,authenticated,service_role;
create or replace function public.create_team(target_cohort uuid,team_name text,team_description text default null,lead_user uuid default null,target_project uuid default null)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; org uuid; c public.cohorts; master_id uuid; wid uuid; tid uuid; chid uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 select p.organization_id into org from public.cohorts co join public.programs p on p.id=co.program_id where co.id=target_cohort;
 if org is null or not(public.has_active_role_in_organization('ADMIN',org) or public.has_active_role_in_cohort('MASTER',target_cohort)) then
  raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.cohorts where id=target_cohort for update;
 -- Re-resolve and lock the current parent scope after any wait on the cohort.
 select organization_id into org from public.programs where id=c.program_id for share;
 if not found or not(public.has_active_role_in_organization('ADMIN',org) or public.has_active_role_in_cohort('MASTER',target_cohort)) then
  raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
  where a.user_id=actor and a.status='active' and a.starts_at<=now() and (a.ends_at is null or a.ends_at>now())
   and a.program_id is null and a.team_id is null and a.project_id is null
   and ((r.code='ADMIN' and a.organization_id=org and a.cohort_id is null)
    or (r.code='MASTER' and a.cohort_id=c.id and a.organization_id is null)) for share of a;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 if target_project is not null then raise exception 'Project dependency unavailable' using errcode='0A000';end if;
 if team_name is null or length(btrim(team_name)) not between 1 and 200 then raise exception 'Invalid Team input' using errcode='22023';end if;
 -- One Primary Master is already defined by M3; never accept a caller Master ID.
 master_id:=c.primary_master_id;
 perform 1 from public.users where id=master_id and account_status='active' for share;
 if not found then raise exception 'Invalid Team Master' using errcode='22023';end if;
 perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
  where a.user_id=master_id and r.code='MASTER' and a.cohort_id=c.id and a.status='active'
   and a.starts_at<=now() and (a.ends_at is null or a.ends_at>now())
   and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null
  for share of a;
 if not found then raise exception 'Invalid Team Master' using errcode='22023';end if;
 if lead_user is not null then
  perform 1 from public.users where id=lead_user and account_status='active' for share;
  if not found then raise exception 'Invalid Team Lead' using errcode='22023';end if;
  perform 1 from public.enrollments where user_id=lead_user and cohort_id=c.id
   and status='active' and enrollment_role='participant' for share;
  if not found then raise exception 'Invalid Team Lead' using errcode='22023';end if;
 end if;
 insert into public.workspaces(workspace_type,name,cohort_id,status,visibility,created_by,updated_by)
  values('TEAM',btrim(team_name),c.id,'active','private',actor,actor) returning id into wid;
 insert into public.teams(cohort_id,name,description,master_user_id,workspace_id,created_by)
  values(c.id,btrim(team_name),team_description,master_id,wid,actor) returning id into tid;
 update public.workspaces set team_id=tid where id=wid;
 insert into public.chat_channels(channel_type,workspace_id,team_id,cohort_id,name,status)
  values('TEAM',wid,tid,c.id,btrim(team_name),'active') returning id into chid;
 if lead_user is not null then
  if exists(select 1 from public.team_memberships where team_id=tid and user_id=lead_user and status='active') then
   raise exception 'Duplicate active membership' using errcode='23505';end if;
  insert into public.team_memberships(team_id,user_id,membership_role,status,joined_at,left_at,removed_by,added_by)
   values(tid,lead_user,'team_lead','active',pg_catalog.statement_timestamp(),null,null,actor);
  update public.teams set team_lead_user_id=lead_user where id=tid;
 end if;

 perform public.persist_m5_team_event('TEAM_CREATED',tid,jsonb_build_object('newLeadUserId',lead_user));
 return pg_catalog.jsonb_build_object('teamId',tid,'workspaceId',wid,'chatChannelId',chid);
end $$;
create or replace function public.add_team_member(target_team uuid,target_user uuid,kind public.team_membership_role)
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

 perform public.persist_m5_team_event('MEMBER_ADDED',t.id,jsonb_build_object('userId',target_user,'membershipId',mid,'membershipRole',kind),target_user);
 return jsonb_build_object('teamId',t.id,'membershipId',mid,'chatMembershipId',cmid);
end $$;
create or replace function public.remove_team_member(target_team uuid,target_user uuid,removal_reason text default null)
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

 -- Never delete/rewrite messages, user records, Personal Workspaces or history.
 perform public.persist_m5_team_event('MEMBER_REMOVED',t.id,jsonb_build_object('userId',target_user,'membershipId',m.id,'membershipRole',m.membership_role,'previousLeadUserId',t.team_lead_user_id),target_user);
 return jsonb_build_object('teamId',t.id,'membershipId',m.id);
end $$;
create or replace function public.move_team_member(target_user uuid,source_team uuid,destination_team uuid,move_reason text default null)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; src public.teams; dst public.teams; source_membership public.team_memberships;
 locked_cohort uuid; kind public.team_membership_role; removed jsonb; added jsonb; source_org uuid; target_org uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 if not public.can_manage_team(source_team) or not public.can_manage_team(destination_team) then raise exception 'Access denied' using errcode='42501';end if;
 if source_team=destination_team then raise exception 'Invalid move' using errcode='22023';end if;
 select * into src from public.teams where id=source_team;
 select * into dst from public.teams where id=destination_team;
 select p.organization_id into source_org from public.cohorts c join public.programs p on p.id=c.program_id where c.id=src.cohort_id;
 select p.organization_id into target_org from public.cohorts c join public.programs p on p.id=c.program_id where c.id=dst.cohort_id;
 if not ((public.has_active_role_in_organization('ADMIN',source_org) and public.has_active_role_in_organization('ADMIN',target_org))
  or ((public.has_active_role_in_cohort('MASTER',src.cohort_id) or public.has_active_role_in_team('MASTER',src.id))
   and (public.has_active_role_in_cohort('MASTER',dst.cohort_id) or public.has_active_role_in_team('MASTER',dst.id)))) then
  raise exception 'Access denied' using errcode='42501';end if;
 if src.cohort_id<>dst.cohort_id then raise exception 'Cross-Cohort move unavailable' using errcode='22023';end if;
 -- Same-cohort membership operations serialize here. Team locks are ordered so
 -- opposite-direction moves cannot lock the two Teams in opposite order.
 locked_cohort:=src.cohort_id;
 perform 1 from public.cohorts where id=locked_cohort for update;
 perform 1 from public.teams where id in (source_team,destination_team) order by id for update;
 select * into src from public.teams where id=source_team;
 select * into dst from public.teams where id=destination_team;
 if src.cohort_id<>locked_cohort or dst.cohort_id<>locked_cohort then raise exception 'Invalid move' using errcode='22023';end if;
 select p.organization_id into source_org from public.programs p join public.cohorts c on c.program_id=p.id where c.id=locked_cohort for share of p;
 target_org:=source_org;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
 where a.user_id=actor and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp())
  and a.program_id is null and a.project_id is null and (
   (r.code='ADMIN' and a.organization_id=source_org and a.cohort_id is null and a.team_id is null)
   or (r.code='MASTER' and a.organization_id is null and a.cohort_id=locked_cohort and a.team_id is null)
   or (r.code='MASTER' and a.organization_id is null and a.cohort_id is null and a.team_id in (src.id,dst.id))) for share of a;
 if not ((public.has_active_role_in_organization('ADMIN',source_org) and public.has_active_role_in_organization('ADMIN',target_org))
  or ((public.has_active_role_in_cohort('MASTER',src.cohort_id) or public.has_active_role_in_team('MASTER',src.id))
   and (public.has_active_role_in_cohort('MASTER',dst.cohort_id) or public.has_active_role_in_team('MASTER',dst.id)))) then
  raise exception 'Access denied' using errcode='42501';end if;
 select * into source_membership from public.team_memberships where team_id=src.id and user_id=target_user and status='active' for update;
 if not found then raise exception 'No active membership' using errcode='22023';end if;
 kind:=case when source_membership.membership_role='mentor' then 'mentor'::public.team_membership_role else 'member'::public.team_membership_role end;
 -- Both nested functions recheck scope/eligibility under the held locks and
 -- retain history. Any error escapes, rolling back all source/target changes.
 removed:=public.m5_move_remove_team_member_internal(src.id,target_user,move_reason);
 added:=public.m5_move_add_team_member_internal(dst.id,target_user,kind);
 perform public.persist_m5_team_event('MEMBER_MOVED',dst.id,jsonb_build_object('userId',target_user,'sourceTeamId',src.id,'sourceMembershipId',source_membership.id,'targetMembershipId',added->>'membershipId','membershipRole',kind),target_user);
 return jsonb_build_object('fromTeamId',src.id,'toTeamId',dst.id,
  'sourceMembershipId',removed->>'membershipId','targetMembershipId',added->>'membershipId','chatMembershipId',added->>'chatMembershipId');

end $$;
create or replace function public.assign_team_lead(target_team uuid,target_user uuid)
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

 if t.team_lead_user_id is distinct from target_user or m.membership_role<>'team_lead' or cm.access_level<>'read_write' then
  perform public.persist_m5_team_event('TEAM_LEAD_CHANGED',t.id,jsonb_build_object('userId',target_user,'membershipId',m.id,'previousLeadUserId',t.team_lead_user_id,'newLeadUserId',target_user));
 end if;
 return jsonb_build_object('teamId',t.id,'userId',target_user,'membershipId',m.id);
end $$;
comment on table public.audit_events is 'M5 lifecycle audit foundation. Server-only read/write, immutable, allowlisted identifiers only. TEAM_ARCHIVED reserved for M5.13.';
comment on table public.notifications is 'Minimal durable MEMBER_ADDED/REMOVED/MOVED persistence. Recipient-only SELECT; no UI, delivery, preferences, feed or read/unread lifecycle.';
commit;
