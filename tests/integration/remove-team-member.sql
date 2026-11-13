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
-- Denials while contextual Lead and Mentor still have active membership.
set local role authenticated;
do $$ declare n integer; begin
 foreach n in array array[4003,4004,4005,4006] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  begin perform public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004007');raise exception 'unauthorized removal';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
insert into removal_results values('Master',public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004004','Test removal'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004001',true);
insert into removal_results values('Lead',public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004005'));
do $$ begin
 begin perform public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004004');raise exception 'removed membership accepted';exception when invalid_parameter_value then null;end;
 begin perform public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004016');raise exception 'missing membership accepted';exception when invalid_parameter_value then null;end;
 begin perform public.remove_team_member('00000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000004004');raise exception 'missing Team leaked';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ declare r record; begin
 for r in select * from removal_results loop
  assert exists(select 1 from public.team_memberships m join remove_join_snapshot s using(id)
   where m.id=(r.payload->>'membershipId')::uuid and m.status='removed' and m.left_at>=m.joined_at
   and m.removed_by=case when r.label='Master' then '00000000-0000-4000-8000-000000004002'::uuid else '00000000-0000-4000-8000-000000004001'::uuid end
   and m.joined_at=s.joined_at and m.added_by=s.added_by and m.created_at=s.created_at),'membership history preserved with verified remover';
 end loop;
 assert not exists(select 1 from public.chat_memberships cm join public.chat_channels ch on ch.id=cm.chat_channel_id where ch.team_id=(select (payload->>'teamId')::uuid from member_teams where label='A') and cm.user_id in ('00000000-0000-4000-8000-000000004004','00000000-0000-4000-8000-000000004005') and cm.left_at is null),'corresponding Chat access closed';
 assert (select team_lead_user_id from public.teams where id=(select (payload->>'teamId')::uuid from member_teams where label='A')) is null,'Lead cleared without replacement';
 assert not exists(select 1 from remove_personal_snapshot s left join public.workspaces w using(id) where w.id is null or to_jsonb(w)<>s.original),'Personal rows unchanged';
 assert not exists(select 1 from remove_message_snapshot s left join public.chat_messages m using(id) where m.id is null or to_jsonb(m)<>s.original),'messages, sender, timestamps and attribution unchanged';
 assert exists(select 1 from public.team_memberships where team_id=(select (payload->>'teamId')::uuid from member_teams where label='R') and user_id='00000000-0000-4000-8000-000000004004' and status='active'),'unrelated membership untouched';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
do $$ declare w uuid; ch uuid; begin
 select (payload->>'workspaceId')::uuid,(payload->>'chatChannelId')::uuid into w,ch from member_teams where label='A';
 assert not exists(select 1 from public.workspaces where id=w),'removed direct-ID Workspace SELECT denied';
 assert public.get_team_workspace_access(w) is null,'Workspace resolver denies';
 assert not exists(select 1 from public.chat_channels where id=ch),'Chat read denied';
 assert not exists(select 1 from public.chat_messages where chat_channel_id=ch),'authored messages do not override removal';
 assert public.get_team_chat_access(ch) is null,'Chat read/post capabilities denied';
 assert exists(select 1 from public.workspaces where workspace_type='PERSONAL' and owner_user_id=auth.uid()),'own Personal Workspace retained';
 assert not exists(select 1 from public.workspaces where workspace_type='PERSONAL' and owner_user_id<>auth.uid()),'other Personal privacy retained';
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(ch,auth.uid(),'Removed-user attack');raise exception 'removed member posts';exception when insufficient_privilege then null;end;
 begin update public.chat_memberships set left_at=null;raise exception 'Chat reopening bypass';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004007',true);
do $$ begin
 assert exists(select 1 from public.chat_messages where chat_channel_id=(select (payload->>'chatChannelId')::uuid from member_teams where label='A') and sender_user_id='00000000-0000-4000-8000-000000004004' and content='Private member fixture'),'current users still read preserved messages';
end $$;
reset role;
-- A stale open Chat record cannot override the removed Team membership.
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at)
 select (payload->>'chatChannelId')::uuid,'00000000-0000-4000-8000-000000004004','read_write',clock_timestamp() from member_teams where label='A';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004004',true);
do $$ begin assert not public.can_access_team_chat((select (payload->>'chatChannelId')::uuid from member_teams where label='A')),'stale Chat record does not bypass removal';end $$;
reset role;
do $$ declare lifecycle public.team_status; begin
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
 foreach lifecycle in array array['completed','archived']::public.team_status[] loop
  update public.teams set status=lifecycle where id=(select (payload->>'teamId')::uuid from member_teams where label='A');
  begin perform public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004007');raise exception 'ineligible Team accepts removal';exception when invalid_parameter_value then null;end;
 end loop;
 update public.teams set status='created' where id=(select (payload->>'teamId')::uuid from member_teams where label='A');
 update public.users set account_status='archived' where id='00000000-0000-4000-8000-000000004019';
 perform public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004019');
 update public.enrollments set status='withdrawn' where user_id='00000000-0000-4000-8000-000000004020';
 perform public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='A'),'00000000-0000-4000-8000-000000004020');
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
insert into member_teams values('LegacyLead',public.create_team((select id from member_cohorts where label='A'),'Legacy Lead Team',null,'00000000-0000-4000-8000-000000004018'));
select public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='LegacyLead'),'00000000-0000-4000-8000-000000004018');
reset role;
do $$ begin
 assert (select team_lead_user_id from public.teams where id=(select (payload->>'teamId')::uuid from member_teams where label='LegacyLead')) is null,'Legacy Lead cleared';
 assert not exists(select 1 from public.chat_memberships where chat_channel_id=(select (payload->>'chatChannelId')::uuid from member_teams where label='LegacyLead')),'no missing Chat grant invented';
end $$;
-- Set up an active Lead for rollback tests using the real add operation.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004017','team_lead');
reset role;
create temporary table remove_rollback_members as select id,to_jsonb(m) original from public.team_memberships m;
create temporary table remove_rollback_chat as select id,to_jsonb(cm) original from public.chat_memberships cm;
create function pg_temp.fail_member_remove() returns trigger language plpgsql as $$ begin
 if current_setting('fici_test.remove_failure',true)=tg_table_name then raise exception 'Injected removal failure';end if;return new;
end $$;
create trigger fail_remove_membership before update on public.team_memberships for each row execute function pg_temp.fail_member_remove();
create trigger fail_remove_chat before update on public.chat_memberships for each row execute function pg_temp.fail_member_remove();
create trigger fail_remove_lead before update on public.teams for each row execute function pg_temp.fail_member_remove();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004002',true);
do $$ declare failure text; begin
 foreach failure in array array['team_memberships','chat_memberships','teams'] loop
  perform set_config('fici_test.remove_failure',failure,true);
  begin perform public.remove_team_member((select (payload->>'teamId')::uuid from member_teams where label='R'),'00000000-0000-4000-8000-000000004017');raise exception 'failure not injected';exception when raise_exception then if sqlerrm<>'Injected removal failure' then raise;end if;end;
 end loop;
 perform set_config('fici_test.remove_failure','',true);
end $$;
reset role;
do $$ begin
 assert not exists(select 1 from remove_rollback_members s left join public.team_memberships m using(id) where m.id is null or to_jsonb(m)<>s.original),'membership removal rolls back';
 assert not exists(select 1 from remove_rollback_chat s left join public.chat_memberships cm using(id) where cm.id is null or to_jsonb(cm)<>s.original),'Chat revocation rolls back';
 assert (select team_lead_user_id from public.teams where id=(select (payload->>'teamId')::uuid from member_teams where label='R'))='00000000-0000-4000-8000-000000004017','Lead clearing rolls back';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000004017',true);
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from member_teams where label='R'))='team_lead','Workspace access unchanged on failure';
 assert public.get_team_chat_access((select (payload->>'chatChannelId')::uuid from member_teams where label='R'))='read_write','Chat access unchanged on failure';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.remove_team_member(uuid,uuid,text)'::regprocedure),'safe narrow definer';
 assert not has_function_privilege('anon','public.remove_team_member(uuid,uuid,text)','EXECUTE') and not has_function_privilege('service_role','public.remove_team_member(uuid,uuid,text)','EXECUTE'),'no anonymous/generic service bypass';
end $$;
set local role anon;
do $$ begin
 begin perform public.remove_team_member('00000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000004004');raise exception 'anonymous removal';exception when insufficient_privilege then null;end;
end $$;
reset role;
set constraints all immediate;
rollback;
\echo AT-TEAM-003 / AT-TEAM-004 M5.6 PASS - revoked access, preserved history/Personal isolation, Lead clearing and atomic rollback
