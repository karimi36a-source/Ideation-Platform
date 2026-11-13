\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'add-member-'||n||'@example.test' from generate_series(4001,4020) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'add-member-%@example.test';
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000004021','add-missing-profile@example.test');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 case when n=4001 then '00000000-0000-4000-8000-000000000101'::uuid when n=4006 then '00000000-0000-4000-8000-000000000103'::uuid else '00000000-0000-4000-8000-000000000104'::uuid end,
 '00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000004001'
 from generate_series(4001,4006) n where n not in (4002,4003);
create temporary table member_cohorts(label text,id uuid);grant select,insert on member_cohorts to authenticated;
create temporary table member_teams(label text,payload jsonb);grant select,insert on member_teams to authenticated;
create temporary table member_results(label text,payload jsonb);grant select,insert on member_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
insert into member_cohorts values('A',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Member Cohort A','2026-10-01',null,'00000000-0000-4000-8000-000000004002','active','{}')->>'id')::uuid);
insert into member_cohorts values('B',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Member Cohort B','2026-10-01',null,'00000000-0000-4000-8000-000000004003','active','{}')->>'id')::uuid);
insert into member_teams values('A',public.create_team((select id from member_cohorts where label='A'),'Member Team A'));
insert into member_teams values('R',public.create_team((select id from member_cohorts where label='A'),'Rollback Team'));
insert into member_teams values('B',public.create_team((select id from member_cohorts where label='B'),'Member Team B'));
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
 select c.id,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 case when n=4013 then 'instructor'::public.enrollment_role else 'participant'::public.enrollment_role end,
 case when n=4009 then 'invited'::public.enrollment_status else 'active'::public.enrollment_status end
 from member_cohorts c cross join generate_series(4004,4020) n
 where (c.label='A' and n not in (4014,4015)) or (c.label='B' and n=4015);
update public.enrollments set status=case right(user_id::text,4) when '4010' then 'completed'::public.enrollment_status when '4011' then 'withdrawn'::public.enrollment_status else 'removed'::public.enrollment_status end
 where right(user_id::text,4) in ('4010','4011','4012');
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000004008';
-- Closed memberships remain historical on re-add; open Chat membership is reused.
insert into public.team_memberships(team_id,user_id,membership_role,joined_at,status,left_at,removed_by,added_by)
 select (payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000004020','member',now()-interval '1 day','removed',now(),'00000000-0000-4000-8000-000000004001','00000000-0000-4000-8000-000000004001' from member_teams where label='A';
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at,left_at)
 select (payload->>'chatChannelId')::uuid,'00000000-0000-4000-8000-000000004020','read_write',now()-interval '1 day',now() from member_teams where label='A';
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at)
 select (payload->>'chatChannelId')::uuid,'00000000-0000-4000-8000-000000004019','read',now() from member_teams where label='A';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
insert into member_results values('member',public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004004','member'));
insert into member_results values('lead',public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004005','team_lead'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
insert into member_results values('mentor',public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004006','mentor'));
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004007','member');
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004019','member');
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004020','member');
-- No cross-Team exclusivity is imposed.
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004004','member');
reset role;
do $$ declare r record; begin
 for r in select * from member_results loop
  assert exists(select 1 from public.team_memberships m join public.chat_memberships cm on cm.user_id=m.user_id join public.chat_channels ch on ch.id=cm.chat_channel_id
   where m.id=(r.payload->>'membershipId')::uuid and cm.id=(r.payload->>'chatMembershipId')::uuid and m.team_id=ch.team_id
   and m.status='active' and m.joined_at is not null and m.left_at is null and m.removed_by is null and cm.left_at is null
   and cm.access_level=case when r.label='mentor' then 'read'::public.chat_access_level else 'read_write'::public.chat_access_level end),'atomic synchronized lifecycle';
 end loop;
 assert (select team_lead_user_id from public.teams where id=(select (payload->>'teamId')::uuid from member_teams where label='A'))='00000000-0000-4000-8000-000000004005','Lead reference consistent';
 assert (select count(*) from public.team_memberships where user_id='00000000-0000-4000-8000-000000004020')=2,'removed membership preserved';
 assert (select count(*) from public.chat_memberships where user_id='00000000-0000-4000-8000-000000004020')=2,'closed Chat history preserved';
 assert (select count(*) from public.chat_memberships where user_id='00000000-0000-4000-8000-000000004019')=1,'open Chat membership reused';
 assert to_regclass('public.audit_events') is not null and to_regclass('public.notifications') is not null,'M5.12 persistence foundation exists';
end $$;
insert into public.chat_messages(chat_channel_id,sender_user_id,content)
 select (payload->>'chatChannelId')::uuid,'00000000-0000-4000-8000-000000004004','Private member fixture' from member_teams where label='A';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
select public.create_personal_workspace();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004007',true);
select public.create_personal_workspace();
create temporary table sent_chat(label text,payload jsonb);grant select,insert on sent_chat to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
insert into sent_chat values('first',public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='A'),'Canonical first message'));
insert into sent_chat values('reply',public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='A'),'Canonical reply',(select (payload->>'id')::uuid from sent_chat where label='first')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004005',true);
insert into sent_chat values('lead',public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='A'),'Lead message'));
reset role;
do $$ begin
 assert exists(select 1 from public.chat_messages m where to_jsonb(m)=(select payload from sent_chat where label='first') and sender_user_id='00000000-0000-4000-8000-000000004004' and created_at is not null and message_type='TEXT'),'canonical saved sender/time';
 assert (select payload->>'parent_message_id' from sent_chat where label='reply')=(select payload->>'id' from sent_chat where label='first'),'same channel parent';
end $$;
-- Tied timestamp fixture proves stable ID tie-breaker and exact precision cursor.
insert into public.chat_messages(id,chat_channel_id,sender_user_id,content,created_at)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,(payload->>'chatChannelId')::uuid,'00000000-0000-4000-8000-000000004004','Tie '||n,'2020-01-01T00:00:00.123456Z'
 from member_teams cross join generate_series(9001,9003) n where label='A';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
do $$ declare ch uuid;page jsonb;second jsonb;full_page jsonb;begin
 select (payload->>'chatChannelId')::uuid into ch from member_teams where label='A';
 full_page:=public.list_team_chat_messages(ch,100);
 assert full_page->'items' @> jsonb_build_array((select payload from sent_chat where label='first')),'reload exact canonical message';
 page:=public.list_team_chat_messages(ch,2);
 assert page->'items'->0->>'id'='00000000-0000-4000-8000-000000009001' and page->'items'->1->>'id'='00000000-0000-4000-8000-000000009002','stable ordering';
 second:=public.list_team_chat_messages(ch,2,(page->'nextCursor'->>'createdAt')::timestamptz,(page->'nextCursor'->>'id')::uuid);
 assert second->'items'->0->>'id'='00000000-0000-4000-8000-000000009003','pagination without skip/duplicate';
 assert full_page->'nextCursor'='null'::jsonb,'terminal cursor';
 begin perform public.list_team_chat_messages(ch,101);raise exception 'oversized page';exception when invalid_parameter_value then null;end;
 begin perform public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='A'),E' \n\t ');raise exception 'empty message';exception when invalid_parameter_value then null;end;
 begin perform public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='A'),chr(160)||chr(65279));raise exception 'Unicode blank message';exception when invalid_parameter_value then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(ch,'00000000-0000-4000-8000-000000004005','Spoof');raise exception 'direct insert';exception when insufficient_privilege then null;end;
 begin update public.chat_messages set content='edited' where chat_channel_id=ch;raise exception 'edit';exception when insufficient_privilege then null;end;
 begin delete from public.chat_messages where chat_channel_id=ch;raise exception 'delete';exception when insufficient_privilege then null;end;
end $$;
-- Contextual Mentor reads but cannot post.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004006',true);
do $$ begin
 assert jsonb_array_length(public.list_team_chat_messages((select (payload->>'chatChannelId')::uuid from member_teams where label='A'))->'items')>0,'mentor read';
 begin perform public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='A'),'mentor post');raise exception 'mentor posted';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- User only in unrelated Team B; no platform-role or identifier bypass.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='B'),'00000000-0000-4000-8000-000000004015','member');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004015',true);
insert into sent_chat values('other',public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='B'),'Other private Team'));
do $$ declare who text; ch uuid;begin
 select (payload->>'chatChannelId')::uuid into ch from member_teams where label='A';
 foreach who in array array['4015','4003','4001'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  assert (select count(*) from public.chat_messages where chat_channel_id=ch)=0,'RLS channel filter';
  assert (select count(*) from public.chat_messages where id=(select (payload->>'id')::uuid from sent_chat where label='first'))=0,'direct message ID';
  assert (select count(*) from public.chat_channels where id=ch)=0,'direct channel ID';
  begin perform public.list_team_chat_messages(ch);raise exception 'cross Team list';exception when insufficient_privilege then null;end;
  begin perform public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='A'),'cross Team post');raise exception 'cross Team send';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
 begin perform public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='A'),'cross channel reply',(select (payload->>'id')::uuid from sent_chat where label='other'));raise exception 'cross parent';exception when invalid_parameter_value then null;end;
end $$;
-- Removal revokes writes/reads; malicious stale open Chat membership is insufficient.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004004');
reset role;
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at)
 select (payload->>'chatChannelId')::uuid,'00000000-0000-4000-8000-000000004004','read_write',statement_timestamp() from member_teams where label='A';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
do $$ begin
 begin perform public.list_team_chat_messages((select (payload->>'chatChannelId')::uuid from member_teams where label='A'));raise exception 'removed read';exception when insufficient_privilege then null;end;
 begin perform public.send_team_chat_message((select (payload->>'teamId')::uuid from member_teams where label='A'),'stale post');raise exception 'removed post';exception when insufficient_privilege then null;end;
 assert (select count(*) from public.chat_messages where id=(select (payload->>'id')::uuid from sent_chat where label='first'))=0,'removed direct ID';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004007',true);
do $$ begin
 assert public.list_team_chat_messages((select (payload->>'chatChannelId')::uuid from member_teams where label='A'),100)->'items' @> jsonb_build_array((select payload from sent_chat where label='first')),'history preserved for authorized remaining member';
end $$;
reset role;
do $$ begin
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.send_team_chat_message(uuid,text,uuid)'::regprocedure),'safe definer';
 assert not has_function_privilege('service_role','public.send_team_chat_message(uuid,text,uuid)','EXECUTE'),'no service shortcut';
 assert not has_table_privilege('authenticated','public.chat_messages','INSERT') and not has_table_privilege('authenticated','public.chat_messages','UPDATE') and not has_table_privilege('authenticated','public.chat_messages','DELETE'),'direct mutations denied';
end $$;
set local role anon;
do $$ begin
 begin perform public.send_team_chat_message('00000000-0000-4000-8000-000000009999','anonymous');raise exception 'anonymous send';exception when insufficient_privilege then null;end;
 begin perform public.list_team_chat_messages('00000000-0000-4000-8000-000000009999');raise exception 'anonymous list';exception when insufficient_privilege then null;end;
end $$;
reset role;
set constraints all immediate;
rollback;
\echo M5.9 AT-CHAT-001/003/004 PASS - canonical TEXT, reload, cursor, parent, scope, removal and spoofing
