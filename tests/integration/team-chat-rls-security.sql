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
-- One unrelated Team B participant with valid access only in B.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='B'),'00000000-0000-4000-8000-000000004015','member');
reset role;
create temporary table rls_target as
 select t.id team_id,t.workspace_id,ch.id channel_id,
 (select id from public.team_memberships where team_id=t.id and user_id='00000000-0000-4000-8000-000000004004' and status='active') membership_id,
 (select id from public.chat_memberships where chat_channel_id=ch.id and user_id='00000000-0000-4000-8000-000000004004' and left_at is null) chat_membership_id,
 (select id from public.chat_messages where chat_channel_id=ch.id limit 1) message_id
 from public.teams t join public.chat_channels ch on ch.team_id=t.id where t.id=(select (payload->>'teamId')::uuid from member_teams where label='A');
grant select on rls_target to authenticated,anon;
create temporary table rls_before_team as select id,to_jsonb(t) original from public.teams t;
create temporary table rls_before_members as select id,to_jsonb(m) original from public.team_memberships m;
create temporary table rls_before_chat_members as select id,to_jsonb(m) original from public.chat_memberships m;
create temporary table rls_before_personal as select id,to_jsonb(w) original from public.workspaces w where workspace_type='PERSONAL';
create function public.fici_assert_private_team_denial() returns void language plpgsql set search_path='' as $$
declare r record;begin
 select * into r from pg_temp.rls_target;
 assert (select count(*) from public.teams where id=r.team_id)=0,'exact Team metadata denied';
 assert (select count(*) from public.workspaces where id=r.workspace_id)=0,'exact Workspace denied';
 assert (select count(*) from public.chat_channels where id=r.channel_id)=0,'exact Chat Channel denied';
 assert (select count(*) from public.chat_memberships where id=r.chat_membership_id)=0,'exact Chat membership denied';
 assert (select count(*) from public.chat_messages where id=r.message_id)=0,'exact message denied';
 begin perform 1 from public.team_memberships where id=r.membership_id;
  -- With a test-only accidental grant, restrictive RLS still yields no rows.
  assert not exists(select 1 from public.team_memberships where id=r.membership_id),'exact Team membership denied';
 exception when insufficient_privilege then null;end;
 assert not public.can_receive_team_chat_broadcast('team-chat:'||r.channel_id::text||':'||auth.uid()::text),'current realtime scope denied';
 begin perform public.send_team_chat_message(r.team_id,'Unauthorized send');raise exception 'private send allowed';exception when insufficient_privilege then null;end;
 begin perform public.list_team_chat_messages(r.channel_id);raise exception 'private list allowed';exception when insufficient_privilege then null;end;
end $$;
create function public.fici_assert_direct_mutations_denied() returns void language plpgsql set search_path='' as $$
declare r record;sql_text text;begin
 select * into r from pg_temp.rls_target;
 foreach sql_text in array array[
  format('insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values(%L,%L,''member'',now(),%L)',r.team_id,auth.uid(),auth.uid()),
  format('insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at) values(%L,%L,''read_write'',now())',r.channel_id,auth.uid()),
  format('insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(%L,%L,''Direct message'')',r.channel_id,auth.uid()),
  format('insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(%L,%L,''Spoof sender'')',r.channel_id,'00000000-0000-4000-8000-000000004005')
 ] loop
  begin execute sql_text;raise exception 'Direct insert allowed';exception when insufficient_privilege then null;end;
 end loop;
 foreach sql_text in array array[
  format('update public.team_memberships set membership_role=''team_lead'' where id=%L',r.membership_id),
  format('update public.team_memberships set membership_role=''team_lead'' where user_id=%L and team_id=%L',auth.uid(),r.team_id),
  format('update public.team_memberships set status=''removed'',left_at=now(),removed_by=%L where id=%L',auth.uid(),r.membership_id),
  format('update public.team_memberships set status=''active'',left_at=null,removed_by=null where team_id=%L',r.team_id),
  format('delete from public.team_memberships where id=%L',r.membership_id),
  format('update public.teams set team_lead_user_id=%L where id=%L',auth.uid(),r.team_id),
  format('update public.teams set master_user_id=%L where id=%L',auth.uid(),r.team_id),
  format('update public.teams set cohort_id=''00000000-0000-4000-8000-000000009999'' where id=%L',r.team_id),
  format('update public.teams set workspace_id=''00000000-0000-4000-8000-000000009999'' where id=%L',r.team_id),
  format('update public.workspaces set team_id=''00000000-0000-4000-8000-000000009999'' where id=%L',r.workspace_id),
  format('update public.chat_memberships set access_level=''read_write'' where id=%L',r.chat_membership_id),
  format('update public.chat_memberships set access_level=''read_write'' where user_id=%L and chat_channel_id=%L',auth.uid(),r.channel_id),
  format('update public.chat_messages set content=''Unauthorized edit'' where id=%L',r.message_id),
  format('delete from public.chat_messages where id=%L',r.message_id)
 ] loop
  begin execute sql_text;exception when insufficient_privilege then null;end;
 end loop;
end $$;
set local role authenticated;
do $$ declare who text;begin
 -- Baseline table privileges and exact-ID privacy.
 foreach who in array array['4015','4003'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  perform public.fici_assert_private_team_denial();perform public.fici_assert_direct_mutations_denied();
 end loop;
 foreach who in array array['4004','4005','4006'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  assert (select count(*) from public.teams where id=(select team_id from rls_target))=1,'own member/Lead/Mentor Team metadata';
  assert (select count(*) from public.workspaces where id=(select workspace_id from rls_target))=1,'own Team Workspace';
  assert (select count(*) from public.chat_channels where id=(select channel_id from rls_target))=1,'own Channel';
  assert (select count(*) from public.chat_messages where id=(select message_id from rls_target))=1,'own canonical message';
  assert public.can_receive_team_chat_broadcast('team-chat:'||(select channel_id::text from rls_target)||':'||auth.uid()::text),'own realtime authorization';
  perform public.fici_assert_direct_mutations_denied();
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004006',true);
 begin perform public.send_team_chat_message((select team_id from rls_target),'Mentor post');raise exception 'Mentor writes';exception when insufficient_privilege then null;end;
 begin perform public.add_team_member((select team_id from rls_target),'00000000-0000-4000-8000-000000004014','member');raise exception 'Mentor manages';exception when insufficient_privilege then null;end;
 -- Operational Admin/assigned Master metadata does not confer private content.
 foreach who in array array['4001','4002'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  assert (select count(*) from public.teams where id=(select team_id from rls_target))=1,'scoped operational metadata';
  assert (select count(*) from public.workspaces where id=(select workspace_id from rls_target))=0,'no automatic Workspace content';
  assert (select count(*) from public.chat_channels where id=(select channel_id from rls_target))=0,'no automatic Chat';
  assert (select count(*) from public.chat_messages where id=(select message_id from rls_target))=0,'no automatic private messages';
  perform public.fici_assert_direct_mutations_denied();
 end loop;
end $$;
reset role;
-- Restrictive guards survive accidentally broad table grants/permissive policies.
grant select,insert,update,delete on public.teams,public.team_memberships,public.workspaces,public.chat_channels,public.chat_memberships,public.chat_messages to authenticated;
do $$ declare table_name text;begin
 foreach table_name in array array['teams','team_memberships','workspaces','chat_channels','chat_memberships','chat_messages'] loop
  execute format('create policy fixture_broad_all on public.%I for all to authenticated using(true) with check(true)',table_name);
 end loop;
end $$;
set local role authenticated;
do $$ declare who text;begin
 foreach who in array array['4015','4003','4004','4005','4006'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  if who in ('4015','4003') then perform public.fici_assert_private_team_denial();end if;
  perform public.fici_assert_direct_mutations_denied();
 end loop;
end $$;
reset role;
do $$ begin
 assert not exists(select 1 from rls_before_team s join public.teams t using(id) where to_jsonb(t)<>s.original),'Team identity/scope unchanged';
 assert not exists(select 1 from rls_before_members s join public.team_memberships m using(id) where to_jsonb(m)<>s.original),'membership/history unchanged';
 assert not exists(select 1 from rls_before_chat_members s join public.chat_memberships m using(id) where to_jsonb(m)<>s.original),'Chat access unchanged';
 assert not exists(select 1 from rls_before_personal s join public.workspaces w using(id) where to_jsonb(w)<>s.original),'Personal untouched';
end $$;
-- Real removal, stale Chat membership and old known IDs cease authorization.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
select public.remove_team_member((select team_id from rls_target),'00000000-0000-4000-8000-000000004004');
reset role;
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at)
 select channel_id,'00000000-0000-4000-8000-000000004004','read_write',statement_timestamp() from rls_target;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
select public.fici_assert_private_team_denial();
select public.fici_assert_direct_mutations_denied();
reset role;
do $$ declare table_name text;f record;begin
 assert exists(select 1 from public.team_memberships where id=(select membership_id from rls_target) and status='removed'),'removed history preserved';
 assert exists(select 1 from public.chat_messages where id=(select message_id from rls_target) and sender_user_id='00000000-0000-4000-8000-000000004004'),'sender history preserved';
 foreach table_name in array array['teams','team_memberships','workspaces','chat_channels','chat_memberships','chat_messages'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||table_name)::regclass),'RLS enabled';
 end loop;
 for f in select p.oid,p.prosecdef,p.proconfig,p.proowner from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in ('can_manage_team','get_team_workspace_access','get_team_chat_access','can_access_team_chat','create_team','add_team_member','remove_team_member','move_team_member','assign_team_lead','send_team_chat_message','list_team_chat_messages','can_receive_team_chat_broadcast','broadcast_team_chat_message','team_chat_broadcast_recipient') loop
  assert f.proconfig=array['search_path=""'],'fixed helper/RPC search_path';
  assert not has_function_privilege('anon',f.oid,'EXECUTE'),'no anonymous helper execution';
  assert f.proowner not in (select oid from pg_roles where rolname in ('anon','authenticated','service_role')),'trusted function ownership';
 end loop;
 assert not has_function_privilege('authenticated','public.team_chat_broadcast_recipient(uuid,uuid)','EXECUTE'),'explicit-recipient helper isolated';
 assert not has_function_privilege('authenticated','public.broadcast_team_chat_message()','EXECUTE'),'trigger-only publisher isolated';
 assert to_regclass('public.audit_events') is not null,'audit M5.12 foundation exists';
end $$;
-- Anonymous stays denied even if a future broad grant/policy is accidentally added.
grant select,insert,update,delete on public.teams,public.team_memberships,public.workspaces,public.chat_channels,public.chat_memberships,public.chat_messages to anon;
do $$ declare table_name text;begin
 foreach table_name in array array['teams','team_memberships','workspaces','chat_channels','chat_memberships','chat_messages'] loop
  execute format('create policy fixture_anon_broad on public.%I for all to anon using(true) with check(true)',table_name);
 end loop;
end $$;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
 assert (select count(*) from public.teams)=0,'anonymous Teams denied';
 assert (select count(*) from public.team_memberships)=0,'anonymous memberships denied';
 assert (select count(*) from public.workspaces where workspace_type='TEAM')=0,'anonymous Team Workspaces denied';
 assert (select count(*) from public.chat_channels)=0,'anonymous channels denied';
 assert (select count(*) from public.chat_memberships)=0,'anonymous Chat memberships denied';
 assert (select count(*) from public.chat_messages)=0,'anonymous messages denied';
end $$;
reset role;
set constraints all immediate;
rollback;
\echo M5.11 Team/Chat RLS security PASS - exact IDs, member metadata, Mentor read-only, Lead boundaries, removed/stale denial, broad-policy resistance, helper audit and preserved history
