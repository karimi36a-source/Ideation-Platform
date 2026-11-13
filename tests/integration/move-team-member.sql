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
create temporary table move_snapshot_messages as select id,to_jsonb(m) original from public.chat_messages m;
create temporary table move_snapshot_personal as select id,to_jsonb(w) original from public.workspaces w where workspace_type='PERSONAL';
create temporary table move_results(label text,payload jsonb);grant select,insert on move_results to authenticated;
-- Give Student A1 only source membership for the move; preserve its prior R row.
update public.team_memberships set status='removed',left_at=clock_timestamp(),removed_by='00000000-0000-4000-8000-000000004001' where team_id=(select (payload->>'teamId')::uuid from member_teams where label='R') and user_id='00000000-0000-4000-8000-000000004004';
update public.chat_memberships set left_at=clock_timestamp() where chat_channel_id=(select (payload->>'chatChannelId')::uuid from member_teams where label='R') and user_id='00000000-0000-4000-8000-000000004004' and left_at is null;
-- A Team-only Master authorized on A cannot use the move to acquire R scope.
insert into public.role_assignments(user_id,role_id,team_id,assigned_by) select '00000000-0000-4000-8000-000000004016','00000000-0000-4000-8000-000000000102',(payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000004001' from member_teams where label='A';
set local role authenticated;
do $$ declare n integer; begin
 foreach n in array array[4003,4004,4005,4006,4016] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  begin perform public.move_team_member('00000000-0000-4000-8000-000000004004',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R'));raise exception 'unauthorized/one-Team move';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
insert into move_results values('member',public.move_team_member('00000000-0000-4000-8000-000000004004',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
insert into move_results values('lead',public.move_team_member('00000000-0000-4000-8000-000000004005',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R')));
insert into move_results values('mentor',public.move_team_member('00000000-0000-4000-8000-000000004006',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R')));
do $$ begin
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004007',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='A'));raise exception 'same Team move';exception when invalid_parameter_value then null;end;
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004007',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='B'));raise exception 'cross-Cohort move';exception when invalid_parameter_value then null;end;
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004004',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R'));raise exception 'removed source reused';exception when invalid_parameter_value then null;end;
end $$;
reset role;
do $$ declare r record; begin
 for r in select * from move_results loop
  assert r.payload->>'sourceMembershipId'<>r.payload->>'targetMembershipId','target uses NEW row';
  assert exists(select 1 from public.team_memberships where id=(r.payload->>'sourceMembershipId')::uuid and status='removed' and left_at>=joined_at and removed_by=case when r.label='member' then '00000000-0000-4000-8000-000000004002'::uuid else '00000000-0000-4000-8000-000000004001'::uuid end),'source history preserved';
  assert exists(select 1 from public.team_memberships where id=(r.payload->>'targetMembershipId')::uuid and status='active' and left_at is null and membership_role=case when r.label='mentor' then 'mentor'::public.team_membership_role else 'member'::public.team_membership_role end),'target role safe';
 end loop;
 assert not exists(select 1 from move_snapshot_messages s left join public.chat_messages m using(id) where m.id is null or to_jsonb(m)<>s.original),'source messages and attribution unchanged';
 assert (select count(*) from public.chat_messages)=(select count(*) from move_snapshot_messages),'no private Chat copies';
 assert not exists(select 1 from move_snapshot_personal s left join public.workspaces w using(id) where w.id is null or to_jsonb(w)<>s.original),'Personal rows untouched';
 assert not exists(select 1 from public.teams where id in (select (payload->>'teamId')::uuid from member_teams where label in ('A','R')) and team_lead_user_id is not null),'source Lead cleared and target Lead not appointed';
end $$;
set local role authenticated;
do $$ declare n integer; sw uuid; dw uuid; sc uuid; dc uuid; begin
 select (payload->>'workspaceId')::uuid,(payload->>'chatChannelId')::uuid into sw,sc from member_teams where label='A';
 select (payload->>'workspaceId')::uuid,(payload->>'chatChannelId')::uuid into dw,dc from member_teams where label='R';
 foreach n in array array[4004,4005,4006] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  assert not exists(select 1 from public.workspaces where id=sw),'source direct-ID Workspace denied';
  assert public.get_team_workspace_access(sw) is null and public.get_team_chat_access(sc) is null,'source Workspace and Chat read/post revoked';
  assert not exists(select 1 from public.chat_messages where chat_channel_id=sc),'source private messages denied';
  assert exists(select 1 from public.workspaces where id=dw),'target Workspace visible';
  assert public.get_team_workspace_access(dw)=case when n=4006 then 'mentor' else 'member' end,'target Workspace capability role';
  assert public.get_team_chat_access(dc)=case when n=4006 then 'read' else 'read_write' end,'target Chat role';
  assert exists(select 1 from public.chat_channels where id=dc),'target Chat channel visible';
  assert not exists(select 1 from public.chat_messages where chat_channel_id=dc and content='Private member fixture'),'source private content not migrated';
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004007',true);
 assert exists(select 1 from public.chat_messages where chat_channel_id=sc and content='Private member fixture'),'current source members still see historical messages';
end $$;
reset role;
-- Stale source Chat record still cannot override the removed source relationship.
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at) select (payload->>'chatChannelId')::uuid,'00000000-0000-4000-8000-000000004004','read_write',clock_timestamp() from member_teams where label='A';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
do $$ begin assert not public.can_access_team_chat((select (payload->>'chatChannelId')::uuid from member_teams where label='A')),'stale source Chat cannot bypass removal';end $$;
-- Duplicate target: both existing relationships must remain unchanged.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004007','member');
do $$ begin
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004007',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R'));raise exception 'duplicate target move';exception when unique_violation then null;end;
end $$;
reset role;
-- Eligibility errors after source revocation roll back the source changes.
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000004019';
update public.enrollments set status='withdrawn' where user_id='00000000-0000-4000-8000-000000004020';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
do $$ declare n integer; begin
 foreach n in array array[4019,4020] loop
  begin perform public.move_team_member(('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R'));raise exception 'ineligible move';exception when invalid_parameter_value then null;end;
 end loop;
end $$;
reset role;
-- Move a current Lead to test every source and target failure stage.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004017','team_lead');
reset role;
create temporary table move_before_members as select id,to_jsonb(m) original from public.team_memberships m;
create temporary table move_before_chat as select id,to_jsonb(cm) original from public.chat_memberships cm;
create function pg_temp.fail_member_move() returns trigger language plpgsql as $$ begin
 if current_setting('fici_test.move_failure',true)='target_chat_update' and tg_table_name='chat_memberships' and tg_op='UPDATE' then
  if new.chat_channel_id=(select (payload->>'chatChannelId')::uuid from member_teams where label='R') then raise exception 'Injected move failure';end if;
 end if;
 if current_setting('fici_test.move_failure',true)=tg_table_name||':'||tg_op then raise exception 'Injected move failure';end if;return new;
end $$;
create trigger fail_move_member before insert or update on public.team_memberships for each row execute function pg_temp.fail_member_move();
create trigger fail_move_chat before insert or update on public.chat_memberships for each row execute function pg_temp.fail_member_move();
create trigger fail_move_lead before update on public.teams for each row execute function pg_temp.fail_member_move();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
do $$ declare failure text; begin
 foreach failure in array array['team_memberships:UPDATE','chat_memberships:UPDATE','teams:UPDATE','team_memberships:INSERT','chat_memberships:INSERT'] loop
  perform set_config('fici_test.move_failure',failure,true);
  begin perform public.move_team_member('00000000-0000-4000-8000-000000004017',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R'));raise exception 'failure not injected';exception when raise_exception then if sqlerrm<>'Injected move failure' then raise;end if;end;
 end loop;
 perform set_config('fici_test.move_failure','',true);
end $$;
reset role;
-- Reusing an existing open target Chat row is also an atomic activation step.
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at)
 select (payload->>'chatChannelId')::uuid,'00000000-0000-4000-8000-000000004017','read',clock_timestamp() from member_teams where label='R';
insert into move_before_chat select id,to_jsonb(cm) from public.chat_memberships cm where chat_channel_id=(select (payload->>'chatChannelId')::uuid from member_teams where label='R') and user_id='00000000-0000-4000-8000-000000004017';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
do $$ begin
 perform set_config('fici_test.move_failure','target_chat_update',true);
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004017',(select (payload->>'teamId')::uuid from member_teams where label='A'),(select (payload->>'teamId')::uuid from member_teams where label='R'));raise exception 'activation failure not injected';exception when raise_exception then if sqlerrm<>'Injected move failure' then raise;end if;end;
 perform set_config('fici_test.move_failure','',true);
end $$;
reset role;
do $$ begin
 assert (select count(*) from public.team_memberships)=(select count(*) from move_before_members),'no target member orphan';
 assert not exists(select 1 from move_before_members s left join public.team_memberships m using(id) where m.id is null or to_jsonb(m)<>s.original),'source membership exactly restored';
 assert (select count(*) from public.chat_memberships)=(select count(*) from move_before_chat),'no target Chat orphan';
 assert not exists(select 1 from move_before_chat s left join public.chat_memberships cm using(id) where cm.id is null or to_jsonb(cm)<>s.original),'source Chat exactly restored';
 assert (select team_lead_user_id from public.teams where id=(select (payload->>'teamId')::uuid from member_teams where label='A'))='00000000-0000-4000-8000-000000004017','source Lead restored';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004017',true);
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from member_teams where label='A'))='team_lead','source access remains';
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from member_teams where label='R')) is null,'no target partial access';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.move_team_member(uuid,uuid,uuid,text)'::regprocedure),'safe definer';
 assert not has_function_privilege('anon','public.move_team_member(uuid,uuid,uuid,text)','EXECUTE') and not has_function_privilege('service_role','public.move_team_member(uuid,uuid,uuid,text)','EXECUTE'),'no anonymous/service bypass';
end $$;
set local role anon;
do $$ begin
 begin perform public.move_team_member('00000000-0000-4000-8000-000000004004','00000000-0000-4000-8000-000000009998','00000000-0000-4000-8000-000000009999');raise exception 'anonymous move';exception when insufficient_privilege then null;end;
end $$;
reset role;
set constraints all immediate;
rollback;
\echo AT-TEAM-005 M5.7 PASS - atomic move, source revocation, target access, role safety, history and no content transfer
