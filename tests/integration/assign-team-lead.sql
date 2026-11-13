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
-- Snapshot exact Personal and authored message rows before removal.
create temporary table remove_personal_snapshot as select id,to_jsonb(w) original from public.workspaces w where workspace_type='PERSONAL' and owner_user_id in ('00000000-0000-4000-8000-000000004004','00000000-0000-4000-8000-000000004007');
create temporary table remove_message_snapshot as select id,to_jsonb(m) original from public.chat_messages m where chat_channel_id=(select (payload->>'chatChannelId')::uuid from member_teams where label='A');
create temporary table remove_join_snapshot as select id,joined_at,added_by,created_at from public.team_memberships where team_id=(select (payload->>'teamId')::uuid from member_teams where label='A');
create temporary table removal_results(label text,payload jsonb);grant select,insert on removal_results to authenticated;
-- Remove the initial Lead through the approved path; preserve that history.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004005');
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004019','member');
reset role;
create temporary table lead_members_before as select id,to_jsonb(m)-'membership_role' history from public.team_memberships m;
create temporary table lead_chat_before as select id,to_jsonb(cm) original from public.chat_memberships cm;
create temporary table lead_roles_before as select id,to_jsonb(a) original from public.role_assignments a;
create temporary table lead_results(payload jsonb);grant select,insert on lead_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
insert into lead_results values(public.assign_team_lead((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004004'));
insert into lead_results values(public.assign_team_lead((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004004'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
insert into lead_results values(public.assign_team_lead((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004019'));
reset role;
do $$ declare n int;begin
 assert (select count(distinct payload) from lead_results)=2,'retry returns same membership';
 assert (select count(*) from public.team_memberships)=(select count(*) from lead_members_before),'no new membership';
 assert not exists(select 1 from lead_members_before s join public.team_memberships m using(id) where to_jsonb(m)-'membership_role'<>s.history),'join/lifecycle/history unchanged';
 assert not exists(select 1 from lead_chat_before s join public.chat_memberships cm using(id) where to_jsonb(cm)<>s.original),'correct Chat untouched';
 assert not exists(select 1 from lead_roles_before s join public.role_assignments a using(id) where to_jsonb(a)<>s.original),'platform role unchanged';
 assert not exists(select 1 from remove_personal_snapshot s join public.workspaces w using(id) where to_jsonb(w)<>s.original),'Personal unchanged';
 assert not exists(select 1 from remove_message_snapshot s join public.chat_messages m using(id) where to_jsonb(m)<>s.original),'messages unchanged';
 assert exists(select 1 from public.teams t join public.team_memberships m on m.team_id=t.id and m.user_id=t.team_lead_user_id where t.id=(select (payload->>'teamId')::uuid from member_teams where label='A') and m.status='active' and m.membership_role='team_lead'),'Lead reference synchronized';
end $$;
-- Real authenticated actor denial, including contextual Lead with active access.
set local role authenticated;
do $$ declare actor text; a uuid; r uuid;begin
 select (payload->>'teamId')::uuid into a from member_teams where label='A';
 select (payload->>'teamId')::uuid into r from member_teams where label='R';
 foreach actor in array array['4003','4004','4006','4007'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor,12,'0'),true);
  begin perform public.assign_team_lead(a,'00000000-0000-4000-8000-000000004007');raise exception 'unauthorized assignment';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from member_teams where label='A'))='team_lead','approved Lead access';
 assert public.get_team_chat_access((select (payload->>'chatChannelId')::uuid from member_teams where label='A'))='read_write','approved Lead Chat';
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from member_teams where label='B')) is null,'other Team denied';
 assert (select count(*) from public.workspaces where owner_user_id='00000000-0000-4000-8000-000000004007' and workspace_type='PERSONAL')=0,'private teammate Personal denied';
 begin perform public.add_team_member(a,'00000000-0000-4000-8000-000000004014','member');raise exception 'Lead adds';exception when insufficient_privilege then null;end;
 begin perform public.remove_team_member(a,'00000000-0000-4000-8000-000000004007');raise exception 'Lead removes';exception when insufficient_privilege then null;end;
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004007',a,r);raise exception 'Lead moves';exception when insufficient_privilege then null;end;
 begin update public.teams set master_user_id='00000000-0000-4000-8000-000000004004' where id=a;raise exception 'Lead changes Master';exception when insufficient_privilege then null;end;
 begin insert into public.role_assignments(user_id,role_id,assigned_by) values('00000000-0000-4000-8000-000000004004','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000004004');raise exception 'Lead escalates';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
 begin perform public.assign_team_lead(a,'00000000-0000-4000-8000-000000004007');raise exception 'replacement';exception when unique_violation then null;end;
 -- Removed/nonmember/inactive profile denied even before conflicting Lead check.
 foreach actor in array array['4005','4008','4014','4021'] loop
  begin perform public.assign_team_lead(a,('00000000-0000-4000-8000-'||lpad(actor,12,'0'))::uuid);raise exception 'invalid member';exception when invalid_parameter_value then null;end;
 end loop;
end $$;
reset role;
-- Fresh Team for atomic failure injection and contextual Mentor promotion.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
insert into member_teams values('F',public.create_team((select id from member_cohorts where label='A'),'Lead failure Team'));
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='F'),'00000000-0000-4000-8000-000000004006','mentor');
reset role;
create temporary table lead_failure_team as select id,to_jsonb(t) original from public.teams t where id=(select (payload->>'teamId')::uuid from member_teams where label='F');
create temporary table lead_failure_member as select id,to_jsonb(m) original from public.team_memberships m where team_id=(select id from lead_failure_team);
create temporary table lead_failure_chat as select id,to_jsonb(cm) original from public.chat_memberships cm where chat_channel_id=(select (payload->>'chatChannelId')::uuid from member_teams where label='F');
create function public.fici_lead_failure() returns trigger language plpgsql as $$ begin
 if current_setting('fici_test.lead_failure',true)=tg_table_name then raise exception 'Injected Lead failure';end if;return new;
end $$;
create trigger fici_lead_fail_team before update on public.teams for each row execute function public.fici_lead_failure();
create trigger fici_lead_fail_member before update on public.team_memberships for each row execute function public.fici_lead_failure();
create trigger fici_lead_fail_chat before update on public.chat_memberships for each row execute function public.fici_lead_failure();
set local role authenticated;
do $$ declare step text;begin
 foreach step in array array['teams','team_memberships','chat_memberships'] loop
  perform set_config('fici_test.lead_failure',step,true);
  begin perform public.assign_team_lead((select (payload->>'teamId')::uuid from member_teams where label='F'),'00000000-0000-4000-8000-000000004006');raise exception 'missing injection';exception when raise_exception then if sqlerrm<>'Injected Lead failure' then raise;end if;end;
 end loop;
 perform set_config('fici_test.lead_failure','',true);
end $$;
reset role;
do $$ begin
 assert not exists(select 1 from lead_failure_team s join public.teams t using(id) where to_jsonb(t)<>s.original),'Team rollback';
 assert not exists(select 1 from lead_failure_member s join public.team_memberships m using(id) where to_jsonb(m)<>s.original),'membership rollback';
 assert not exists(select 1 from lead_failure_chat s join public.chat_memberships cm using(id) where to_jsonb(cm)<>s.original),'Chat rollback';
end $$;
set local role authenticated;
select public.assign_team_lead((select (payload->>'teamId')::uuid from member_teams where label='F'),'00000000-0000-4000-8000-000000004006');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004006',true);
do $$ begin
 assert public.get_team_chat_access((select (payload->>'chatChannelId')::uuid from member_teams where label='F'))='read_write','existing mentor Chat synchronized to Lead';
 assert not public.can_manage_team((select (payload->>'teamId')::uuid from member_teams where label='F')),'contextual promotion no management';
end $$;
reset role;
do $$ begin
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.assign_team_lead(uuid,uuid)'::regprocedure),'fixed safe definer';
 assert not has_function_privilege('anon','public.assign_team_lead(uuid,uuid)','EXECUTE') and not has_function_privilege('service_role','public.assign_team_lead(uuid,uuid)','EXECUTE'),'no elevated caller shortcut';
 assert to_regclass('public.audit_events') is not null,'audit foundation exists';
end $$;
set local role anon;
do $$ begin
 begin perform public.assign_team_lead('00000000-0000-4000-8000-000000009998','00000000-0000-4000-8000-000000004004');raise exception 'anonymous';exception when insufficient_privilege then null;end;
end $$;
reset role;
set constraints all immediate;
rollback;
\echo M5.8 Team Lead assignment PASS - scope, consistency, idempotency, conflict, history, rollback and no escalation
