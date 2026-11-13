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
select public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004004');
create temporary table event_baseline as select count(*) a,(select count(*) from public.notifications) n from public.audit_events;
select public.move_team_member('00000000-0000-4000-8000-000000004004',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R'),'PRIVATE REASON NOT STORED');
do $$ begin
 assert (select count(*) from public.audit_events)=(select a+1 from event_baseline),'one canonical move event';
 assert (select count(*) from public.notifications)=(select n+1 from event_baseline),'one move notification';
 assert exists(select 1 from public.audit_events where event_type='MEMBER_MOVED' and actor_user_id=auth.uid() and entity_id=(select (payload->>'teamId')::uuid from member_teams where label='R') and scope_id=entity_id and metadata->>'cohortId'=(select id::text from member_cohorts where label='A')),'trusted actor/entity/scope';
 assert not exists(select 1 from public.audit_events where metadata::text like '%PRIVATE%' or metadata::text like '%fixture%'),'no content/reason in metadata';
 assert exists(select 1 from public.audit_events where event_type='TEAM_CREATED');
 assert exists(select 1 from public.audit_events where event_type='MEMBER_ADDED');
 assert exists(select 1 from public.audit_events where event_type='MEMBER_REMOVED');
end $$;
select public.assign_team_lead((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004004');
create temporary table lead_baseline as select count(*) n from public.audit_events;
select public.assign_team_lead((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004004');
do $$ begin assert (select count(*) from public.audit_events)=(select n from lead_baseline),'consistent Lead retry no duplicate event';assert exists(select 1 from public.audit_events where event_type='TEAM_LEAD_CHANGED');end $$;
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='B'),'00000000-0000-4000-8000-000000004015','member');
-- Inject persistence failures: lifecycle state and all side effects roll back.
create function pg_temp.fail_event() returns trigger language plpgsql as $$begin raise exception 'injected persistence failure' using errcode='23514';end $$;
create temporary table before_failure as select (select count(*) from public.audit_events) a,(select count(*) from public.notifications) n,(select count(*) from public.team_memberships) m,(select count(*) from public.teams) t,(select count(*) from public.workspaces) w,(select count(*) from public.chat_channels) c;
create temporary table state_before_failure as select 'teams' kind,id,to_jsonb(t) data from public.teams t union all select 'membership',id,to_jsonb(m) from public.team_memberships m union all select 'chat',id,to_jsonb(c) from public.chat_memberships c;
create trigger test_fail_audit before insert on public.audit_events for each row execute function pg_temp.fail_event();
do $$ begin
 begin perform public.assign_team_lead((select (payload->>'teamId')::uuid from member_teams where label='B'),'00000000-0000-4000-8000-000000004015');raise exception 'unexpected success';exception when check_violation then null;end;
 begin perform public.create_team((select id from member_cohorts where label='A'),'Rollback audit Team');raise exception 'unexpected success';exception when check_violation then null;end;
 begin perform public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004007','member');raise exception 'unexpected success';exception when check_violation then null;end;
 begin perform public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004004');raise exception 'unexpected success';exception when check_violation then null;end;
end $$;
drop trigger test_fail_audit on public.audit_events;
create trigger test_fail_notification before insert on public.notifications for each row execute function pg_temp.fail_event();
do $$ begin
 begin perform public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004007','member');raise exception 'unexpected success';exception when check_violation then null;end;
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004007',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R'));raise exception 'unexpected success';exception when check_violation then null;end;
end $$;
drop trigger test_fail_notification on public.notifications;
do $$ begin
 assert not exists(select 1 from state_before_failure s where s.data is distinct from case s.kind when 'teams' then (select to_jsonb(t) from public.teams t where t.id=s.id) when 'membership' then (select to_jsonb(m) from public.team_memberships m where m.id=s.id) else (select to_jsonb(c) from public.chat_memberships c where c.id=s.id) end),'full state rollback';
 assert (select count(*) from public.audit_events)=(select a from before_failure);
 assert (select count(*) from public.notifications)=(select n from before_failure);
 assert (select count(*) from public.team_memberships)=(select m from before_failure);
 assert (select count(*) from public.teams)=(select t from before_failure);
 assert (select count(*) from public.workspaces)=(select w from before_failure);
 assert (select count(*) from public.chat_channels)=(select c from before_failure);
 assert exists(select 1 from public.team_memberships where team_id=(select (payload->>'teamId')::uuid from member_teams where label='R') and user_id='00000000-0000-4000-8000-000000004004' and status='active');
 assert (select team_lead_user_id from public.teams where id=(select (payload->>'teamId')::uuid from member_teams where label='R'))='00000000-0000-4000-8000-000000004004';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
do $$ declare code text; begin
 assert exists(select 1 from public.notifications),'recipient can read own durable notifications';
 assert not exists(select 1 from public.notifications where recipient_user_id<>auth.uid()),'other recipients hidden';
 foreach code in array array['TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED'] loop
 begin insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id) values(auth.uid(),code,'team',(select (payload->>'teamId')::uuid from member_teams where label='A'),'team',(select (payload->>'teamId')::uuid from member_teams where label='A'));raise exception 'forged audit';exception when insufficient_privilege then null;end;
 end loop;
 begin perform 1 from public.audit_events;raise exception 'audit leaked';exception when insufficient_privilege then null;end;
 begin update public.audit_events set actor_user_id=auth.uid();raise exception 'audit rewritten';exception when insufficient_privilege then null;end;
 begin delete from public.audit_events;raise exception 'audit deleted';exception when insufficient_privilege then null;end;
 begin insert into public.notifications(recipient_user_id,notification_type,entity_type,entity_id) values(auth.uid(),'MEMBER_ADDED','team',(select (payload->>'teamId')::uuid from member_teams where label='A'));raise exception 'forged notification';exception when insufficient_privilege then null;end;
 begin perform public.persist_m5_team_event('TEAM_CREATED',(select (payload->>'teamId')::uuid from member_teams where label='A'));raise exception 'private writer callable';exception when insufficient_privilege then null;end;
 begin perform public.m5_move_add_team_member_internal((select (payload->>'teamId')::uuid from member_teams where label='A'),auth.uid(),'member');raise exception 'non-auditing helper callable';exception when insufficient_privilege then null;end;
 begin perform public.m5_move_remove_team_member_internal((select (payload->>'teamId')::uuid from member_teams where label='A'),auth.uid(),null);raise exception 'non-auditing helper callable';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 begin update public.audit_events set metadata='{}';raise exception 'history mutable';exception when check_violation then null;end;
 begin delete from public.notifications;raise exception 'history deletable';exception when check_violation then null;end;
end $$;
rollback;
select 'M5.12 audit and notification persistence PASS';
