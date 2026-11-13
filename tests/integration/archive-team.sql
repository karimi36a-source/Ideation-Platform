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

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
insert into member_teams values('T',public.create_team((select id from member_cohorts where label='A'),'Active move source'));
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='T'),'00000000-0000-4000-8000-000000004007','member');
create temporary table preserved_records as
 select 'workspace' kind,id,to_jsonb(w) data from public.workspaces w
 union all select 'membership',id,to_jsonb(m) from public.team_memberships m
 union all select 'channel',id,to_jsonb(c) from public.chat_channels c
 union all select 'chat_membership',id,to_jsonb(c) from public.chat_memberships c
 union all select 'message',id,to_jsonb(m) from public.chat_messages m
 union all select 'audit',id,to_jsonb(a) from public.audit_events a
 union all select 'notification',id,to_jsonb(n) from public.notifications n;
create temporary table archive_results(label text,payload jsonb);grant select,insert on archive_results to authenticated;
set local role authenticated;
do $$ declare n integer;begin
 foreach n in array array[4003,4004,4005,4006] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.archive_team((select (payload->>'teamId')::uuid from member_teams where label='A'));raise exception 'unauthorized archive';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','',true);
 begin perform public.archive_team((select (payload->>'teamId')::uuid from member_teams where label='A'));raise exception 'anonymous archive';exception when invalid_authorization_specification then null;end;
end $$;
reset role;
-- Audit failure must roll back both lifecycle state and timestamp.
create temporary table team_before_failure as select id,to_jsonb(t) data from public.teams t;
create function pg_temp.fail_archive_audit() returns trigger language plpgsql as $$begin if new.event_type='TEAM_ARCHIVED' then raise exception 'injected failure' using errcode='23514';end if;return new;end $$;
create trigger fail_archive_audit before insert on public.audit_events for each row execute function pg_temp.fail_archive_audit();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
do $$ begin begin perform public.archive_team((select (payload->>'teamId')::uuid from member_teams where label='A'));raise exception 'audit failure ignored';exception when check_violation then null;end;
 assert not exists(select 1 from public.teams t join team_before_failure b using(id) where to_jsonb(t)<>b.data),'full archive rollback';
 assert not exists(select 1 from public.audit_events where event_type='TEAM_ARCHIVED'),'no failed event';end $$;
drop trigger fail_archive_audit on public.audit_events;
set local role authenticated;
insert into archive_results values('Master',public.archive_team((select (payload->>'teamId')::uuid from member_teams where label='A')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
insert into archive_results values('Admin',public.archive_team((select (payload->>'teamId')::uuid from member_teams where label='R')));
insert into archive_results values('retry',public.archive_team((select (payload->>'teamId')::uuid from member_teams where label='A')));
-- Archived Teams block all ordinary membership/Lead changes and both move directions.
do $$ declare a uuid; r uuid;begin
 a:=(select (payload->>'teamId')::uuid from member_teams where label='A');r:=(select (payload->>'teamId')::uuid from member_teams where label='R');
 begin perform public.add_team_member(a,'00000000-0000-4000-8000-000000004016','member');raise exception 'archived add';exception when invalid_parameter_value then null;end;
 begin perform public.remove_team_member(a,'00000000-0000-4000-8000-000000004004');raise exception 'archived remove';exception when invalid_parameter_value then null;end;
 begin perform public.assign_team_lead(a,'00000000-0000-4000-8000-000000004004');raise exception 'archived Lead';exception when invalid_parameter_value then null;end;
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004007',(select (payload->>'teamId')::uuid from member_teams where label='T'),a);raise exception 'move into archive';exception when invalid_parameter_value then null;end;
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004007',a,(select (payload->>'teamId')::uuid from member_teams where label='T'));raise exception 'move out of archive';exception when invalid_parameter_value then null;end;
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004007',a,r);raise exception 'archived move';exception when invalid_parameter_value then null;end;
 begin update public.teams set status='active' where id=a;raise exception 'direct restore';exception when insufficient_privilege then null;end;
 begin update public.teams set name='changed' where id=a;raise exception 'metadata mutation';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
do $$ declare t uuid;w uuid;ch uuid;begin
 select (payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid,(payload->>'chatChannelId')::uuid into t,w,ch from member_teams where label='A';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||ch::text||':'||auth.uid()::text),'stale realtime topic cannot authorize';
 assert public.get_team_workspace_access(w) is null and public.get_team_chat_access(ch) is null,'known IDs cannot authorize archived access';
 assert not exists(select 1 from public.workspaces where id=w),'archived Workspace RLS denied';
 assert not exists(select 1 from public.chat_channels where id=ch),'archived Channel RLS denied';
 assert not exists(select 1 from public.chat_messages where chat_channel_id=ch),'archived history ordinary read denied';
 begin perform public.send_team_chat_message(t,'archived message');raise exception 'archived send';exception when insufficient_privilege then null;end;
 begin perform public.list_team_chat_messages(ch);raise exception 'archived history RPC';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ declare x record;actual jsonb;begin
 for x in select * from preserved_records loop
 case x.kind
 when 'workspace' then select to_jsonb(t) into actual from public.workspaces t where id=x.id;
 when 'membership' then select to_jsonb(t) into actual from public.team_memberships t where id=x.id;
 when 'channel' then select to_jsonb(t) into actual from public.chat_channels t where id=x.id;
 when 'chat_membership' then select to_jsonb(t) into actual from public.chat_memberships t where id=x.id;
 when 'message' then select to_jsonb(t) into actual from public.chat_messages t where id=x.id;
 when 'audit' then select to_jsonb(t) into actual from public.audit_events t where id=x.id;
 when 'notification' then select to_jsonb(t) into actual from public.notifications t where id=x.id;
 end case;
 assert actual is not distinct from x.data,'collaboration/Personal/history record unchanged';
 end loop;
 assert (select count(*) from public.audit_events where event_type='TEAM_ARCHIVED')=2,'exactly one event per archive';
 assert (select payload->>'archivedAt' from archive_results where label='Master')=(select payload->>'archivedAt' from archive_results where label='retry'),'retry preserves timestamp';
 assert (select count(*) from public.notifications)=(select count(*) from preserved_records where kind='notification'),'no extra notifications';
 assert not exists(select 1 from public.notifications where notification_type='TEAM_ARCHIVED'),'no invented notifications';
 assert exists(select 1 from public.teams where id=(select (payload->>'teamId')::uuid from member_teams where label='A') and status='archived' and archived_at is not null and team_lead_user_id='00000000-0000-4000-8000-000000004005'),'Lead/reference/history preserved';
 assert exists(select 1 from public.audit_events where event_type='TEAM_ARCHIVED' and actor_user_id='00000000-0000-4000-8000-000000004002' and metadata->>'cohortId'=(select id::text from member_cohorts where label='A')),'verified actor and scope audit';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.archive_team(uuid)'::regprocedure),'safe fixed definer path';
 assert not has_function_privilege('anon','public.archive_team(uuid)','EXECUTE') and not has_function_privilege('service_role','public.archive_team(uuid)','EXECUTE'),'no anonymous/service bypass';
 assert not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('restore_team','unarchive_team')),'no restore';
end $$;
set constraints all immediate;
rollback;
select 'M5.13 Team archive security and history PASS';
