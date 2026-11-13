\set ON_ERROR_STOP on
begin;
do $$ declare t text; f record; n integer:=0; begin
 foreach t in array array['teams','team_memberships','workspaces','chat_channels','chat_memberships','chat_messages','audit_events','notifications'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass), 'M5 sensitive RLS disabled';
  assert not has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'), 'anonymous grant';
  assert not has_table_privilege('authenticated','public.'||t,'INSERT,UPDATE,DELETE,TRUNCATE'), 'direct client mutation grant';
  assert not has_table_privilege('service_role','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'), 'broad service grant';
  assert not exists(select 1 from pg_policies where schemaname='public' and tablename=t and permissive='PERMISSIVE' and (qual='true' or with_check='true')), 'broad policy';
 end loop;
 for f in select p.* from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname='public' and p.proname in
 ('create_team','add_team_member','remove_team_member','move_team_member','assign_team_lead','archive_team','send_team_chat_message','list_team_chat_messages','can_manage_team','get_team_workspace_access','get_team_chat_access','can_access_team_chat','team_workspace_has_chat_access','can_receive_team_chat_broadcast','broadcast_team_chat_message','team_chat_broadcast_recipient','persist_m5_team_event','m5_move_add_team_member_internal','m5_move_remove_team_member_internal','preserve_m5_event_history') loop
  n:=n+1;
  assert f.proconfig=array['search_path=""'], 'unsafe function search_path';
  assert f.proowner not in (select oid from pg_roles where rolname in ('anon','authenticated','service_role')), 'untrusted function owner';
  assert not has_function_privilege('anon',f.oid,'EXECUTE'), 'anonymous function execution';
  if f.proname in ('broadcast_team_chat_message','team_chat_broadcast_recipient','persist_m5_team_event','m5_move_add_team_member_internal','m5_move_remove_team_member_internal','preserve_m5_event_history') then
   assert not has_function_privilege('authenticated',f.oid,'EXECUTE'), 'private function browser exposure';
   assert not has_function_privilege('service_role',f.oid,'EXECUTE'), 'private function service exposure';
  else
   assert has_function_privilege('authenticated',f.oid,'EXECUTE'), 'approved narrow RPC unavailable';
  end if;
 end loop;
 assert n=20, 'missing security inventory function';
 assert not has_table_privilege('authenticated','public.audit_events','SELECT'), 'audit exposed';
 assert has_table_privilege('authenticated','public.notifications','SELECT'), 'recipient notification read unavailable';
 assert not has_function_privilege('authenticated','realtime.send(jsonb,text,text,boolean)','EXECUTE'), 'client publisher';
 assert to_regclass('public.projects') is null and to_regclass('public.project_baselines') is null, 'premature later M6 schema';
end $$;
rollback;
\echo M5.18 final grant/function/security inventory PASS
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
-- An enrolled learner with even an open Chat membership has no Team access.
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at)
 select (payload->>'chatChannelId')::uuid,'00000000-0000-4000-8000-000000004016','read_write',now() from member_teams where label='A';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004016',true);
do $$ declare v jsonb; begin
 select payload into v from member_teams where label='A';
 assert public.get_team_workspace_access((v->>'workspaceId')::uuid) is null,'enrollment alone Workspace bypass';
 assert public.get_team_chat_access((v->>'chatChannelId')::uuid) is null,'open Chat membership alone bypass';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||(v->>'chatChannelId')||':00000000-0000-4000-8000-000000004016'),'enrollment realtime bypass';
 assert not exists(select 1 from public.teams where id=(v->>'teamId')::uuid),'enrollment Team metadata leak';
 assert not exists(select 1 from public.workspaces where id=(v->>'workspaceId')::uuid),'enrollment Workspace leak';
 assert not exists(select 1 from public.chat_channels where id=(v->>'chatChannelId')::uuid),'enrollment channel leak';
 assert not exists(select 1 from public.chat_memberships where chat_channel_id=(v->>'chatChannelId')::uuid),'stale membership leak';
 begin
  perform public.send_team_chat_message((v->>'teamId')::uuid,'must not persist');
  raise exception 'enrolled nonmember sent message';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
\echo M5.18 enrollment is not Team membership PASS
