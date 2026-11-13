\set ON_ERROR_STOP on
begin;
-- Deterministic identities: Admin, assigned/unrelated Masters, A1/A2/B1/B2,
-- plus Mentor for negative authority regression. Resources use canonical RPC IDs.
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'team-acceptance-'||n||'@example.test' from generate_series(6001,6008) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'team-acceptance-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('00000000-0000-4000-8000-'||lpad((case when n=6001 then 101 when n=6008 then 103 else 104 end)::text,12,'0'))::uuid,
 '00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000006001'
 from generate_series(6001,6008) n where n not in (6002,6003);
create temporary table acceptance_cohorts(label text primary key,id uuid);grant select,insert on acceptance_cohorts to authenticated;
create temporary table acceptance_teams(label text primary key,payload jsonb);grant select,insert on acceptance_teams to authenticated;
create temporary table acceptance_messages(label text primary key,payload jsonb);grant select,insert on acceptance_messages to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into acceptance_cohorts values('Test',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Professional Course Test Cohort','2026-10-01',null,'00000000-0000-4000-8000-000000006002','active','{}')->>'id')::uuid);
insert into acceptance_cohorts values('Unrelated',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Unrelated acceptance cohort','2026-10-01',null,'00000000-0000-4000-8000-000000006003','active','{}')->>'id')::uuid);
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
 select c.id,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'participant','active' from acceptance_cohorts c cross join generate_series(6004,6008) n where c.label='Test';
-- Canonical Personal provisioning, retained unchanged through all Team operations.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select public.create_personal_workspace();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);select public.create_personal_workspace();
create temporary table acceptance_personal as select id,to_jsonb(w) data from public.workspaces w where workspace_type='PERSONAL' and owner_user_id in ('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into acceptance_teams values('A',public.create_team((select id from acceptance_cohorts where label='Test'),'Team A'));
insert into acceptance_teams values('B',public.create_team((select id from acceptance_cohorts where label='Test'),'Team B'));
insert into acceptance_teams values('C',public.create_team((select id from acceptance_cohorts where label='Test'),'Team C'));
reset role;
do $$ declare x record;begin
 for x in select * from acceptance_teams loop
 assert exists(select 1 from public.teams t join public.workspaces w on w.id=t.workspace_id join public.chat_channels ch on ch.team_id=t.id
 where t.id=(x.payload->>'teamId')::uuid and w.id=(x.payload->>'workspaceId')::uuid and ch.id=(x.payload->>'chatChannelId')::uuid
 and w.workspace_type='TEAM' and w.team_id=t.id and t.cohort_id=w.cohort_id and ch.cohort_id=t.cohort_id and ch.workspace_id=w.id and ch.channel_type='TEAM'
 and t.cohort_id=(select id from acceptance_cohorts where label='Test')),'AT-TEAM-001 canonical relationships';
 assert exists(select 1 from public.audit_events where event_type='TEAM_CREATED' and entity_id=(x.payload->>'teamId')::uuid and actor_user_id='00000000-0000-4000-8000-000000006002'),'AT-TEAM-001 audit';
 end loop;
end $$;
set local role authenticated;
do $$ declare n integer;begin
 foreach n in array array[6003,6004,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.create_team((select id from acceptance_cohorts where label='Test'),'Unauthorized Team');raise exception 'unauthorized create';exception when insufficient_privilege then null;end;
 end loop;
end $$;
\echo M5.14 AT-TEAM-001 PASS
-- Assigned Master and organization Admin each add eligible participants.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='C'),'00000000-0000-4000-8000-000000006004','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','team_lead');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007','member');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='C'),'00000000-0000-4000-8000-000000006005','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006008','mentor');
do $$begin begin perform public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='C'),'00000000-0000-4000-8000-000000006004','member');raise exception 'duplicate accepted';exception when unique_violation then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$ declare w uuid;ch uuid;begin
 select (payload->>'workspaceId')::uuid,(payload->>'chatChannelId')::uuid into w,ch from acceptance_teams where label='C';
 assert public.get_team_workspace_access(w)='member' and public.get_team_chat_access(ch)='read_write','AT-TEAM-002 access';
 assert exists(select 1 from public.chat_memberships where chat_channel_id=ch and user_id=auth.uid() and access_level='read_write' and left_at is null),'Chat membership';
 assert exists(select 1 from public.notifications where recipient_user_id=auth.uid() and notification_type='MEMBER_ADDED' and entity_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='C')),'affected user notification';
 assert not exists(select 1 from public.workspaces where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000006005'),'Personal isolation';
end $$;
insert into acceptance_messages values('C',public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='C'),'Private Team C authored history'));
insert into acceptance_messages values('A',public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'Private Team A history, never copied'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
insert into acceptance_messages values('B',public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'Private Team B history'));
reset role;
do $$begin assert exists(select 1 from public.audit_events where event_type='MEMBER_ADDED' and metadata->>'userId'='00000000-0000-4000-8000-000000006004' and entity_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='C')),'add audit';end $$;
\echo M5.14 AT-TEAM-002 PASS
-- Contextual Team Lead/Mentor, Student and unrelated Master cannot manage members.
set local role authenticated;
do $$ declare n integer;t uuid;begin
 t:=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
 foreach n in array array[6003,6004,6005,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.add_team_member(t,'00000000-0000-4000-8000-000000006005','member');raise exception 'unauthorized add';exception when insufficient_privilege then null;end;
 begin perform public.remove_team_member(t,'00000000-0000-4000-8000-000000006004');raise exception 'unauthorized remove';exception when insufficient_privilege then null;end;
 begin perform public.move_team_member('00000000-0000-4000-8000-000000006004',t,(select (payload->>'teamId')::uuid from acceptance_teams where label='B'));raise exception 'unauthorized move';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='C'),'00000000-0000-4000-8000-000000006004');
reset role;
do $$begin
 assert exists(select 1 from public.team_memberships where team_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='C') and user_id='00000000-0000-4000-8000-000000006004' and status='removed' and left_at>=joined_at and removed_by='00000000-0000-4000-8000-000000006002'),'historical membership lifecycle';
 assert exists(select 1 from public.chat_messages where id=(select (payload->>'id')::uuid from acceptance_messages where label='C') and to_jsonb(chat_messages)=(select payload from acceptance_messages where label='C')),'message/sender/time unchanged';
 assert exists(select 1 from public.audit_events where event_type='MEMBER_REMOVED' and entity_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='C') and metadata->>'userId'='00000000-0000-4000-8000-000000006004'),'remove audit';
 assert exists(select 1 from public.notifications where notification_type='MEMBER_REMOVED' and entity_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='C') and recipient_user_id='00000000-0000-4000-8000-000000006004'),'remove affected notification';
end $$;
\echo M5.14 AT-TEAM-003 PASS
-- Exact known IDs: removed A1, unrelated Master, and Team-B-only Student B1.
set local role authenticated;
do $$ declare n integer;t uuid;w uuid;ch uuid;mid uuid;begin
 select (payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid,(payload->>'chatChannelId')::uuid into t,w,ch from acceptance_teams where label='C';
 mid:=(select (payload->>'id')::uuid from acceptance_messages where label='C');
 foreach n in array array[6004,6003,6006] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 assert not exists(select 1 from public.teams where id=t),'exact Team ID no metadata';
 assert not exists(select 1 from public.workspaces where id=w),'exact Workspace ID no metadata';
 assert not exists(select 1 from public.chat_channels where id=ch),'exact Channel ID no metadata';
 assert not exists(select 1 from public.chat_messages where id=mid),'exact Message ID no body/sender/time';
 assert public.get_team_workspace_access(w) is null and public.get_team_chat_access(ch) is null,'no stale capability';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||ch::text||':'||auth.uid()::text),'realtime authorization denied';
 perform set_config('realtime.topic','team-chat:'||ch::text||':'||auth.uid()::text,true);
 assert not exists(select 1 from realtime.messages),'realtime receive RLS denied';
 begin perform public.list_team_chat_messages(ch);raise exception 'direct list bypass';exception when insufficient_privilege then null;end;
 begin perform public.send_team_chat_message(t,'direct post bypass');raise exception 'direct send bypass';exception when insufficient_privilege then null;end;
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values(t,auth.uid(),'member',now(),auth.uid());raise exception 'direct self add';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin
 assert not exists(select 1 from public.workspaces where id=(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A')),'Team B cannot enumerate Team A Workspace';
 assert not exists(select 1 from public.chat_messages where chat_channel_id=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A')),'Team B cannot query Team A Chat';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||(select payload->>'chatChannelId' from acceptance_teams where label='A')||':'||auth.uid()::text),'Team B cannot subscribe Team A';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert public.get_team_chat_access((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='C'))='read_write','current C user retains authorized history';assert exists(select 1 from public.chat_messages where id=(select (payload->>'id')::uuid from acceptance_messages where label='C')),'preserved message readable by remaining member';end $$;
\echo M5.14 AT-TEAM-004 PASS
-- Move the current Team A Lead to B; no automatic Lead transfer or content copy.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.move_team_member('00000000-0000-4000-8000-000000006004',(select (payload->>'teamId')::uuid from acceptance_teams where label='A'),(select (payload->>'teamId')::uuid from acceptance_teams where label='B'));
reset role;
do $$declare a uuid;b uuid;begin
 a:=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');b:=(select (payload->>'teamId')::uuid from acceptance_teams where label='B');
 assert exists(select 1 from public.team_memberships where team_id=a and user_id='00000000-0000-4000-8000-000000006004' and status='removed' and membership_role='team_lead'),'source Lead history';
 assert exists(select 1 from public.team_memberships where team_id=b and user_id='00000000-0000-4000-8000-000000006004' and status='active' and membership_role='member'),'new target membership';
 assert (select team_lead_user_id from public.teams where id=a) is null and (select team_lead_user_id from public.teams where id=b) is null,'no automatic Lead transfer';
 assert exists(select 1 from public.chat_messages where id=(select (payload->>'id')::uuid from acceptance_messages where label='A') and to_jsonb(chat_messages)=(select payload from acceptance_messages where label='A')),'source history unchanged';
 assert not exists(select 1 from public.chat_messages where chat_channel_id=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='B') and content like '%Team A%'),'no copied private source content';
 assert (select count(*) from public.audit_events where event_type='MEMBER_MOVED' and entity_id=b and metadata->>'sourceTeamId'=a::text and metadata->>'userId'='00000000-0000-4000-8000-000000006004')=1,'canonical move audit';
 assert exists(select 1 from public.notifications where notification_type='MEMBER_MOVED' and entity_id=b and recipient_user_id='00000000-0000-4000-8000-000000006004'),'move affected notification';
 assert not exists(select 1 from acceptance_personal s left join public.workspaces w using(id) where to_jsonb(w) is distinct from s.data),'Personal unchanged';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare a jsonb;b jsonb;begin
 select payload into a from acceptance_teams where label='A';select payload into b from acceptance_teams where label='B';
 assert public.get_team_workspace_access((a->>'workspaceId')::uuid) is null and public.get_team_chat_access((a->>'chatChannelId')::uuid) is null,'source revocation';
 assert public.get_team_workspace_access((b->>'workspaceId')::uuid)='member' and public.get_team_chat_access((b->>'chatChannelId')::uuid)='read_write','target activation';
 assert not exists(select 1 from public.workspaces where id=(a->>'workspaceId')::uuid) and not exists(select 1 from public.chat_messages where chat_channel_id=(a->>'chatChannelId')::uuid),'known source IDs denied';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||(a->>'chatChannelId')||':'||auth.uid()::text),'no stale source subscription';
 assert not exists(select 1 from public.chat_messages where chat_channel_id=(b->>'chatChannelId')::uuid and content like '%Team A%'),'no source disclosure in target';
end $$;
\echo M5.14 AT-TEAM-005 PASS
-- Archive regression preserves C history and denies active use.
reset role;
create temporary table archive_history as select id,to_jsonb(m) data from public.chat_messages m;
create temporary table archive_memberships as select id,to_jsonb(m) data from public.team_memberships m;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.archive_team((select (payload->>'teamId')::uuid from acceptance_teams where label='C'));
do $$begin begin perform public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='C'),'00000000-0000-4000-8000-000000006006','member');raise exception 'archived add';exception when invalid_parameter_value then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 begin perform public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='C'),'archived message');raise exception 'archived send';exception when insufficient_privilege then null;end;
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from acceptance_teams where label='C')) is null and public.get_team_chat_access((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='C')) is null,'archived active paths denied';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
do $$begin assert not exists(select 1 from public.teams where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='C')),'unrelated archive scope denied';end $$;
reset role;
do $$begin
 assert not exists(select 1 from archive_history s left join public.chat_messages m using(id) where to_jsonb(m) is distinct from s.data),'archive messages preserved';
 assert not exists(select 1 from archive_memberships s left join public.team_memberships m using(id) where to_jsonb(m) is distinct from s.data),'archive memberships preserved';
 assert exists(select 1 from public.audit_events where event_type='TEAM_ARCHIVED' and entity_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='C')),'archive audit';
 assert not exists(select 1 from acceptance_personal s left join public.workspaces w using(id) where to_jsonb(w) is distinct from s.data),'Personal preserved after archive';
end $$;
\echo M5.14 archive/direct security regression PASS
\echo M5.14 voting history DEFERRED - requires Voting entities/runtime
\echo M5.14 Artifact direct-ID DEFERRED - requires Artifacts
set constraints all immediate;
rollback;
