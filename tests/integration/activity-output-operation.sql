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
-- M7.9 TEST CASES
create temporary table output_results(label text primary key,payload jsonb);grant select,insert on output_results to authenticated;
create function pg_temp.output_call(a uuid,o uuid,error0 text default null) returns jsonb language plpgsql as $$declare before jsonb;after jsonb;result jsonb;existing boolean;begin
 before:=pg_temp.public_fingerprint();
 select exists(select 1 from public.activity_outputs where activity_instance_id=a and development_object_id=o) into existing;
 begin
  result:=public.add_activity_output(a,o);
  if error0 is not null then raise exception 'Expected safe denial %',error0;end if;
 exception when others then
  if error0 is null or sqlstate<>error0 then raise;end if;
  assert before=pg_temp.public_fingerprint(),'failure has zero writes';return null;
 end;
 after:=pg_temp.public_fingerprint();
 assert (before-'activity_outputs')=(after-'activity_outputs'),'only output link may change';
 if existing then assert before=after,'retry zero writes';end if;
 assert result->>'activity_instance_id'=a::text and result->>'development_object_id'=o::text;
 assert result->>'output_type'='development_object';
 assert result->'artifact_id'='null'::jsonb and result->'decision_id'='null'::jsonb and result->'evidence_id'='null'::jsonb;
 assert not(result ? 'content') and not(result ? 'title') and not(result ? 'metadata');
 assert exists(select 1 from jsonb_array_elements(public.resume_activity(a)->'outputs') i where i->>'id'=result->>'id'),'resume observes canonical registration';
 return result;
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into output_results select 'Personal',pg_temp.output_call(f.id,(o.payload->>'id')::uuid) from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
do $$declare a uuid;o uuid;v jsonb;begin select id into a from resumed_fixture where label='Personal';select (payload->>'id')::uuid into o from logged_objects where label='Problem';v:=pg_temp.output_call(a,o);assert v=(select payload from output_results where label='Personal'),'canonical retry identity';end $$;
insert into output_results select 'Optional',pg_temp.output_call(f.id,(o.payload->>'id')::uuid) from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Solution';
-- Ordinary Team member may contribute without an Activity Participant row.
insert into output_results select 'Team',pg_temp.output_call(f.id,(o.payload->>'id')::uuid) from resumed_fixture f cross join logged_objects o where f.label='Team' and o.label='Activity Team';
do $$begin assert not exists(select 1 from public.activity_participants where activity_instance_id=(select id from resumed_fixture where label='Team') and user_id='00000000-0000-4000-8000-000000006004');end $$;
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'42501') from resumed_fixture f cross join logged_objects o where f.label='Team' and o.label='Problem';
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'42501') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Activity Team';
select pg_temp.output_call(id,'00000000-0000-4000-8000-000000780802','42501') from resumed_fixture where label='Team';
select pg_temp.output_call(id,'00000000-0000-4000-8000-000000789999','42501') from resumed_fixture where label='Personal';
select pg_temp.output_call('00000000-0000-4000-8000-000000789999',(payload->>'id')::uuid,'42501') from logged_objects where label='Problem';
-- Direct normal-client mutation remains denied, including known output IDs.
do $$declare a uuid;o uuid;begin select id into a from resumed_fixture where label='Personal';select (payload->>'id')::uuid into o from logged_objects where label='Problem';
 begin insert into public.activity_outputs(activity_instance_id,development_object_id,output_type) values(a,o,'development_object');raise exception 'direct insert bypass';exception when insufficient_privilege then null;end;
 begin update public.activity_outputs set decision_id=null where id=(select (payload->>'id')::uuid from output_results where label='Personal');raise exception 'direct update bypass';exception when insufficient_privilege then null;end;
 begin delete from public.activity_outputs where id=(select (payload->>'id')::uuid from output_results where label='Personal');raise exception 'direct delete bypass';exception when insufficient_privilege then null;end;
 perform pg_temp.output_call(a,null,'22023');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'42501') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
do $$begin assert not exists(select 1 from public.activity_outputs where id=(select (payload->>'id')::uuid from output_results where label='Personal')),'exact output ID cannot expose private reference';end $$;
-- Lead and scoped Master with existing contributor authority can retry Team link.
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid) from resumed_fixture f cross join logged_objects o where f.label='Team' and o.label='Activity Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid) from resumed_fixture f cross join logged_objects o where f.label='Team' and o.label='Activity Team';
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'42501') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
do $$begin assert not exists(select 1 from public.activity_outputs where id=(select (payload->>'id')::uuid from output_results where label='Personal')),'exact output ID cannot expose private reference';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'42501') from resumed_fixture f cross join logged_objects o where f.label='Team' and o.label='Activity Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'42501') from resumed_fixture f cross join logged_objects o where f.label='Team' and o.label='Activity Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'42501') from resumed_fixture f cross join logged_objects o where f.label='Team' and o.label='Activity Team';
select set_config('request.jwt.claim.sub','',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'28000') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
reset role;
-- Same-Project/cross-Workspace sources are already rejected by the composite FK.
do $$begin begin insert into public.development_objects(project_id,workspace_id,object_type,title,created_by) select p.project,w.id,'PROBLEM','Invalid cross Workspace','00000000-0000-4000-8000-000000006004' from av_context p cross join public.workspaces w where p.label='Personal' and w.workspace_type='PERSONAL' and w.owner_user_id='00000000-0000-4000-8000-000000006005';raise exception 'cross Workspace source accepted';exception when foreign_key_violation then null;end;end $$;

savepoint state_fixture;
-- Preserve the earlier execution as terminal history before the new unstarted fixture.
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from resumed_fixture where label='Personal');
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,status) select '00000000-0000-4000-8000-000000780903',a.activity_definition_id,a.cohort_id,a.project_id,a.workspace_id,'not_started' from public.activity_instances a join resumed_fixture f on f.id=a.id where f.label='Personal';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.output_call('00000000-0000-4000-8000-000000780903',(payload->>'id')::uuid,'55000') from logged_objects where label='Problem';
reset role;rollback to state_fixture;

savepoint state_fixture;
update public.activity_instances set status='submitted',completed_at=null where id=(select id from resumed_fixture where label='Personal');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'55000') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
reset role;rollback to state_fixture;

savepoint state_fixture;
update public.activity_instances set status='under_review',completed_at=null where id=(select id from resumed_fixture where label='Personal');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'55000') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
reset role;rollback to state_fixture;

savepoint state_fixture;
update public.activity_instances set status='revision_requested',completed_at=null where id=(select id from resumed_fixture where label='Personal');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'55000') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
reset role;rollback to state_fixture;

savepoint state_fixture;
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from resumed_fixture where label='Personal');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'55000') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
reset role;rollback to state_fixture;

savepoint state_fixture;
update public.activity_instances set status='archived',completed_at=null where id=(select id from resumed_fixture where label='Personal');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'55000') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Problem';
reset role;rollback to state_fixture;

savepoint removal;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006005');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'42501') from resumed_fixture f cross join logged_objects o where f.label='Team' and o.label='Activity Team';
do $$begin assert not exists(select 1 from public.activity_outputs where id=(select (payload->>'id')::uuid from output_results where label='Team')),'removed starter cannot read known output';end $$;
reset role;do $$begin assert exists(select 1 from public.activity_participants where user_id='00000000-0000-4000-8000-000000006005');assert exists(select 1 from public.project_memberships where user_id='00000000-0000-4000-8000-000000006005' and status='active');end $$;rollback to removal;
savepoint failed_insert;
create function pg_temp.force_output_failure() returns trigger language plpgsql as $$begin raise exception 'fixture failure' using errcode='23514';end $$;
create trigger fixture_failed_output before insert on public.activity_outputs for each row execute function pg_temp.force_output_failure();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.output_call(f.id,(o.payload->>'id')::uuid,'23514') from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Individual Idea';
reset role;rollback to failed_insert;
-- Every table besides activity_outputs remained unchanged for all successful adds;
-- retries/failures changed no public table. Exactly three canonical output rows.
do $$begin assert (select count(*) from public.activity_outputs)=3;
 assert not has_table_privilege('authenticated','public.activity_outputs','INSERT,UPDATE,DELETE');
 assert not has_function_privilege('anon','public.add_activity_output(uuid,uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.add_activity_output(uuid,uuid)','EXECUTE');
 assert (select prosecdef and provolatile='v' and proconfig=array['search_path=""'] from pg_proc where oid='public.add_activity_output(uuid,uuid)'::regprocedure);
end $$;
-- Generic reference handoff only; no completion or formal AT-ACT-004 behavior.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare ctx av_context;later jsonb;link jsonb;o uuid;before_objects jsonb;begin
 select * into ctx from av_context where label='Team';
 select (payload->>'id')::uuid into o from logged_objects where label='Activity Team';
 before_objects:=pg_temp.public_fingerprint()->'development_objects';
 later:=public.start_activity('00000000-0000-4000-8000-000000750804',ctx.project,ctx.workspace,ctx.team);
 assert (later->>'started')::boolean,'isolated later context starts';
 link:=public.add_activity_input((later->'activity'->>'id')::uuid,o,false);
 assert link->>'development_object_id'=o::text,'same canonical output ID reused as later input';
 assert before_objects=pg_temp.public_fingerprint()->'development_objects','handoff does not clone or mutate source';
end $$;
reset role;
rollback;
\echo M7.9 contribution/active state/exact scope/idempotency/RLS/resume/no side effects PASS
