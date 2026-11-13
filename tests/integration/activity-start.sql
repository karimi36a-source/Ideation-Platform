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
insert into public.development_projects(id,name,project_type,owner_user_id,primary_workspace_id)
 values('00000000-0000-4000-8000-000000007201','Individual fixture','individual','00000000-0000-4000-8000-000000006004',(select id from public.workspaces where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000006004')),
 ('00000000-0000-4000-8000-000000007203','Case Study fixture','instructor_case_study','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000007101');
insert into public.development_projects(id,name,project_type,owner_team_id,primary_workspace_id)
 select '00000000-0000-4000-8000-000000007202','Team fixture','team',(payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid from acceptance_teams where label='A';
insert into public.project_memberships(project_id,user_id) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006004'),('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006005');

create temporary table logged_projects(label text primary key,payload jsonb);grant select,insert on logged_projects to authenticated;
create temporary table logged_objects(label text primary key,payload jsonb);grant select,insert on logged_objects to authenticated;
create temporary table logged_edges(label text primary key,payload jsonb);grant select,insert on logged_edges to authenticated;
create temporary table membership_baseline as select count(*) n from public.project_memberships;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into logged_projects values('Individual',public.create_development_project('Logged Individual','individual',(select id from public.workspaces where workspace_type='PERSONAL')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('Team',public.create_development_project('Logged Team','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
-- Admin creation needs no automatic Project Membership to produce trusted history.
reset role;
do $$begin
 assert (select count(*) from public.project_memberships)=(select n from membership_baseline),'no membership merely for logging';
 assert exists(select 1 from public.change_log where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') and changed_by='00000000-0000-4000-8000-000000006001' and change_type='PROJECT_CREATED'),'Admin Project creation verified actor';
end $$;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006004' from logged_projects where label='Team';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into logged_projects values('Case',public.create_development_project('Logged Case','instructor_case_study','00000000-0000-4000-8000-000000007101',null,'00000000-0000-4000-8000-000000006002'));
insert into logged_objects values('Case',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Case'),'00000000-0000-4000-8000-000000007101','PROBLEM','Case','Content',null));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into logged_objects values('Problem',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select id from public.workspaces where workspace_type='PERSONAL'),'PROBLEM','Problem','Private content never copied','User','{"private":"blob"}')),
 ('Solution',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select id from public.workspaces where workspace_type='PERSONAL'),'SOLUTION','Solution','Content','User')),
 ('Team',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),'PROBLEM','Problem','Content','User'));

-- Canonical Team and Individual typed data for exact-ID attacks; no later entities.
select public.write_problem_details((select (payload->>'id')::uuid from logged_objects where label='Problem'),'{}',true);
insert into logged_objects values('Individual Idea',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select id from public.workspaces where workspace_type='PERSONAL'),'IDEA','Private Idea','Private Idea content','User'));
select public.write_idea_details((select (payload->>'id')::uuid from logged_objects where label='Individual Idea'),'{"acceptance_state":"private"}',true);
insert into logged_objects values('Team Idea',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),'IDEA','Team Idea','Private Team content','User'));
select public.write_problem_details((select (payload->>'id')::uuid from logged_objects where label='Team'),'{}',true);
select public.write_idea_details((select (payload->>'id')::uuid from logged_objects where label='Team Idea'),'{"acceptance_state":"private","original_private_workspace_id":null}',true);
insert into logged_edges values('Individual',public.relate_development_objects((select (payload->>'id')::uuid from logged_objects where label='Solution'),(select (payload->>'id')::uuid from logged_objects where label='Problem'),'SOLVES')),
 ('Team',public.relate_development_objects((select (payload->>'id')::uuid from logged_objects where label='Team Idea'),(select (payload->>'id')::uuid from logged_objects where label='Team'),'DERIVED_FROM'));
select public.link_project_to_program((select (payload->>'id')::uuid from logged_projects where label='Individual'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.link_project_to_program((select (payload->>'id')::uuid from logged_projects where label='Case'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));
reset role;
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test') from logged_projects where label='Team';


-- Isolated curriculum fixtures; production 2026 v1 and its seed remain unchanged.
insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000740602','00000000-0000-4000-8000-000000000601','M7.4 isolated fixture','draft');
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence,status) values('00000000-0000-4000-8000-000000740702','00000000-0000-4000-8000-000000740602',1,'Availability test','Test only','Security test only',1,'active');
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,status)
select ('00000000-0000-4000-8000-'||lpad((740800+n)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000740702','Isolated availability '||n,'custom',
case when n=2 then 'Instructor Workspace' when n=6 then 'Personal Workspace' when n=7 then null else 'Team Workspace' end,n,case when n=5 then 'inactive'::public.activity_status else 'active'::public.activity_status end from generate_series(1,7) n;
insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory)
values('00000000-0000-4000-8000-000000740803','00000000-0000-4000-8000-000000740801','approved_output',true),
('00000000-0000-4000-8000-000000740804','00000000-0000-4000-8000-000000740801','artifact_available',false);

insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,status)
select ('00000000-0000-4000-8000-'||lpad((750800+n)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000740702','Dependency test '||n,'custom','Team Workspace',10+n,'active' from generate_series(1,8)n;
insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory) values
('00000000-0000-4000-8000-000000750801','00000000-0000-4000-8000-000000740801','completion',true),
('00000000-0000-4000-8000-000000750802','00000000-0000-4000-8000-000000740801','completion',false),
('00000000-0000-4000-8000-000000750803','00000000-0000-4000-8000-000000740801','completion',true),
('00000000-0000-4000-8000-000000750803','00000000-0000-4000-8000-000000750804','completion',true),
('00000000-0000-4000-8000-000000750805','00000000-0000-4000-8000-000000740801','artifact_available',true),
('00000000-0000-4000-8000-000000750806','00000000-0000-4000-8000-000000740801','gate_passed',true),
('00000000-0000-4000-8000-000000750807','00000000-0000-4000-8000-000000740801','gate_passed',false);
do $$begin
 begin
 insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory)
 values('00000000-0000-4000-8000-000000750808','00000000-0000-4000-8000-000000740801','unsupported',true);
 raise exception 'unknown dependency accepted';exception when invalid_text_representation then null;end;
end $$;

update public.curriculum_versions set status='approved' where id='00000000-0000-4000-8000-000000740602';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into acceptance_cohorts values('Availability',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000740602','Isolated availability Cohort','2026-10-01',null,'00000000-0000-4000-8000-000000006002','active','{}')->>'id')::uuid);
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
select c.id,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'participant','active' from acceptance_cohorts c cross join (values(6002),(6004),(6005),(6008)) v(n) where c.label='Availability';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into acceptance_teams values('Availability',public.create_team((select id from acceptance_cohorts where label='Availability'),'Isolated Team',null,'00000000-0000-4000-8000-000000006005'));
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='Availability'),'00000000-0000-4000-8000-000000006004','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='Availability'),'00000000-0000-4000-8000-000000006002','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='Availability'),'00000000-0000-4000-8000-000000006008','mentor');
reset role;
update public.teams set status='active' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='Availability');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('Availability',public.create_development_project('Isolated availability Project','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='Availability'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='Availability')));
reset role;
insert into public.project_memberships(project_id,user_id) select (p.payload->>'id')::uuid,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from logged_projects p cross join (values(6002),(6004),(6005),(6008)) v(n) where p.label='Availability';
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Availability') from logged_projects where label='Availability';
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Availability') from logged_projects where label='Individual';
create temporary table av_context(label text primary key,definition uuid,project uuid,workspace uuid,team uuid);
insert into av_context select 'Personal','00000000-0000-4000-8000-000000000801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,null from logged_projects where label='Individual';
insert into av_context select 'Team','00000000-0000-4000-8000-000000740801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,(payload->>'owner_team_id')::uuid from logged_projects where label='Availability';
insert into av_context select 'Case','00000000-0000-4000-8000-000000000801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,null from logged_projects where label='Case';
grant select on av_context to authenticated,anon;
-- Fingerprint every public table before/after every resolver call, including audit/notification tables.
create function pg_temp.public_fingerprint() returns jsonb language plpgsql security definer set search_path='' as $$declare t text;payload jsonb:='{}';digest text;begin
 for t in select tablename from pg_catalog.pg_tables where schemaname='public' order by tablename loop
 execute format('select md5(coalesce(string_agg(to_jsonb(x)::text,'''' order by to_jsonb(x)::text),'''')) from public.%I x',t) into digest;
 payload:=payload||jsonb_build_object(t,digest);end loop;return payload;end $$;
create function pg_temp.av(label0 text,patch jsonb,expected jsonb) returns jsonb language plpgsql as $$declare ctx jsonb;result jsonb;before jsonb;begin
 select to_jsonb(x) into ctx from av_context x where label=label0;ctx:=ctx||patch;
 before:=pg_temp.public_fingerprint();
 result:=public.resolve_activity_availability((ctx->>'definition')::uuid,(ctx->>'project')::uuid,(ctx->>'workspace')::uuid,(ctx->>'team')::uuid);
 assert result=expected,'Availability expected '||expected::text||', got '||result::text;
 assert before=pg_temp.public_fingerprint(),'resolver must perform zero public writes';return result;end $$;


-- M7.6 TEST CASES
create temporary table start_snapshots as select id,public.activity_start_snapshot(id) data from public.activity_definitions;
grant select on start_snapshots to authenticated;
create function pg_temp.start_call(label0 text,patch jsonb,expected_reason text default null) returns jsonb language plpgsql as $$
declare ctx jsonb;result jsonb;before jsonb;row0 jsonb;begin
 select to_jsonb(x) into ctx from av_context x where label=label0;ctx:=ctx||patch;
 before:=pg_temp.public_fingerprint();
 result:=public.start_activity((ctx->>'definition')::uuid,(ctx->>'project')::uuid,(ctx->>'workspace')::uuid,(ctx->>'team')::uuid);
 if expected_reason is not null then
  assert result->>'started'='false' and result->>'reasonCode'=expected_reason,'safe failure '||result::text;
  assert before=pg_temp.public_fingerprint(),'failed start performs zero public writes';
 else
  assert result->>'started'='true','start succeeded';row0:=result->'activity';
  assert row0->>'status'='active' and row0->>'started_by'=auth.uid()::text and row0->>'started_at' is not null and row0->>'completed_at' is null;
  assert row0->>'activity_definition_id'=ctx->>'definition' and row0->>'project_id'=ctx->>'project' and row0->>'workspace_id'=ctx->>'workspace' and row0->>'team_id' is not distinct from ctx->>'team';
  assert exists(select 1 from public.activity_instances i where i.id=(row0->>'id')::uuid and to_jsonb(i)=row0),'canonical returned DB instance';
  assert (select count(*) from public.activity_participants where activity_instance_id=(row0->>'id')::uuid)=1,'exactly one initiating participant';
  assert exists(select 1 from public.activity_participants where activity_instance_id=(row0->>'id')::uuid and user_id=auth.uid() and participant_role='participant' and joined_at=(row0->>'started_at')::timestamptz and completed_at is null);
  assert row0->'configuration_snapshot'=(select data from start_snapshots where id=(ctx->>'definition')::uuid),'exact 8-field canonical snapshot';
  assert (before-'activity_instances'-'activity_participants')=(pg_temp.public_fingerprint()-'activity_instances'-'activity_participants'),'only instance and participant created';
 end if;return result;
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
savepoint personal;
select pg_temp.start_call('Personal','{}');
select pg_temp.start_call('Personal','{}','ACTIVE_INSTANCE_EXISTS');
reset role;
do $$declare original jsonb;begin
 select configuration_snapshot into original from public.activity_instances where project_id=(select project from av_context where label='Personal');
 begin update public.activity_definitions set instructions='changed' where id='00000000-0000-4000-8000-000000000801';raise exception 'approved definition rewrite';exception when check_violation then null;end;
 begin update public.activity_instances set configuration_snapshot='{}';raise exception 'snapshot overwrite';exception when check_violation then null;end;
 assert original=(select configuration_snapshot from public.activity_instances where project_id=(select project from av_context where label='Personal')),'snapshot history preserved';
end $$;
rollback to personal;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
savepoint lead;select pg_temp.start_call('Team','{}');reset role;rollback to lead;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
savepoint master;select pg_temp.start_call('Team','{}');reset role;rollback to master;
-- Ordinary member, Mentor, unrelated Master, Team B, Admin-only and other Personal owner deny.
set local role authenticated;
do $$declare actor0 uuid;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006008','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006001']::uuid[] loop
 perform set_config('request.jwt.claim.sub',actor0::text,true);perform pg_temp.start_call('Team','{}','INVALID_CONTEXT');end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 perform pg_temp.start_call('Personal','{}','INVALID_CONTEXT');
 perform set_config('request.jwt.claim.sub','',true);perform pg_temp.start_call('Team','{}','UNAUTHENTICATED');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.start_call('Team','{"definition":"00000000-0000-4000-8000-000000750801"}','DEPENDENCY_NOT_MET');
select pg_temp.start_call('Team','{"definition":"00000000-0000-4000-8000-000000740803"}','DEPENDENCY_NOT_MET');
select pg_temp.start_call('Team','{"definition":"00000000-0000-4000-8000-000000750805"}','DEPENDENCY_NOT_MET');
select pg_temp.start_call('Team','{"definition":"00000000-0000-4000-8000-000000750806"}','DEPENDENCY_NOT_MET');
select pg_temp.start_call('Team','{"definition":"00000000-0000-4000-8000-000000740807"}','WORKSPACE_MODE_MISMATCH');
select pg_temp.start_call('Team','{"definition":"00000000-0000-4000-8000-000000740805"}','ACTIVITY_NOT_AVAILABLE');
reset role;savepoint completed_dependency;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'completed','00000000-0000-4000-8000-000000006005',now(),now() from av_context where label='Team';
set local role authenticated;select pg_temp.start_call('Team','{"definition":"00000000-0000-4000-8000-000000750801"}');reset role;rollback to completed_dependency;

savepoint duplicate_fixture;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'not_started',null,null,null from av_context where label='Team';
set local role authenticated;select pg_temp.start_call('Team','{}','ACTIVE_INSTANCE_EXISTS');reset role;rollback to duplicate_fixture;

savepoint duplicate_fixture;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'active','00000000-0000-4000-8000-000000006005'::uuid,now(),null from av_context where label='Team';
set local role authenticated;select pg_temp.start_call('Team','{}','ACTIVE_INSTANCE_EXISTS');reset role;rollback to duplicate_fixture;

savepoint duplicate_fixture;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'submitted','00000000-0000-4000-8000-000000006005'::uuid,now(),null from av_context where label='Team';
set local role authenticated;select pg_temp.start_call('Team','{}','ACTIVE_INSTANCE_EXISTS');reset role;rollback to duplicate_fixture;

savepoint duplicate_fixture;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'under_review','00000000-0000-4000-8000-000000006005'::uuid,now(),null from av_context where label='Team';
set local role authenticated;select pg_temp.start_call('Team','{}','ACTIVE_INSTANCE_EXISTS');reset role;rollback to duplicate_fixture;

savepoint duplicate_fixture;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'revision_requested','00000000-0000-4000-8000-000000006005'::uuid,now(),null from av_context where label='Team';
set local role authenticated;select pg_temp.start_call('Team','{}','ACTIVE_INSTANCE_EXISTS');reset role;rollback to duplicate_fixture;

savepoint duplicate_fixture;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'completed','00000000-0000-4000-8000-000000006005'::uuid,now(),now() from av_context where label='Team';
set local role authenticated;select pg_temp.start_call('Team','{}',null);reset role;rollback to duplicate_fixture;

savepoint duplicate_fixture;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'archived','00000000-0000-4000-8000-000000006005'::uuid,now(),now() from av_context where label='Team';
set local role authenticated;select pg_temp.start_call('Team','{}',null);reset role;rollback to duplicate_fixture;

-- Forced failures are fixture-only triggers/private function replacements. Each
-- failed call is caught in a subtransaction and every public table is compared.
create function pg_temp.forced_failure() returns trigger language plpgsql as $$begin raise exception 'fixture failure' using errcode='23514';end $$;
create function pg_temp.assert_rollback() returns void language plpgsql as $$declare ctx av_context;before jsonb;begin
 select * into ctx from av_context where label='Team';before:=pg_temp.public_fingerprint();
 begin perform public.start_activity(ctx.definition,ctx.project,ctx.workspace,ctx.team);raise exception 'failure not forced';exception when check_violation or invalid_parameter_value then null;end;
 assert before=pg_temp.public_fingerprint(),'full transaction rollback including history/audit';
end $$;
savepoint failed_participant;
create trigger m76_fail_participant before insert on public.activity_participants for each row execute function pg_temp.forced_failure();
select pg_temp.assert_rollback();rollback to failed_participant;
savepoint failed_instance;
create trigger m76_fail_instance before insert on public.activity_instances for each row execute function pg_temp.forced_failure();
select pg_temp.assert_rollback();rollback to failed_instance;
savepoint failed_after_participant;
create trigger m76_fail_after_participant after insert on public.activity_participants for each row execute function pg_temp.forced_failure();
select pg_temp.assert_rollback();rollback to failed_after_participant;
savepoint failed_snapshot;
create or replace function public.activity_start_snapshot(target_definition uuid) returns jsonb language plpgsql stable set search_path='' as $$begin return null;end $$;
select pg_temp.assert_rollback();rollback to failed_snapshot;
set local role authenticated;
do $$begin
 begin insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,status,started_by,started_at) select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,'active','00000000-0000-4000-8000-000000006002',now() from av_context where label='Team';raise exception 'direct insert bypass';exception when insufficient_privilege then null;end;
 begin insert into public.activity_participants(activity_instance_id,user_id,joined_at) values(gen_random_uuid(),'00000000-0000-4000-8000-000000006002',now());raise exception 'participant spoof';exception when insufficient_privilege then null;end;
 begin perform public.activity_start_snapshot('00000000-0000-4000-8000-000000740801');raise exception 'private snapshot exposed';exception when insufficient_privilege then null;end;
end $$;
-- A participation row remains history, not an authorization grant after removal.
select pg_temp.start_call('Team','{}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006005');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.start_call('Team','{}','INVALID_CONTEXT');
do $$begin assert not exists(select 1 from public.activity_instances);assert not exists(select 1 from public.activity_participants),'participant history never extends access';end $$;
reset role;
do $$begin
 assert (select count(*) from public.activity_instances)=1 and (select count(*) from public.activity_participants)=1,'historical initiator retained';
 assert not has_function_privilege('anon','public.start_activity(uuid,uuid,uuid,uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.start_activity(uuid,uuid,uuid,uuid)','EXECUTE');
 assert not has_table_privilege('authenticated','public.activity_instances','INSERT,UPDATE,DELETE');
 assert not has_table_privilege('authenticated','public.activity_participants','INSERT,UPDATE,DELETE');
 assert (select prosecdef and provolatile='v' and proconfig=array['search_path=""'] from pg_proc where oid='public.start_activity(uuid,uuid,uuid,uuid)'::regprocedure);
end $$;
rollback;
\echo M7.6 start/actor/snapshot/initiator/dependencies/duplicates/rollback/privacy PASS
