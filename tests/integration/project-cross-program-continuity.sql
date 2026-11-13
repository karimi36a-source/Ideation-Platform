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
insert into public.workspaces(id,workspace_type,name,owner_user_id,cohort_id,created_by,updated_by)
 values('00000000-0000-4000-8000-000000007101','CASE_STUDY','Case Study fixture','00000000-0000-4000-8000-000000006002',(select id from acceptance_cohorts where label='Test'),'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006001');
grant select on acceptance_personal to authenticated;
create temporary table created_projects(label text,payload jsonb);grant select,insert on created_projects to authenticated;
create temporary table creation_history_counts as select (select count(*) from public.audit_events) audits,(select count(*) from public.notifications) notifications;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into created_projects values('Individual',public.create_development_project('My Project','individual',(select id from acceptance_personal where data->>'owner_user_id'='00000000-0000-4000-8000-000000006004')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into created_projects values('Team Master',public.create_development_project('Team Project','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
insert into created_projects values('Case Study',public.create_development_project('Case Project','instructor_case_study','00000000-0000-4000-8000-000000007101',null,'00000000-0000-4000-8000-000000006002'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into created_projects values('Team Admin',public.create_development_project('Admin Team Project','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
reset role;
do $$declare x record;begin
 for x in select * from created_projects loop
  assert exists(select 1 from public.development_projects p where p.id=(x.payload->>'id')::uuid and to_jsonb(p)=x.payload),'canonical persisted Project response';
 end loop;
 assert not exists(select 1 from public.project_memberships),'no automatic participant rows for any Project type';
 assert (select count(*) from public.audit_events)=(select audits from creation_history_counts),'no misuse of Team audit';
 assert (select count(*) from public.notifications)=(select notifications from creation_history_counts),'no notifications invented';
 assert (select count(*) from public.development_projects)=4,'only four creations';
end $$;
-- Isolated Advanced Course fixture; no production seed or curriculum content changes.
insert into public.organizations(id,name,slug) values('00000000-0000-4000-8000-000000000604','Other','program-other');
insert into public.programs(id,organization_id,name,code,program_type) values('00000000-0000-4000-8000-000000000605','00000000-0000-4000-8000-000000000604','Advanced Course test fixture','ADVANCED_TEST','advanced_course');
insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000000606','00000000-0000-4000-8000-000000000605','Advanced test approved','approved');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000604','00000000-0000-4000-8000-000000006001');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into acceptance_cohorts values('Other',(public.create_cohort('00000000-0000-4000-8000-000000000605','00000000-0000-4000-8000-000000000606','Advanced Course test cohort','2026-10-01',null,'00000000-0000-4000-8000-000000006002','planned','{}')->>'id')::uuid);
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006004','participant','active' from acceptance_cohorts where label='Other';
-- Operational Master/Admin authority does not grant Project content access.
-- Explicitly establish both independent memberships for authorized Team actors.
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'participant','active' from acceptance_cohorts cross join generate_series(6001,6002) n where label='Test';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006002','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006001','member');
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from created_projects cross join generate_series(6001,6002) n where label='Team Master';
-- Expired participant history never grants Team Project authority.
insert into public.project_memberships(project_id,user_id,starts_at,ends_at)
 select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006004',now()-interval '2 days',now()-interval '1 day' from created_projects where label='Team Master';
create temporary table continuity_objects(label text,payload jsonb);grant select,insert on continuity_objects to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into continuity_objects select 'Individual',public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM','AT-PROJ-003 Problem','Persistent cross-program Object',null) from created_projects where label='Individual';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into continuity_objects select 'Team',public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM','AT-PROJ-003 Team Problem','Team isolation fixture',null) from created_projects where label='Team Master';
reset role;
create temporary table continuity_projects as select id,to_jsonb(p) data from public.development_projects p;
create temporary table continuity_workspaces as select id,to_jsonb(w) data from public.workspaces w;
create temporary table continuity_members as select id,to_jsonb(m) data from public.project_memberships m;
create temporary table participation_results(label text,payload jsonb);grant select,insert on participation_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into participation_results values('Individual Test',public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Individual'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into participation_results values('Team Test',public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Team Master'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test')));
insert into participation_results values('Case Test',public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Case Study'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test')));
reset role;
-- Trusted history fixture only; M6.4 adds no completion API.
update public.project_program_links set completed_at=clock_timestamp() where id=(select (payload->>'id')::uuid from participation_results where label='Individual Test');
create temporary table prior_participation_history as select id,to_jsonb(l) data from public.project_program_links l;
-- Fail the actual second-program INSERT before allowing the successful transition.
create function public.fixture_fail_advanced_link() returns trigger language plpgsql as $$begin raise exception 'Forced Advanced link failure' using errcode='23514';end $$;
create trigger fixture_advanced_failure after insert on public.project_program_links for each row execute function public.fixture_fail_advanced_link();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Individual'),'00000000-0000-4000-8000-000000000605',(select id from acceptance_cohorts where label='Other'));raise exception 'Advanced failure did not roll back';exception when check_violation then null;end;
end $$;
reset role;
do $$begin
 assert (select count(*) from public.project_program_links)=(select count(*) from prior_participation_history),'failed Advanced link leaves no partial row';
 assert not exists(select 1 from prior_participation_history b left join public.project_program_links l using(id) where l.id is null or b.data<>to_jsonb(l)),'failed Advanced link preserves first link';
 assert not exists(select 1 from continuity_projects b left join public.development_projects p using(id) where p.id is null or b.data<>to_jsonb(p)),'failed Advanced link preserves Project';
 assert not exists(select 1 from continuity_objects b left join public.development_objects o on o.id=(b.payload->>'id')::uuid where o.id is null or b.payload<>to_jsonb(o)),'failed Advanced link preserves Objects';
 assert not exists(select 1 from continuity_members b left join public.project_memberships m using(id) where m.id is null or b.data<>to_jsonb(m)),'failed Advanced link preserves membership history';
end $$;
drop trigger fixture_advanced_failure on public.project_program_links;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into participation_results values('Individual Other',public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Individual'),'00000000-0000-4000-8000-000000000605',(select id from acceptance_cohorts where label='Other'),null));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into participation_results values('Team Other',public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Team Master'),'00000000-0000-4000-8000-000000000605',(select id from acceptance_cohorts where label='Other')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into participation_results values('Case Other',public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Case Study'),'00000000-0000-4000-8000-000000000605',(select id from acceptance_cohorts where label='Other')));
do $$begin
 begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Team Master'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));raise exception 'active duplicate';exception when unique_violation then null;end;
 begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Case Study'),'00000000-0000-4000-8000-000000000605',(select id from acceptance_cohorts where label='Test'));raise exception 'invalid Program/Cohort pair';exception when invalid_parameter_value then null;end;
 begin perform public.link_project_to_program('00000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));raise exception 'nonexistent Project';exception when insufficient_privilege then null;end;
 begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Case Study'),'00000000-0000-4000-8000-000000009999',(select id from acceptance_cohorts where label='Test'));raise exception 'nonexistent Program';exception when invalid_parameter_value then null;end;
 begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Case Study'),'00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000009999');raise exception 'nonexistent Cohort';exception when insufficient_privilege then null;end;
 begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Case Study'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'),'00000000-0000-4000-8000-000000009999');raise exception 'unverified Artifact version';exception when feature_not_supported then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Individual'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));raise exception 'unapproved completed-context re-entry';exception when unique_violation then null;end;
 assert (select count(*) from public.project_program_links)=2,'owner sees only own authorized participation';
end $$;
reset role;
do $$begin
 assert not exists(select 1 from continuity_projects b join public.development_projects p using(id) where b.data<>to_jsonb(p)),'same Project ID/owner/Workspace/metadata';
 assert (select count(*) from public.development_projects)=(select count(*) from continuity_projects),'no duplicate Projects';
 assert not exists(select 1 from continuity_workspaces b join public.workspaces w using(id) where b.data<>to_jsonb(w)),'Workspace identity unchanged';
 assert (select count(*) from public.project_memberships)=(select count(*) from continuity_members),'membership count unchanged';
 assert not exists(select 1 from continuity_members b join public.project_memberships m using(id) where b.data<>to_jsonb(m)),'Project Membership history unchanged';
 assert not exists(select 1 from prior_participation_history b join public.project_program_links l using(id) where b.data<>to_jsonb(l)),'prior participation history unchanged';
 assert (select count(*) from public.project_program_links)=6,'three types linked to two contexts';
 assert not exists(select 1 from continuity_objects b left join public.development_objects o on o.id=(b.payload->>'id')::uuid where o.id is null or to_jsonb(o)<>b.payload),'canonical Objects unchanged after both Program links';
 assert (select count(*) from public.development_projects where name='My Project')=1,'one canonical Project A';
 assert (select count(*) from public.development_objects where project_id=(select (payload->>'id')::uuid from created_projects where label='Individual'))=1,'one canonical Object in Project A';
 assert (select count(*) from public.change_log where project_id=(select (payload->>'id')::uuid from created_projects where label='Individual') and change_type='PROJECT_CREATED')=1,'one Project creation event';
 assert (select count(*) from public.change_log where project_id=(select (payload->>'id')::uuid from created_projects where label='Individual') and change_type='OBJECT_CREATED')=1,'one Object creation event';
 assert (select count(*) from public.change_log where project_id=(select (payload->>'id')::uuid from created_projects where label='Individual'))=2,'linking creates no fake history events';

 assert not exists(select 1 from public.project_program_links where entry_artifact_version_id is not null or exit_artifact_version_id is not null),'null Artifact fields accepted';
end $$;
set local role authenticated;
do $$declare who text;pid uuid;begin
 select (payload->>'id')::uuid into pid from created_projects where label='Individual';
 foreach who in array array['6003','6005','6006','6007','6008'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  assert (select count(*) from public.project_program_links)=0,'unrelated actor participation denied';
  begin perform public.link_project_to_program(pid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));raise exception 'link another owner Project';exception when insufficient_privilege then null;end;
  begin insert into public.project_program_links(project_id,program_id,cohort_id) values(pid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));raise exception 'direct insert';exception when insufficient_privilege then null;end;
  begin update public.project_program_links set completed_at=null,entry_artifact_version_id=auth.uid();raise exception 'direct lifecycle/Artifact edit';exception when insufficient_privilege then null;end;
  begin delete from public.project_program_links;raise exception 'direct delete';exception when insufficient_privilege then null;end;
 end loop;
end $$;
do $$declare who text;p uuid;begin
 select (payload->>'id')::uuid into p from created_projects where label='Team Master';
 foreach who in array array['6003','6004','6006','6007'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  assert not exists(select 1 from public.development_projects where id=p),'unrelated/stale participant Project denied';
  assert not exists(select 1 from public.development_objects where project_id=p),'unrelated/stale participant Objects denied';
  assert not exists(select 1 from public.project_program_links where project_id=p),'unrelated/stale participant links denied';
  begin perform public.link_project_to_program(p,'00000000-0000-4000-8000-000000000605',(select id from acceptance_cohorts where label='Other'));raise exception 'Team transition bypass';exception when insufficient_privilege then null;end;
 end loop;
end $$;
-- Current Team access must still be required after removal, despite Project Membership.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006002');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert not exists(select 1 from public.project_program_links where project_id=(select (payload->>'id')::uuid from created_projects where label='Team Master')),'removed Team participant link read denied';
 begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Team Master'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));raise exception 'removed transition bypass';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Composite FK and historical protections apply even at the trusted DB boundary.
do $$begin
 begin insert into public.project_program_links(project_id,program_id,cohort_id) values((select (payload->>'id')::uuid from created_projects where label='Individual'),'00000000-0000-4000-8000-000000000605',(select id from acceptance_cohorts where label='Test'));raise exception 'cross-program FK';exception when foreign_key_violation then null;end;
 begin update public.project_program_links set entered_at=entered_at+interval '1 day';raise exception 'history rewrite';exception when check_violation then null;end;
 begin delete from public.project_program_links;raise exception 'history delete';exception when check_violation then null;end;
 assert to_regclass('public.project_baselines') is null and to_regclass('public.project_baselines') is null,'no M8/M6.5 resources';
 assert not exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey) where c.conrelid='public.project_program_links'::regclass and c.contype='f' and a.attname in ('entry_artifact_version_id','exit_artifact_version_id')),'Artifact FKs deferred';
 assert (select proconfig=array['search_path=""'] from pg_proc where oid='public.link_project_to_program(uuid,uuid,uuid,uuid)'::regprocedure),'fixed definer search_path';
end $$;
-- Completion keeps permitted history readable but is not active linking eligibility.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.transition_enrollment((select id from public.enrollments where user_id='00000000-0000-4000-8000-000000006004' and cohort_id=(select id from acceptance_cohorts where label='Test') and status='active'),'completed');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert exists(select 1 from public.project_program_links where id=(select (payload->>'id')::uuid from participation_results where label='Individual Test')),'completed enrollment retains authorized participation history';end $$;
reset role;
-- A valid, new target context is used to force failure after the link INSERT.
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006004','participant','active' from acceptance_cohorts where label='Unrelated';
create function public.fixture_fail_participation_insert() returns trigger language plpgsql as $$begin raise exception 'Forced link failure' using errcode='23514';end $$;
create trigger fixture_participation_failure after insert on public.project_program_links for each row execute function public.fixture_fail_participation_insert();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Individual'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Unrelated'));raise exception 'failed insert did not roll back';exception when check_violation then null;end;end $$;
reset role;
do $$begin assert (select count(*) from public.project_program_links)=6,'no partial participation row';assert not exists(select 1 from continuity_projects b join public.development_projects p using(id) where b.data<>to_jsonb(p)),'failure preserves Project identity';end $$;
do $$begin
 assert not exists(select 1 from continuity_objects b left join public.development_objects o on o.id=(b.payload->>'id')::uuid where o.id is null or to_jsonb(o)<>b.payload),'failed link preserves Objects';
 assert not exists(select 1 from prior_participation_history b left join public.project_program_links l using(id) where l.id is null or b.data<>to_jsonb(l)),'failed link preserves first history';
 assert not exists(select 1 from public.project_program_links where project_id=(select (payload->>'id')::uuid from created_projects where label='Individual') and cohort_id=(select id from acceptance_cohorts where label='Unrelated')),'no partial second link';
end $$;
-- Report real canonical identities before separately exercising archive denial.
select 'M6_15_CONTINUITY='||jsonb_build_object(
 'beforeProjectId',p.payload->>'id','afterProjectId',x.id,
 'beforeObjectId',o.payload->>'id','afterObjectId',y.id,
 'professionalLinkId',a.payload->>'id','advancedLinkId',b.payload->>'id',
 'projectCount',(select count(*) from public.development_projects where name='My Project'),
 'objectCount',(select count(*) from public.development_objects where project_id=x.id),
 'projectCreatedCount',(select count(*) from public.change_log where project_id=x.id and change_type='PROJECT_CREATED'),
 'objectCreatedCount',(select count(*) from public.change_log where project_id=x.id and change_type='OBJECT_CREATED'))::text
 from created_projects p join public.development_projects x on x.id=(p.payload->>'id')::uuid
 join continuity_objects o on o.label='Individual' join public.development_objects y on y.id=(o.payload->>'id')::uuid
 join participation_results a on a.label='Individual Test' join participation_results b on b.label='Individual Other'
 where p.label='Individual';
drop trigger fixture_participation_failure on public.project_program_links;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.archive_development_project((select (payload->>'id')::uuid from created_projects where label='Individual'));
do $$begin
 begin perform public.link_project_to_program((select (payload->>'id')::uuid from created_projects where label='Individual'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Unrelated'));raise exception 'archived transition bypass';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin
 assert (select count(*) from public.project_program_links)=6,'archive denial creates no partial link';
 assert not exists(select 1 from continuity_objects b left join public.development_objects o on o.id=(b.payload->>'id')::uuid where o.id is null or to_jsonb(o)<>b.payload),'archive preserves Objects';
 assert not exists(select 1 from prior_participation_history b left join public.project_program_links l using(id) where l.id is null or b.data<>to_jsonb(l)),'archive preserves first link';
 assert not exists(select 1 from public.activity_instances) and to_regclass('public.project_baselines') is null,'no later entities';
end $$;
rollback;
\echo M6.15 AT-PROJ-003 PostgreSQL cross-program/Object/history/count/security/rollback/archive PASS
