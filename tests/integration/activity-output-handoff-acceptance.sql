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

update public.activity_definitions set instructions='Original execution instructions',ai_role_code='fixture_ai_role' where session_definition_id='00000000-0000-4000-8000-000000740702';
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



-- M7.7 PERSISTENT FIXTURES
update av_context set definition='00000000-0000-4000-8000-000000740806' where label='Personal';
create temporary table resumed_fixture(label text primary key,id uuid,payload jsonb);
grant select,insert,update on resumed_fixture to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into resumed_fixture select 'Personal',(v->'activity'->>'id')::uuid,null from av_context x cross join lateral (select public.start_activity(x.definition,x.project,x.workspace,x.team) v) f where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into resumed_fixture select 'Team',(v->'activity'->>'id')::uuid,null from av_context x cross join lateral (select public.start_activity(x.definition,x.project,x.workspace,x.team) v) f where label='Team';
reset role;
insert into public.activity_inputs(id,activity_instance_id,input_type,development_object_id,required) select '00000000-0000-4000-8000-000000770901',f.id,'development_object',(o.payload->>'id')::uuid,true from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
insert into public.activity_outputs(id,activity_instance_id,output_type,development_object_id) select '00000000-0000-4000-8000-000000770902',f.id,'development_object',(o.payload->>'id')::uuid from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';


-- M7.8 PERSISTENT FIXTURES
-- Remove only trusted test setup's input so registration is exercised from empty.
delete from public.activity_inputs;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into logged_objects select 'Activity Team',public.create_development_object(project,workspace,'PROBLEM','Team source','Private canonical content','User') from av_context where label='Team';
reset role;
-- Team B source is an isolated trusted canonical schema fixture.
insert into public.development_projects(id,name,project_type,owner_team_id,primary_workspace_id)
select '00000000-0000-4000-8000-000000780801','Team B source','team',(payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid from acceptance_teams where label='B';
insert into public.development_objects(id,project_id,workspace_id,object_type,title,created_by)
select '00000000-0000-4000-8000-000000780802','00000000-0000-4000-8000-000000780801',(payload->>'workspaceId')::uuid,'PROBLEM','Private Team B','00000000-0000-4000-8000-000000006006' from acceptance_teams where label='B';

-- M7.9 PERSISTENT FIXTURES
-- Only trusted fixture setup is cleared; production history is untouched.
delete from public.activity_outputs;

-- AT-ACT-004 generic foundation: actual started A and canonical RPC-created O1.
create temporary table handoff_context as
select f.id a,c.project,c.workspace,c.team,(o.payload->>'id')::uuid object_id
from resumed_fixture f join av_context c on c.label=f.label cross join logged_objects o
where f.label='Team' and o.label='Activity Team';
grant select on handoff_context to authenticated;
-- Trusted fixture counter compares the complete database population, not an
-- actor-filtered RLS subset. It exists only in this rolled-back test session.
create function pg_temp.handoff_object_count() returns bigint language sql security definer set search_path='' as $$select count(*) from public.development_objects$$;
create temporary table handoff_before as select pg_temp.public_fingerprint() data,(select count(*) from public.development_objects) object_count,(select to_jsonb(o) from public.development_objects o where id=(select object_id from handoff_context)) object_row;
grant select on handoff_before to authenticated;
create temporary table handoff_links(label text primary key,payload jsonb);
grant all on handoff_links to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
-- Output registration may change only its canonical association row.
do $$declare c handoff_context;before jsonb;v jsonb;begin
 select * into c from handoff_context;before:=pg_temp.public_fingerprint();
 assert exists(select 1 from public.activity_instances where id=c.a and status='active' and project_id=c.project and workspace_id=c.workspace and team_id=c.team and cohort_id=(select id from acceptance_cohorts where label='Availability'));
 v:=public.add_activity_output(c.a,c.object_id);
 assert v->>'output_type'='development_object' and v->>'development_object_id'=c.object_id::text and v->>'activity_instance_id'=c.a::text;
 assert not(v ? 'content') and not(v ? 'title');
 assert (before-'activity_outputs')=(pg_temp.public_fingerprint()-'activity_outputs'),'output link only; Object and all provenance unchanged';
 assert pg_temp.handoff_object_count()=(select object_count from handoff_before),'actual Object count unchanged';
 assert (select to_jsonb(o) from public.development_objects o where id=c.object_id)=(select object_row from handoff_before),'full canonical O1 including provenance preserved';
 assert (select count(*) from public.activity_outputs where activity_instance_id=c.a and development_object_id=c.object_id)=1;
 insert into handoff_links values('Output',v);
end $$;
-- Collective completion changes only canonical Activity state, never Object approval.
do $$declare c handoff_context;before jsonb;v jsonb;begin
 select * into c from handoff_context;before:=pg_temp.public_fingerprint();
 v:=public.complete_activity(c.a);assert v->>'status'='completed' and v->>'completed_at' is not null;
 assert (before-'activity_instances')=(pg_temp.public_fingerprint()-'activity_instances'),'completion does not mutate Object/provenance/approval/dependency';
 assert pg_temp.handoff_object_count()=(select object_count from handoff_before),'actual Object count unchanged';
 assert (select to_jsonb(o) from public.development_objects o where id=c.object_id)=(select object_row from handoff_before),'full canonical O1 including provenance preserved';
 v:=public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000750801',c.project,c.workspace,c.team);
 assert (v->>'satisfied')::boolean,'canonical exact-context completion unlocks B';
 assert public.resolve_activity_availability('00000000-0000-4000-8000-000000750801',c.project,c.workspace,c.team)='{"available":true}'::jsonb;
 assert not(public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000740803',c.project,c.workspace,c.team)->>'satisfied')::boolean,'approved_output remains unsatisfied in M7';
end $$;
do $$declare c handoff_context;before jsonb;v jsonb;begin
 select * into c from handoff_context;before:=pg_temp.public_fingerprint();
 v:=public.start_activity('00000000-0000-4000-8000-000000750801',c.project,c.workspace,c.team);
 assert (v->>'started')::boolean and v->'activity'->>'status'='active';
 assert v->'activity'->>'project_id'=c.project::text and v->'activity'->>'workspace_id'=c.workspace::text and v->'activity'->>'team_id'=c.team::text;
 assert (before-'activity_instances'-'activity_participants')=(pg_temp.public_fingerprint()-'activity_instances'-'activity_participants'),'start B never clones O1';
 assert pg_temp.handoff_object_count()=(select object_count from handoff_before),'actual Object count unchanged';
 assert (select to_jsonb(o) from public.development_objects o where id=c.object_id)=(select object_row from handoff_before),'full canonical O1 including provenance preserved';
 insert into handoff_links values('B',v->'activity');
end $$;
do $$declare c handoff_context;before jsonb;v jsonb;b uuid;begin
 select * into c from handoff_context;select (payload->>'id')::uuid into b from handoff_links where label='B';before:=pg_temp.public_fingerprint();
 v:=public.add_activity_input(b,c.object_id,true);
 assert v->>'input_type'='development_object' and (v->>'required')::boolean and v->>'development_object_id'=c.object_id::text and v->>'activity_instance_id'=b::text;
 assert not(v ? 'content') and not(v ? 'title');
 assert (before-'activity_inputs')=(pg_temp.public_fingerprint()-'activity_inputs'),'input link only; Object never cloned/replaced';
 assert pg_temp.handoff_object_count()=(select object_count from handoff_before),'actual Object count unchanged';
 assert (select to_jsonb(o) from public.development_objects o where id=c.object_id)=(select object_row from handoff_before),'full canonical O1 including provenance preserved';
 insert into handoff_links values('Input',v);
 assert (select count(*) from public.activity_inputs where activity_instance_id=b and development_object_id=c.object_id)=1;
 assert v->>'development_object_id'=(select payload->>'development_object_id' from handoff_links where label='Output'),'exact O1 identity equality';
 v:=public.resume_activity(c.a);
 assert exists(select 1 from jsonb_array_elements(v->'outputs') x where x->>'id'=(select payload->>'id' from handoff_links where label='Output') and x->>'development_object_id'=c.object_id::text),'A output survives completion';
 v:=public.resume_activity(b);
 assert exists(select 1 from jsonb_array_elements(v->'inputs') x where x->>'id'=(select payload->>'id' from handoff_links where label='Input') and x->>'development_object_id'=c.object_id::text),'B resumes canonical required input';
 assert (pg_temp.public_fingerprint()->'development_objects')=(select data->'development_objects' from handoff_before),'all Object rows including O1 provenance/content/timestamps and count unchanged';
end $$;
-- Exact foreign Object IDs do not confer authorization or implicit sharing.
create function pg_temp.denied_handoff(actor0 uuid,object0 uuid) returns void language plpgsql as $$
declare b uuid;before jsonb;begin
 select (payload->>'id')::uuid into b from handoff_links where label='B';
 perform set_config('request.jwt.claim.sub',actor0::text,true);before:=pg_temp.public_fingerprint();
 begin perform public.add_activity_input(b,object0,true);raise exception 'foreign/stale input accepted';exception when insufficient_privilege then null;end;
 assert before=pg_temp.public_fingerprint(),'denied handoff has zero partial writes';
end $$;
select pg_temp.denied_handoff('00000000-0000-4000-8000-000000006005',(payload->>'id')::uuid) from logged_objects where label in ('Problem','Team','Case');
select pg_temp.denied_handoff('00000000-0000-4000-8000-000000006005','00000000-0000-4000-8000-000000780802');
select pg_temp.denied_handoff('00000000-0000-4000-8000-000000006006',object_id) from handoff_context;
-- Removed initiator loses even the existing/idempotent input path; history remains.
reset role;create temporary table handoff_history as select pg_temp.public_fingerprint() data;
grant select on handoff_history to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team from handoff_context),'00000000-0000-4000-8000-000000006005');
select pg_temp.denied_handoff('00000000-0000-4000-8000-000000006005',object_id) from handoff_context;
do $$declare c handoff_context;begin select * into c from handoff_context;
 assert public.resume_activity(c.a) is null and public.resume_activity((select (payload->>'id')::uuid from handoff_links where label='B')) is null;
 assert not exists(select 1 from public.development_objects where id=c.object_id),'known O1 ID does not bypass RLS after removal';
end $$;
reset role;
do $$declare before jsonb;after jsonb;t text;begin select data into before from handoff_history;after:=pg_temp.public_fingerprint();
 foreach t in array array['development_objects','activity_instances','activity_participants','activity_inputs','activity_outputs'] loop
  assert before->t=after->t,'removal retains historical '||t;
 end loop;
 assert exists(select 1 from public.development_objects where id=(select object_id from handoff_context));
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert public.resume_activity((select a from handoff_context))->'outputs'->0->>'development_object_id'=(select object_id::text from handoff_context);
 assert public.resume_activity((select (payload->>'id')::uuid from handoff_links where label='B'))->'inputs'->0->>'development_object_id'=(select object_id::text from handoff_context),'remaining member retains canonical handoff visibility';
end $$;
reset role;
rollback;
\echo AT-ACT-004 generic canonical output-to-input/no clones/provenance/resume/scope/removal PASS; formal approval DEFERRED TO M8
