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

select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005','team_lead');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006008','mentor');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007','member');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into acceptance_messages values('first',public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'Canonical Team A message 1'));
insert into acceptance_messages values('second',public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'Canonical Team A message 2'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into acceptance_messages values('Lead',public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'Team Lead canonical message'));
reset role;
do $$declare r record;ch uuid;begin
 ch:=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A');
 for r in select * from acceptance_messages loop
 assert exists(select 1 from public.chat_messages m where m.id=(r.payload->>'id')::uuid and to_jsonb(m)=r.payload and m.chat_channel_id=ch and m.created_at is not null and m.message_type='TEXT'),'canonical row/sender/timestamp persistence';
 assert r.payload->>'sender_user_id'=case when r.label='Lead' then '00000000-0000-4000-8000-000000006005' else '00000000-0000-4000-8000-000000006004' end,'server sender identity';
 assert exists(select 1 from realtime.messages where event='team.message.created' and private and payload=jsonb_build_object('chatChannelId',ch,'messageId',r.payload->>'id') and topic='team-chat:'||ch::text||':00000000-0000-4000-8000-000000006005'),'authorized A2 recipient references canonical ID only';
 end loop;
 assert not exists(select 1 from realtime.messages where event='team.message.created' and (topic like '%00000000-0000-4000-8000-000000006006' or topic like '%00000000-0000-4000-8000-000000006003')),'no Team B/unrelated Master publication';
end $$;
-- Replay duplicate event at the test-only publisher boundary: no canonical INSERT.
create temporary table canonical_count as select count(*) n from public.chat_messages;
insert into realtime.messages(topic,event,payload,private) select topic,event,payload,private from realtime.messages where payload->>'messageId'=(select payload->>'id' from acceptance_messages where label='first') and topic like '%00000000-0000-4000-8000-000000006004';
do $$begin assert (select count(*) from public.chat_messages)=(select n from canonical_count),'duplicate notification is not duplicate canonical storage';end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare ch uuid;begin
 ch:=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A');
 assert public.can_receive_team_chat_broadcast('team-chat:'||ch::text||':'||auth.uid()::text),'Team A realtime authorization';
 perform set_config('realtime.topic','team-chat:'||ch::text||':'||auth.uid()::text,true);
 assert exists(select 1 from realtime.messages where payload->>'messageId'=(select payload->>'id' from acceptance_messages where label='first')),'private receive RLS';
 begin perform realtime.send('{}','team.message.created',current_setting('realtime.topic'),true);raise exception 'client broadcast';exception when insufficient_privilege then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(ch,'00000000-0000-4000-8000-000000006005','spoofed sender');raise exception 'sender spoof';exception when insufficient_privilege then null;end;
end $$;
\echo M5.15 AT-CHAT-001 PASS
-- Reconnect/new authenticated load reads canonical PostgreSQL without Broadcast.
reset role;
-- Drop ephemeral test-only delivery capture: history must still reload unchanged.
truncate realtime.messages;
create temporary table reloads(label text,payload jsonb);grant select,insert on reloads to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into reloads values('refresh',public.list_team_chat_messages((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A')));
insert into reloads values('page1',public.list_team_chat_messages((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A'),1));
insert into reloads values('page2',public.list_team_chat_messages((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A'),1,(select (payload->'nextCursor'->>'createdAt')::timestamptz from reloads where label='page1'),(select (payload->'nextCursor'->>'id')::uuid from reloads where label='page1')));
insert into reloads values('page3',public.list_team_chat_messages((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A'),1,(select (payload->'nextCursor'->>'createdAt')::timestamptz from reloads where label='page2'),(select (payload->'nextCursor'->>'id')::uuid from reloads where label='page2')));
do $$begin
 assert (select jsonb_array_length(payload->'items') from reloads where label='refresh')=3,'fresh load canonical history';
 assert (select payload->'items'->0 from reloads where label='page1')=(select payload from acceptance_messages where label='first'),'ordered first';
 assert (select payload->'items'->0 from reloads where label='page2')=(select payload from acceptance_messages where label='second'),'ordered second';
 assert (select payload->'items'->0 from reloads where label='page3')=(select payload from acceptance_messages where label='Lead'),'ordered Lead message';
 assert (select payload->'nextCursor' from reloads where label='page3')='null'::jsonb,'last page cursor';
end $$;
\echo M5.15 AT-CHAT-004 PASS
-- Exact Channel/Message IDs, Team A teamId, and spoofed recipient cannot authorize B.
do $$declare n integer;t uuid;ch uuid;mid uuid;begin
 t:=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');ch:=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A');mid:=(select (payload->>'id')::uuid from acceptance_messages where label='first');
 foreach n in array array[6006,6007,6003] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 assert not exists(select 1 from public.chat_channels where id=ch),'exact channel no metadata';
 assert not exists(select 1 from public.chat_messages where id=mid or chat_channel_id=ch),'exact message/channel query denied';
 assert public.get_team_chat_access(ch) is null,'forged resource IDs no capability';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||ch::text||':'||auth.uid()::text),'cross-Team subscription';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||ch::text||':00000000-0000-4000-8000-000000006004'),'recipient identity spoof';
 begin perform public.list_team_chat_messages(ch);raise exception 'cross-Team list';exception when insufficient_privilege then null;end;
 begin perform public.send_team_chat_message(t,'forged Team A ID');raise exception 'cross-Team send';exception when insufficient_privilege then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(ch,auth.uid(),'direct cross-Team insert');raise exception 'direct insert';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','',true);
do $$begin assert not public.can_receive_team_chat_broadcast('team-chat:'||(select payload->>'chatChannelId' from acceptance_teams where label='A')||':00000000-0000-4000-8000-000000006004'),'anonymous subscription';end $$;
\echo M5.15 AT-CHAT-002 PASS
-- Contextual Mentor reads only own Team, cannot post or forge direct insertion.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
do $$declare ch uuid;begin
 ch:=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A');
 assert public.get_team_chat_access(ch)='read','Mentor read only';
 assert jsonb_array_length(public.list_team_chat_messages(ch)->'items')=3,'Mentor own history read';
 assert public.get_team_chat_access((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='B')) is null,'Mentor no cross-Team read';
 begin perform public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'Mentor post');raise exception 'Mentor posted';exception when insufficient_privilege then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(ch,auth.uid(),'Mentor insert');raise exception 'Mentor direct insert';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert public.get_team_chat_access((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A'))='read_write','Lead own read/write';assert public.get_team_chat_access((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='B')) is null,'Lead no cross-Team access';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
reset role;
-- Deliberately retain a stale open Chat membership, without active Team membership.
update public.chat_memberships set left_at=null where user_id='00000000-0000-4000-8000-000000006004' and chat_channel_id=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare t uuid;ch uuid;mid uuid;begin
 t:=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');ch:=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A');mid:=(select (payload->>'id')::uuid from acceptance_messages where label='first');
 assert public.get_team_chat_access(ch) is null,'stale Chat membership no authorization';
 assert not exists(select 1 from public.chat_messages where id=mid or chat_channel_id=ch),'removed read denied';
 assert not exists(select 1 from public.chat_channels where id=ch),'removed metadata denied';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||ch::text||':'||auth.uid()::text),'removed reconnect authorization';
 begin perform public.send_team_chat_message(t,'removed send');raise exception 'removed send accepted';exception when insufficient_privilege then null;end;
 begin perform public.list_team_chat_messages(ch);raise exception 'removed reload accepted';exception when insufficient_privilege then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(ch,auth.uid(),'removed insert');raise exception 'removed insert accepted';exception when insufficient_privilege then null;end;
end $$;
\echo M5.15 AT-CHAT-003 PASS
-- Archive keeps all canonical messages and prevents normal Chat/realtime activity.
reset role;
create temporary table chat_before_archive as select id,to_jsonb(m) data from public.chat_messages m;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.archive_team((select (payload->>'teamId')::uuid from acceptance_teams where label='A'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare t uuid;ch uuid;begin
 t:=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');ch:=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A');
 assert public.get_team_chat_access(ch) is null and not public.can_receive_team_chat_broadcast('team-chat:'||ch::text||':'||auth.uid()::text),'archive subscription denied';
 begin perform public.send_team_chat_message(t,'archive send');raise exception 'archive send accepted';exception when insufficient_privilege then null;end;
 begin perform realtime.send('{}','team.message.created','team-chat:'||ch::text||':'||auth.uid()::text,true);raise exception 'archive write bypass';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin assert not exists(select 1 from chat_before_archive s left join public.chat_messages m using(id) where to_jsonb(m) is distinct from s.data),'archive canonical messages/attribution preserved';assert exists(select 1 from public.chat_channels where id=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A')),'archive Channel preserved';end $$;
\echo M5.15 Mentor/Lead/archive/sender security PASS
\echo M5.15 hosted websocket transport NOT EXERCISED - local deterministic realtime fixture
set constraints all immediate;
rollback;
