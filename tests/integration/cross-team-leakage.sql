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

reset role;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006009','unrelated-mentor-security@example.test'),('00000000-0000-4000-8000-000000006010','removed-former-security@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006009','active');select public.provision_user_profile('00000000-0000-4000-8000-000000006010','active');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000006009','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000006001');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,u,'participant','active' from acceptance_cohorts cross join unnest(array['00000000-0000-4000-8000-000000006009'::uuid,'00000000-0000-4000-8000-000000006010'::uuid]) u where label='Test';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006009','mentor');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006010','member');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006010',true);
insert into acceptance_messages values('former',public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'Preserved former-member Team A history'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into acceptance_messages values('A',public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'Private Team A security fixture'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
insert into acceptance_messages values('B',public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'Legitimate Team B message'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006010');
reset role;
-- Explicit stale Chat access fixture must not bypass removed Team membership.
update public.chat_memberships set left_at=null where user_id='00000000-0000-4000-8000-000000006010' and chat_channel_id=(select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A');
create temporary table leakage_target as select (payload->>'teamId')::uuid t,(payload->>'workspaceId')::uuid w,(payload->>'chatChannelId')::uuid ch,(select (payload->>'id')::uuid from acceptance_messages where label='A') mid,(select id from acceptance_cohorts where label='Test') cohort from acceptance_teams where label='A';grant select on leakage_target to authenticated,anon;
-- Snapshot every private M5 row; attempts must leave contents/history unchanged.
create temporary table leakage_before as
 select 'teams' kind,id,to_jsonb(t) data from public.teams t union all select 'team_memberships',id,to_jsonb(t) from public.team_memberships t
 union all select 'workspaces',id,to_jsonb(t) from public.workspaces t union all select 'chat_channels',id,to_jsonb(t) from public.chat_channels t
 union all select 'chat_memberships',id,to_jsonb(t) from public.chat_memberships t union all select 'chat_messages',id,to_jsonb(t) from public.chat_messages t;
create function pg_temp.deny_mutation(command text) returns void language plpgsql set search_path='' as $$declare affected bigint;begin
 begin execute command;get diagnostics affected=row_count;assert affected=0,'unauthorized mutation affected rows';exception when insufficient_privilege then null;end;
end $$;
create function pg_temp.attack_private_team() returns void language plpgsql set search_path='' as $$declare x record;tab text;filter text;num bigint;who uuid;begin
 select * into x from pg_temp.leakage_target;who:=auth.uid();
 foreach tab in array array['teams','team_memberships','workspaces','chat_channels','chat_memberships','chat_messages'] loop
 filter:=case when tab='teams' then format('id=%L',x.t) when tab='team_memberships' then format('team_id=%L',x.t) when tab='workspaces' then format('id=%L',x.w) when tab='chat_channels' then format('id=%L',x.ch) else format('chat_channel_id=%L',x.ch) end;
 begin execute format('select count(*) from public.%I where %s',tab,filter) into num;assert num=0,'private rows/metadata returned';exception when insufficient_privilege then null;end;
 perform pg_temp.deny_mutation(format('delete from public.%I where %s',tab,filter));
 end loop;
 perform pg_temp.deny_mutation(format('insert into public.teams(cohort_id,name,master_user_id,workspace_id,created_by) values(%L,''forged'',%L,%L,%L)',x.cohort,'00000000-0000-4000-8000-000000006002',x.w,who));
 perform pg_temp.deny_mutation(format('insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values(%L,%L,''team_lead'',now(),%L)',x.t,who,who));
 perform pg_temp.deny_mutation(format('insert into public.workspaces(workspace_type,name,team_id,cohort_id,created_by,updated_by) values(''TEAM'',''forged'',%L,%L,%L,%L)',x.t,x.cohort,who,who));
 perform pg_temp.deny_mutation(format('insert into public.chat_channels(channel_type,workspace_id,team_id,cohort_id,name) values(''TEAM'',%L,%L,%L,''forged'')',x.w,x.t,x.cohort));
 perform pg_temp.deny_mutation(format('insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at) values(%L,%L,''read_write'',now())',x.ch,who));
 perform pg_temp.deny_mutation(format('insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(%L,%L,''spoofed sender'')',x.ch,'00000000-0000-4000-8000-000000006004'));
 perform pg_temp.deny_mutation(format('update public.teams set team_lead_user_id=%L,master_user_id=%L,cohort_id=%L,workspace_id=%L where id=%L',who,who,'00000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000009998',x.t));
 perform pg_temp.deny_mutation(format('update public.team_memberships set status=''active'',left_at=null,removed_by=null,membership_role=''team_lead'' where team_id=%L',x.t));
 perform pg_temp.deny_mutation(format('update public.workspaces set owner_user_id=%L,team_id=null,cohort_id=null,workspace_type=''PERSONAL'',settings=''{}'' where id=%L',who,x.w));
 perform pg_temp.deny_mutation(format('update public.chat_channels set team_id=null,cohort_id=null,name=''leak'' where id=%L',x.ch));
 perform pg_temp.deny_mutation(format('update public.chat_memberships set access_level=''read_write'',left_at=null,user_id=%L where chat_channel_id=%L',who,x.ch));
 perform pg_temp.deny_mutation(format('update public.chat_messages set sender_user_id=%L,content=''rewritten'' where id=%L',who,x.mid));
end $$;
set local role authenticated;
do $$declare n integer;x record;begin
 select * into x from leakage_target;
 foreach n in array array[6006,6007,6003,6009,6010] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 perform pg_temp.attack_private_team();
 assert public.get_team_workspace_access(x.w) is null and public.get_team_chat_access(x.ch) is null,'no forged capability';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||x.ch::text||':'||auth.uid()::text),'exact topic denied';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||x.ch::text||':00000000-0000-4000-8000-000000006004'),'forged user recipient denied';
 perform set_config('realtime.topic','team-chat:'||x.ch::text||':'||auth.uid()::text,true);
 assert not exists(select 1 from realtime.messages),'realtime RLS cannot enumerate';
 begin perform public.list_team_chat_messages(x.ch);raise exception 'private list';exception when insufficient_privilege then null;end;
 begin perform public.send_team_chat_message(x.t,'known ID');raise exception 'private send';exception when insufficient_privilege then null;end;
 begin perform public.add_team_member(x.t,auth.uid(),'team_lead');raise exception 'forged role self add';exception when insufficient_privilege then null;end;
 begin perform public.assign_team_lead(x.t,auth.uid());raise exception 'Lead takeover';exception when insufficient_privilege then null;end;
 end loop;
end $$;
\echo M5.16 cross-Team/removed/role SQL mutation and enumeration attacks PASS
reset role;
set local role anon;select set_config('request.jwt.claim.sub','',true);select pg_temp.attack_private_team();
reset role;
do $$declare x record;actual jsonb;begin
 for x in select * from leakage_before loop
 execute format('select to_jsonb(t) from public.%I t where id=$1',x.kind) into actual using x.id;
 assert actual is not distinct from x.data,'private rows and history unchanged';
 end loop;
 assert exists(select 1 from public.team_memberships where user_id='00000000-0000-4000-8000-000000006010' and status='removed'),'former membership preserved';
 assert exists(select 1 from public.chat_messages where id=(select (payload->>'id')::uuid from acceptance_messages where label='former') and sender_user_id='00000000-0000-4000-8000-000000006010'),'former authorship preserved';
end $$;
-- Positive controls prevent a false isolation PASS caused by globally denied use.
set local role authenticated;
do $$declare n integer;team_label text;r jsonb;begin
 foreach n in array array[6004,6005,6006,6007] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);team_label:=case when n<6006 then 'A' else 'B' end;
 select payload into r from acceptance_teams where acceptance_teams.label=team_label;
 assert public.get_team_workspace_access((r->>'workspaceId')::uuid) is not null,'valid own Workspace';
 assert public.get_team_chat_access((r->>'chatChannelId')::uuid)='read_write','valid own Chat';
 assert jsonb_array_length(public.list_team_chat_messages((r->>'chatChannelId')::uuid)->'items')>0,'valid canonical history';
 assert public.can_receive_team_chat_broadcast('team-chat:'||(r->>'chatChannelId')||':'||auth.uid()::text),'valid own subscribe';
 perform public.send_team_chat_message((r->>'teamId')::uuid,'Positive scoped member send');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 assert public.can_manage_team((select t from leakage_target)),'assigned Master operational scope still works';
 assert exists(select 1 from public.teams where id=(select t from leakage_target)),'assigned Master operational metadata';
 assert public.get_team_chat_access((select ch from leakage_target)) is null,'Master scope does not grant private Chat';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
 assert public.get_team_chat_access((select ch from leakage_target))='read','contextual Mentor own read';
 assert jsonb_array_length(public.list_team_chat_messages((select ch from leakage_target))->'items')>0,'contextual Mentor own history';
 begin perform public.send_team_chat_message((select t from leakage_target),'read-only Mentor');raise exception 'Mentor post';exception when insufficient_privilege then null;end;
end $$;
reset role;
\echo M5.16 authorized Team A/Team B/Master/Mentor controls PASS
set constraints all immediate;
rollback;
