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
-- Independent completion-rule cases receive distinct draft Activity Definitions.
-- This preserves exact-context uniqueness without bypassing curriculum history.
create temporary table completion_definitions(label text primary key,id uuid);
insert into public.activity_definitions
select (jsonb_populate_record(null::public.activity_definitions,to_jsonb(a)||jsonb_build_object('id',gen_random_uuid(),'name','Completion fixture '||v.label,'sequence',v.sequence))).*
from (values
('Personal','Personal',100),
('Lead','Team',101),
('Master','Team',102),
('Expiry','Team',103),
('State not_started','Personal',104),
('State submitted','Personal',105),
('State under_review','Personal',106),
('State revision_requested','Personal',107),
('State archived','Personal',108),
('EmptyObject','Personal',109),
('EmptyText','Personal',110),
('Whitespace','Personal',111),
('Zero','Personal',112),
('TextZero','Personal',113),
('MissingInput','Personal',114),
('MissingOutput','Personal',115),
('Negative','Personal',116),
('Fraction','Personal',117),
('StringCount','Personal',118),
('Partial','Personal',119),
('Unknown','Personal',120),
('Array','Personal',121),
('Malformed','Personal',122),
('Boolean','Personal',123),
('NullCount','Personal',124),
('Counts','Personal',125),
('Optional','Personal',126),
('CorruptInput','Team',127),
('CorruptOutput','Team',128)
) v(label,context,sequence) join public.activity_definitions a on a.id=case when v.context='Personal' then '00000000-0000-4000-8000-000000740806'::uuid else '00000000-0000-4000-8000-000000740801'::uuid end;
insert into completion_definitions select substring(name from 20),id from public.activity_definitions where name like 'Completion fixture %';
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

-- M7.10 PERSISTENT FIXTURES: trusted isolated schema states, never production edits.
create temporary table completion_fixture(label text primary key,id uuid);grant select,insert on completion_fixture to authenticated;
create function pg_temp.make_completion(label0 text,context0 text,rule0 jsonb,status0 public.activity_instance_status default 'active') returns uuid
language plpgsql security definer set search_path='' as $$declare a public.activity_instances;new_id uuid;begin
 select x.* into a from public.activity_instances x join pg_temp.resumed_fixture f on f.id=x.id where f.label=context0;
 insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
 values((select id from pg_temp.completion_definitions where label=label0),a.cohort_id,a.project_id,a.workspace_id,a.team_id,
 case when status0='not_started' then null else a.started_by end,case when status0='not_started' then null else a.started_at end,status0,
 a.configuration_snapshot||jsonb_build_object('completion_rule',rule0,'requires_review',true,'requires_approval',true)) returning id into new_id;
 insert into pg_temp.completion_fixture values(label0,new_id);return new_id;
end $$;
select pg_temp.make_completion('Personal','Personal',null);
select pg_temp.make_completion('Lead','Team',null);
select pg_temp.make_completion('Master','Team',null);
select pg_temp.make_completion('Expiry','Team',null);

-- M7.10 TEST CASES
create function pg_temp.complete_call(a uuid,error0 text default null) returns jsonb language plpgsql as $$
declare before jsonb;after jsonb;old0 jsonb;result jsonb;resume0 jsonb;begin
 before:=pg_temp.public_fingerprint();select to_jsonb(x) into old0 from public.activity_instances x where id=a;
 begin
  result:=public.complete_activity(a);
  if error0 is not null then raise exception 'Expected denial %',error0;end if;
 exception when others then
  if error0 is null or sqlstate<>error0 then raise;end if;
  assert before=pg_temp.public_fingerprint(),'failure has no partial writes';return null;
 end;
 after:=pg_temp.public_fingerprint();
 assert (before-'activity_instances')=(after-'activity_instances'),'no participant/Object/I-O/Project/audit/dependency writes';
 assert result->>'id'=a::text and result->>'status'='completed' and (result->>'completed_at')::timestamptz >= (result->>'started_at')::timestamptz;
 assert (old0-array['status','completed_at','updated_at'])=(result-array['status','completed_at','updated_at']),'immutable execution identity/snapshot';
 if old0->>'status'='completed' then assert old0=result and before=after,'retry has no writes and unchanged timestamp';end if;
 resume0:=public.resume_activity(a);assert resume0->'activity'=result,'resume returns exact completed row';
 return result;
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id) from completion_fixture where label='Personal';
select pg_temp.complete_call(id) from completion_fixture where label='Personal';
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Lead';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id) from completion_fixture where label='Lead';
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.complete_call(id) from completion_fixture where label='Master';
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Master';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Master';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Master';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Master';
select pg_temp.complete_call('00000000-0000-4000-8000-000000719999','42501');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.complete_call(id,'28000') from completion_fixture where label='Personal';
reset role;
select pg_temp.make_completion('State not_started','Personal',null,'not_started');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'55000') from completion_fixture where label='State not_started';
reset role;
select pg_temp.make_completion('State submitted','Personal',null,'submitted');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'55000') from completion_fixture where label='State submitted';
reset role;
select pg_temp.make_completion('State under_review','Personal',null,'under_review');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'55000') from completion_fixture where label='State under_review';
reset role;
select pg_temp.make_completion('State revision_requested','Personal',null,'revision_requested');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'55000') from completion_fixture where label='State revision_requested';
reset role;
select pg_temp.make_completion('State archived','Personal',null,'archived');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'55000') from completion_fixture where label='State archived';
reset role;
select pg_temp.make_completion('EmptyObject','Personal','{}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id) from completion_fixture where label='EmptyObject';
reset role;
select pg_temp.make_completion('EmptyText','Personal','""'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id) from completion_fixture where label='EmptyText';
reset role;
select pg_temp.make_completion('Whitespace','Personal','"  "'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id) from completion_fixture where label='Whitespace';
reset role;
select pg_temp.make_completion('Zero','Personal','{"min_required_inputs":0,"min_outputs":0}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id) from completion_fixture where label='Zero';
reset role;
select pg_temp.make_completion('TextZero','Personal','"{\"min_required_inputs\":0,\"min_outputs\":0}"'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id) from completion_fixture where label='TextZero';
reset role;
select pg_temp.make_completion('MissingInput','Personal','{"min_required_inputs":1,"min_outputs":0}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7011') from completion_fixture where label='MissingInput';
reset role;
select pg_temp.make_completion('MissingOutput','Personal','{"min_required_inputs":0,"min_outputs":1}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7011') from completion_fixture where label='MissingOutput';
reset role;
select pg_temp.make_completion('Negative','Personal','{"min_required_inputs":-1,"min_outputs":0}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7010') from completion_fixture where label='Negative';
reset role;
select pg_temp.make_completion('Fraction','Personal','{"min_required_inputs":0,"min_outputs":1.5}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7010') from completion_fixture where label='Fraction';
reset role;
select pg_temp.make_completion('StringCount','Personal','{"min_required_inputs":"1","min_outputs":0}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7010') from completion_fixture where label='StringCount';
reset role;
select pg_temp.make_completion('Partial','Personal','{"min_outputs":0}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7010') from completion_fixture where label='Partial';
reset role;
select pg_temp.make_completion('Unknown','Personal','{"min_required_inputs":0,"min_outputs":0,"approve":true}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7010') from completion_fixture where label='Unknown';
reset role;
select pg_temp.make_completion('Array','Personal','[]'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7010') from completion_fixture where label='Array';
reset role;
select pg_temp.make_completion('Malformed','Personal','"legacy prose"'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7010') from completion_fixture where label='Malformed';
reset role;
select pg_temp.make_completion('Boolean','Personal','true'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7010') from completion_fixture where label='Boolean';
reset role;
select pg_temp.make_completion('NullCount','Personal','{"min_required_inputs":null,"min_outputs":0}'::jsonb);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7010') from completion_fixture where label='NullCount';
reset role;

select pg_temp.make_completion('Counts','Personal','{"min_required_inputs":2,"min_outputs":2}');
select pg_temp.make_completion('Optional','Personal','{"min_required_inputs":1,"min_outputs":0}');
select pg_temp.make_completion('CorruptInput','Team','{"min_required_inputs":1,"min_outputs":0}');
select pg_temp.make_completion('CorruptOutput','Team','{"min_required_inputs":0,"min_outputs":1}');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.add_activity_input(f.id,(o.payload->>'id')::uuid,true) from completion_fixture f cross join logged_objects o where f.label='Counts' and o.label in ('Problem','Solution');
select pg_temp.complete_call(id,'P7011') from completion_fixture where label='Counts';
select public.add_activity_output(f.id,(o.payload->>'id')::uuid) from completion_fixture f cross join logged_objects o where f.label='Counts' and o.label in ('Problem','Solution');
select pg_temp.complete_call(id) from completion_fixture where label='Counts';
select public.add_activity_input(f.id,(o.payload->>'id')::uuid,false) from completion_fixture f cross join logged_objects o where f.label='Optional' and o.label='Problem';
select pg_temp.complete_call(id,'P7011') from completion_fixture where label='Optional';
do $$begin begin update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from completion_fixture where label='Optional');raise exception 'direct update bypass';exception when insufficient_privilege then null;end;end $$;
reset role;
-- Trusted corrupt-link fixtures only: never weaken production validation/RLS.
savepoint corrupt_links;
alter table public.activity_inputs disable trigger activity_inputs_scope;
alter table public.activity_outputs disable trigger activity_outputs_scope;
insert into public.activity_inputs(activity_instance_id,development_object_id,input_type,required) select f.id,(o.payload->>'id')::uuid,'development_object',true from completion_fixture f cross join logged_objects o where f.label='CorruptInput' and o.label='Problem';
insert into public.activity_outputs(activity_instance_id,development_object_id,output_type) select f.id,(o.payload->>'id')::uuid,'development_object' from completion_fixture f cross join logged_objects o where f.label='CorruptOutput' and o.label='Problem';
alter table public.activity_inputs enable trigger activity_inputs_scope;
alter table public.activity_outputs enable trigger activity_outputs_scope;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'P7011') from completion_fixture where label in ('CorruptInput','CorruptOutput');
reset role;rollback to corrupt_links;
-- Same-Project/different-Workspace corruption: trusted rollback-only fixture.
savepoint corrupt_workspace;
update public.activity_inputs set required=true where activity_instance_id=(select id from completion_fixture where label='Optional');
alter table public.development_objects disable trigger all;
update public.development_objects set workspace_id=(select id from public.workspaces where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000006005') where id=(select (payload->>'id')::uuid from logged_objects where label='Problem');
alter table public.development_objects enable trigger all;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.complete_call(id,'P7011') from completion_fixture where label='Optional';
reset role;rollback to corrupt_workspace;
-- Removed historical initiator remains a participant, not an authorization source.
savepoint removed;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006005');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Lead';
select pg_temp.complete_call(id,'42501') from resumed_fixture where label='Team';
reset role;do $$begin assert exists(select 1 from public.activity_participants where user_id='00000000-0000-4000-8000-000000006005');end $$;rollback to removed;
-- Project paused: current canonical state, not historical participation.
savepoint parent_state;
update public.development_projects set status='paused' where id=(select project from av_context where label='Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Expiry';
reset role;rollback to parent_state;
-- Workspace inactive: current canonical state, not historical participation.
savepoint parent_state;
update public.workspaces set status='inactive' where id=(select workspace from av_context where label='Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Expiry';
reset role;rollback to parent_state;
-- Cohort completed: current canonical state, not historical participation.
savepoint parent_state;
update public.cohorts set status='completed' where id=(select cohort_id from public.activity_instances where id=(select id from completion_fixture where label='Expiry'));
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Expiry';
reset role;rollback to parent_state;
-- Enrollment removed: current canonical state, not historical participation.
savepoint parent_state;
update public.enrollments set status='removed' where user_id='00000000-0000-4000-8000-000000006005' and cohort_id=(select cohort_id from public.activity_instances where id=(select id from completion_fixture where label='Expiry'));
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Expiry';
reset role;rollback to parent_state;
-- Profile suspended: current canonical state, not historical participation.
savepoint parent_state;
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000006005';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Expiry';
reset role;rollback to parent_state;
-- Participation closed: current canonical state, not historical participation.
savepoint parent_state;
update public.project_program_links set completed_at=clock_timestamp() where project_id=(select project from av_context where label='Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Expiry';
reset role;rollback to parent_state;
-- Master role expired: current canonical state, not historical participation.
savepoint parent_state;
update public.role_assignments set ends_at=starts_at+interval '1 microsecond' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select cohort_id from public.activity_instances where id=(select id from completion_fixture where label='Expiry'));
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Expiry';
reset role;rollback to parent_state;
-- Project membership future: current canonical state, not historical participation.
savepoint parent_state;
update public.project_memberships set status='inactive',ends_at=clock_timestamp() where user_id='00000000-0000-4000-8000-000000006005' and project_id=(select project from av_context where label='Team');
insert into public.project_memberships(project_id,user_id,starts_at) select project,'00000000-0000-4000-8000-000000006005',clock_timestamp()+interval '1 hour' from av_context where label='Team';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Expiry';
reset role;rollback to parent_state;
-- Project membership expired: current canonical state, not historical participation.
savepoint parent_state;
update public.project_memberships set ends_at=starts_at+interval '1 microsecond' where user_id='00000000-0000-4000-8000-000000006005' and project_id=(select project from av_context where label='Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id,'42501') from completion_fixture where label='Expiry';
reset role;rollback to parent_state;
-- Actual canonical completion satisfies downstream completion, never approval.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.complete_call(id) from resumed_fixture where label='Team';
do $$declare c av_context;v jsonb;begin select * into c from av_context where label='Team';
 v:=public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000750801',c.project,c.workspace,c.team);
 assert (v->>'satisfied')::boolean,'canonical completed upstream satisfies exact-context completion';
 v:=public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000740803',c.project,c.workspace,c.team);
 assert not (v->>'satisfied')::boolean,'completion does not manufacture formal approval';
end $$;

-- Canonical isolated Team B execution in the same Cohort, distinct Project/Workspace.
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006006','participant','active' from acceptance_cohorts where label='Availability';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into acceptance_teams values('Dependency B',public.create_team((select id from acceptance_cohorts where label='Availability'),'Dependency isolation B'));
reset role;update public.teams set status='active' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='Dependency B');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('Dependency B',public.create_development_project('Dependency B','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='Dependency B'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='Dependency B')));
reset role;
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Availability') from logged_projects where label='Dependency B';
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,completed_at)
select '00000000-0000-4000-8000-000000750804',(select id from acceptance_cohorts where label='Availability'),(p.payload->>'id')::uuid,(t.payload->>'workspaceId')::uuid,(t.payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006006',now(),'completed',now() from logged_projects p cross join acceptance_teams t where p.label='Dependency B' and t.label='Dependency B';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare c av_context;v jsonb;begin select * into c from av_context where label='Team';
 v:=public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000750803',c.project,c.workspace,c.team);
 assert not (v->>'satisfied')::boolean and jsonb_array_length(v->'missingRequiredDependencies')=1,'Team B completion cannot satisfy Team A missing prerequisite';
end $$;
reset role;
do $$begin
 assert not has_table_privilege('authenticated','public.activity_instances','UPDATE');
 assert not has_function_privilege('anon','public.complete_activity(uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.complete_activity(uuid)','EXECUTE');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.complete_activity(uuid)'::regprocedure);
 assert not exists(select 1 from public.activity_participants where completed_at is not null),'no individual participant completion';
 assert not exists(select 1 from public.activity_definitions where completion_rule is not null),'production seed has no unsupported legacy rule';
end $$;
rollback;
\echo M7.10 canonical completion/authority/V1 counts/rollback/no approval/participants/resume/dependencies/RLS PASS
