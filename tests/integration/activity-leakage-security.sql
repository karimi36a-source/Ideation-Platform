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

-- M7.11 canonical approved-operation controls; all identities are synthetic.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.add_activity_input(f.id,(o.payload->>'id')::uuid,true) from resumed_fixture f cross join logged_objects o where (f.label='Personal' and o.label='Problem') or (f.label='Team' and o.label='Activity Team');
select public.add_activity_output(f.id,(o.payload->>'id')::uuid) from resumed_fixture f cross join logged_objects o where (f.label='Personal' and o.label='Problem') or (f.label='Team' and o.label='Activity Team');
reset role;
-- Participant presence and otherwise-valid Project membership do not grant Team access.
insert into public.activity_participants(id,activity_instance_id,user_id,joined_at,completed_at) select '00000000-0000-4000-8000-000000711903',id,'00000000-0000-4000-8000-000000006005',now(),now() from resumed_fixture where label='Personal';
insert into public.activity_participants(activity_instance_id,user_id,joined_at) select id,'00000000-0000-4000-8000-000000006006',now() from resumed_fixture where label='Team';
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006006','participant','active' from acceptance_cohorts where label='Availability';
insert into public.project_memberships(project_id,user_id) select project,'00000000-0000-4000-8000-000000006006' from av_context where label='Team';
create temporary table rls_context as select f.label,a.id activity,a.activity_definition_id definition,a.project_id project,a.workspace_id workspace,a.team_id team,a.cohort_id cohort,
 (select id from public.activity_participants where activity_instance_id=a.id order by id limit 1) participant,
 (select id from public.activity_inputs where activity_instance_id=a.id) input,
 (select id from public.activity_outputs where activity_instance_id=a.id) output,
 (select development_object_id from public.activity_outputs where activity_instance_id=a.id) object
 from resumed_fixture f join public.activity_instances a on a.id=f.id;
grant select on rls_context to authenticated,anon;

-- Dedicated direct PostgreSQL boundary tests; no alternate permission model.
create function pg_temp.denied(sql0 text,state0 text default '42501') returns void language plpgsql as $$
declare before0 jsonb;begin before0:=pg_temp.public_fingerprint();
 begin execute sql0;raise exception 'Attack unexpectedly succeeded: %',sql0;
 exception when others then if sqlstate<>state0 then raise;end if;end;
 assert before0=pg_temp.public_fingerprint(),'denied direct attack leaves every public row unchanged';
end $$;
create function pg_temp.read_matrix(label0 text,allowed0 boolean) returns void language plpgsql as $$
declare c rls_context;table0 text;id0 uuid;rows0 jsonb;random0 jsonb;parent0 jsonb;begin
 select * into c from rls_context where label=label0;
 foreach table0 in array array['activity_instances','activity_participants','activity_inputs','activity_outputs'] loop
  id0:=case table0 when 'activity_instances' then c.activity when 'activity_participants' then c.participant when 'activity_inputs' then c.input else c.output end;
  execute format('select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from public.%I x where id=$1',table0) into rows0 using id0;
  execute format('select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from public.%I x where id=$1',table0) into random0 using '00000000-0000-4000-8000-000000719999'::uuid;
  assert random0='[]'::jsonb,'nonexistent identifier has no metadata';
  if allowed0 then assert jsonb_array_length(rows0)=1,'authorized positive exact-ID control';
  else assert rows0=random0,'inaccessible real ID has identical empty visibility';
   if table0<>'activity_instances' then
    execute format('select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from public.%I x where activity_instance_id=$1',table0) into rows0 using c.activity;
    assert rows0='[]'::jsonb,'parent-ID child enumeration does not leak';
   end if;
  end if;
 end loop;
 assert exists(select 1 from public.development_objects where id=c.object)=allowed0,'linked canonical Object privacy';
 assert public.can_read_activity_instance(c.activity)=allowed0,'caller-bound authorization helper';
 assert not public.can_read_activity_instance('00000000-0000-4000-8000-000000719999');
 parent0:=public.resume_activity(c.activity);
 if allowed0 then assert parent0->'activity'->>'id'=c.activity::text;
 else assert parent0 is null and parent0 is not distinct from public.resume_activity('00000000-0000-4000-8000-000000719999');
  assert public.activity_resume_definition_identity(c.activity) is null,'public display helper cannot expose inaccessible Definition';
 end if;
end $$;
create function pg_temp.mutation_matrix(label0 text) returns void language plpgsql as $$
declare c rls_context;v text;table0 text;id0 uuid;begin
 select * into c from rls_context where label=label0;
 -- Inserts spoof identity, scope, state/snapshot, participants, and canonical targets.
 perform pg_temp.denied(format('insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot) values(%L,%L,%L,%L,%L,%L,now(),''active'',''{"completion_rule":{"min_outputs":0},"requires_approval":false}'')',c.definition,c.cohort,c.project,c.workspace,c.team,'00000000-0000-4000-8000-000000006001'));
 perform pg_temp.denied(format('insert into public.activity_participants(activity_instance_id,user_id,participant_role,joined_at) values(%L,%L,''participant'',now())',c.activity,auth.uid()));
 perform pg_temp.denied(format('insert into public.activity_participants(activity_instance_id,user_id,participant_role,joined_at) values(%L,%L,''MASTER'',now())',c.activity,'00000000-0000-4000-8000-000000006001'));
 perform pg_temp.denied(format('insert into public.activity_inputs(activity_instance_id,development_object_id,input_type,required) values(%L,%L,''development_object'',true)',c.activity,c.object));
 perform pg_temp.denied(format('insert into public.activity_outputs(activity_instance_id,development_object_id,output_type) values(%L,%L,''development_object'')',c.activity,c.object));
 perform pg_temp.denied(format('insert into public.activity_inputs(activity_instance_id,development_object_id,input_type,required) values(%L,%L,''artifact'',false)',c.activity,c.object));
 perform pg_temp.denied(format('insert into public.activity_outputs(activity_instance_id,development_object_id,output_type) values(%L,%L,''approved'')',c.activity,c.object));
 foreach table0 in array array['activity_instances','activity_participants','activity_inputs','activity_outputs'] loop
  id0:=case table0 when 'activity_instances' then c.activity when 'activity_participants' then c.participant when 'activity_inputs' then c.input else c.output end;
  perform pg_temp.denied(format('update public.%I set id=id where id=%L',table0,id0));
  perform pg_temp.denied(format('delete from public.%I where id=%L',table0,id0));
  perform pg_temp.denied(format('update public.%I set id=id where id=%L',table0,'00000000-0000-4000-8000-000000719999'));
 end loop;
 foreach v in array array[
  'started_by='''||'00000000-0000-4000-8000-000000006001'||'''',
  'cohort_id='''||'00000000-0000-4000-8000-000000719999'||'''',
  'status=''completed'',completed_at=clock_timestamp()',
  'status=''active'',completed_at=null',
  'configuration_snapshot=''{}''::jsonb',
  'configuration_snapshot=configuration_snapshot||''{"instructions":"spoofed","ai_role_code":"spoofed","requires_review":false,"requires_approval":false,"completion_rule":null}''::jsonb'
 ] loop perform pg_temp.denied(format('update public.activity_instances set %s where id=%L',v,c.activity));end loop;
 perform pg_temp.denied(format('update public.activity_participants set user_id=%L,activity_instance_id=%L,completed_at=null where id=%L','00000000-0000-4000-8000-000000006001',c.activity,c.participant));
 perform pg_temp.denied(format('update public.activity_inputs set required=false,development_object_id=%L where id=%L','00000000-0000-4000-8000-000000780802',c.input));
 perform pg_temp.denied(format('update public.activity_outputs set development_object_id=%L where id=%L','00000000-0000-4000-8000-000000780802',c.output));
end $$;
-- Positive owner/current Team member/Lead/exact scoped Master controls.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.read_matrix('Personal',true);select pg_temp.read_matrix('Team',true);
select pg_temp.mutation_matrix('Personal');select pg_temp.mutation_matrix('Team');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.read_matrix('Personal',false);select pg_temp.read_matrix('Team',true);
select pg_temp.denied('update public.activity_participants set completed_at=null where id=''00000000-0000-4000-8000-000000711903''');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.read_matrix('Personal',false);select pg_temp.read_matrix('Team',true);
-- Same Cohort + participant + otherwise active Project membership do not grant Team access.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.read_matrix('Team',false);select pg_temp.read_matrix('Personal',false);
select pg_temp.mutation_matrix('Team');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.read_matrix('Team',false);select pg_temp.read_matrix('Personal',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select pg_temp.read_matrix('Team',false);select pg_temp.read_matrix('Personal',false);
-- Contextual Mentor has the existing explicit read path, never role-only access.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
select pg_temp.read_matrix('Team',true);select pg_temp.read_matrix('Personal',false);
reset role;savepoint mentor_removed;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team from rls_context where label='Team'),'00000000-0000-4000-8000-000000006008');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
select pg_temp.read_matrix('Team',false);reset role;rollback to mentor_removed;
-- Actual Object RLS, not just parent readability, filters canonical child references.
savepoint object_hidden;
create policy fixture_m711_object_hide on public.development_objects as restrictive for select to authenticated using(id<>(select object from pg_temp.rls_context where label='Team'));
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare c rls_context;v jsonb;begin select * into c from rls_context where label='Team';
 assert exists(select 1 from public.activity_instances where id=c.activity);
 assert not exists(select 1 from public.development_objects where id=c.object);
 assert not exists(select 1 from public.activity_inputs where id=c.input);
 assert not exists(select 1 from public.activity_outputs where id=c.output);
 v:=public.resume_activity(c.activity);assert v->'inputs'='[]'::jsonb and v->'outputs'='[]'::jsonb,'resume does not leak filtered Object IDs';
end $$;
reset role;rollback to object_hidden;
-- Trusted corrupt foreign links must not create Object-ID leakage under caller RLS.
savepoint corrupt_link;
alter table public.activity_inputs disable trigger activity_inputs_scope;
alter table public.activity_outputs disable trigger activity_outputs_scope;
insert into public.activity_inputs(id,activity_instance_id,development_object_id,input_type,required) select '00000000-0000-4000-8000-000000711901',c.activity,(o.payload->>'id')::uuid,'development_object',true from rls_context c cross join logged_objects o where c.label='Team' and o.label='Problem';
insert into public.activity_outputs(id,activity_instance_id,development_object_id,output_type) select '00000000-0000-4000-8000-000000711902',activity,'00000000-0000-4000-8000-000000780802','development_object' from rls_context where label='Team';
alter table public.activity_inputs enable trigger activity_inputs_scope;alter table public.activity_outputs enable trigger activity_outputs_scope;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not exists(select 1 from public.activity_inputs where id='00000000-0000-4000-8000-000000711901');assert not exists(select 1 from public.activity_outputs where id='00000000-0000-4000-8000-000000711902');end $$;
reset role;rollback to corrupt_link;
-- Project membership inactive cannot retain child access.
savepoint membership_invalid;
update public.project_memberships set status='inactive',ends_at=clock_timestamp() where user_id='00000000-0000-4000-8000-000000006004' and project_id=(select project from rls_context where label='Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.read_matrix('Team',false);reset role;rollback to membership_invalid;
-- Project membership expired cannot retain child access.
savepoint membership_invalid;
update public.project_memberships set ends_at=starts_at+interval '1 microsecond' where user_id='00000000-0000-4000-8000-000000006004' and project_id=(select project from rls_context where label='Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.read_matrix('Team',false);reset role;rollback to membership_invalid;
-- Project membership future cannot retain child access.
savepoint membership_invalid;
update public.project_memberships set status='inactive',ends_at=clock_timestamp() where user_id='00000000-0000-4000-8000-000000006004' and project_id=(select project from rls_context where label='Team');
insert into public.project_memberships(project_id,user_id,starts_at) select project,'00000000-0000-4000-8000-000000006004',clock_timestamp()+interval '1 hour' from rls_context where label='Team';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.read_matrix('Team',false);reset role;rollback to membership_invalid;

-- Removed initiator retains historical participant and Project membership only.
create temporary table m711_history as select pg_temp.public_fingerprint() data;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team from rls_context where label='Team'),'00000000-0000-4000-8000-000000006005');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.read_matrix('Team',false);select pg_temp.mutation_matrix('Team');
do $$declare c rls_context;v jsonb;begin select * into c from rls_context where label='Team';
 perform pg_temp.denied(format('select public.add_activity_input(%L,%L,true)',c.activity,c.object));
 perform pg_temp.denied(format('select public.add_activity_output(%L,%L)',c.activity,c.object));
 perform pg_temp.denied(format('select public.complete_activity(%L)',c.activity));
 v:=public.start_activity(c.definition,c.project,c.workspace,c.team);
 assert v='{"started":false,"reasonCode":"INVALID_CONTEXT"}'::jsonb,'removed duplicate path has no existing Activity ID';
end $$;
reset role;
do $$declare old0 jsonb;new0 jsonb;t text;begin select data into old0 from m711_history;new0:=pg_temp.public_fingerprint();
 foreach t in array array['activity_instances','activity_participants','activity_inputs','activity_outputs','development_objects'] loop assert old0->t=new0->t,'history preserved after Team removal';end loop;
 assert exists(select 1 from public.activity_participants where user_id='00000000-0000-4000-8000-000000006005');
 assert exists(select 1 from public.project_memberships where user_id='00000000-0000-4000-8000-000000006005' and status='active');
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.read_matrix('Team',true);select pg_temp.read_matrix('Personal',true);
-- Private helper chaining and extra identity arguments are unavailable to clients.
do $$declare c rls_context;begin select * into c from rls_context where label='Team';
 perform pg_temp.denied(format('select public.activity_execution_context(%L,%L,%L,%L)',c.definition,c.project,c.workspace,c.team));
 perform pg_temp.denied(format('select public.activity_start_snapshot(%L)',c.definition));
 perform pg_temp.denied(format('select public.activity_dependencies_in_context(%L,%L,%L,%L,%L)',c.definition,c.project,c.workspace,c.team,c.cohort));
end $$;
reset role;
-- Anonymous table IDs and functions cannot be used as an existence oracle.
set local role anon;select set_config('request.jwt.claim.sub','',true);
do $$declare t text;c rls_context;fn regprocedure;begin select * into c from rls_context where label='Team';
 foreach t in array array['activity_instances','activity_participants','activity_inputs','activity_outputs'] loop
  perform pg_temp.denied(format('select * from public.%I',t));
  perform pg_temp.denied(format('select * from public.%I where id=%L',t,'00000000-0000-4000-8000-000000719999'));
  perform pg_temp.denied(format('update public.%I set id=id',t));perform pg_temp.denied(format('delete from public.%I',t));
 end loop;
 perform pg_temp.denied(format('select public.start_activity(%L,%L,%L,%L)',c.definition,c.project,c.workspace,c.team));
 perform pg_temp.denied(format('select public.resume_activity(%L)',c.activity));
 perform pg_temp.denied(format('select public.add_activity_input(%L,%L,true)',c.activity,c.object));
 perform pg_temp.denied(format('select public.add_activity_output(%L,%L)',c.activity,c.object));
 perform pg_temp.denied(format('select public.complete_activity(%L)',c.activity));
end $$;
reset role;
-- Catalog audit of the exact retained M7 function surface, with no migration churn.
create temporary table m711_functions(signature text primary key,definer boolean,exposed boolean);
insert into m711_functions values
 ('can_read_activity_instance(uuid)',true,true),
 ('activity_execution_context(uuid,uuid,uuid,uuid)',true,false),
 ('resolve_activity_availability(uuid,uuid,uuid,uuid)',true,true),
 ('evaluate_activity_dependencies(uuid,uuid,uuid,uuid)',true,true),
 ('start_activity(uuid,uuid,uuid,uuid)',true,true),
 ('activity_resume_definition_identity(uuid)',true,true),
 ('add_activity_input(uuid,uuid,boolean)',true,true),
 ('add_activity_output(uuid,uuid)',true,true),
 ('complete_activity(uuid)',true,true),
 ('resume_activity(uuid)',false,true),
 ('activity_dependencies_in_context(uuid,uuid,uuid,uuid,uuid)',false,false),
 ('activity_start_snapshot(uuid)',false,false),
 ('validate_activity_instance_context()',false,false),
 ('preserve_activity_participant_history()',false,false),
 ('validate_activity_object_link()',false,false);
do $$declare f record;p pg_proc;t text;begin
 for f in select * from m711_functions loop
  select * into p from pg_proc where oid=('public.'||f.signature)::regprocedure;
  assert p.prosecdef=f.definer and p.proconfig=array['search_path=""'],'fixed empty path and reviewed privilege mode';
  assert pg_get_userbyid(p.proowner) not in ('anon','authenticated','service_role'),'trusted owner';
  assert has_function_privilege('authenticated',p.oid,'EXECUTE')=f.exposed,'minimal authenticated exposure';
  assert not has_function_privilege('anon',p.oid,'EXECUTE') and not has_function_privilege('service_role',p.oid,'EXECUTE');
  assert not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE'),'no PUBLIC execute';
  assert pg_get_function_arguments(p.oid)!~'(user_id|actor|role)','no caller-supplied identity or role';
 end loop;
 foreach t in array array['activity_instances','activity_participants','activity_inputs','activity_outputs'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass),'RLS enabled';
  assert has_table_privilege('authenticated','public.'||t,'SELECT');
  assert not has_table_privilege('authenticated','public.'||t,'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER');
  assert not has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE');
  assert not exists(select 1 from pg_policy where polrelid=('public.'||t)::regclass and polpermissive and polcmd<>'r'),'no permissive mutation/catch-all';
  assert not exists(select 1 from pg_policy where polrelid=('public.'||t)::regclass and polpermissive and pg_get_expr(polqual,polrelid)='true'),'no broad authenticated SELECT';
  assert exists(select 1 from pg_policy where polrelid=('public.'||t)::regclass and not polpermissive and polcmd='r'),'restrictive canonical read guard';
 end loop;
end $$;

-- M7.16 dedicated adversarial extension. Existing M7.11 direct-CRUD/Object-RLS
-- attacks above are deliberately retained rather than introducing another model.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into acceptance_teams values('Leakage B',public.create_team((select cohort from rls_context where label='Team'),'Leakage Team B',null,'00000000-0000-4000-8000-000000006006'));
reset role;
update public.teams set status='active' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='Leakage B');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('Leakage B',public.create_development_project('Leakage B','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='Leakage B'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='Leakage B')));
insert into logged_projects values('Leakage Other',public.create_development_project('Same Workspace distinct Project','team',(select workspace from rls_context where label='Team'),null,null,(select team from rls_context where label='Team')));
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,case when label='Leakage B' then '00000000-0000-4000-8000-000000006006'::uuid else '00000000-0000-4000-8000-000000006004'::uuid end from logged_projects where label in ('Leakage B','Leakage Other');
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select cohort from rls_context where label='Team') from logged_projects where label in ('Leakage B','Leakage Other');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into logged_objects values('Leakage Other',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Leakage Other'),(select workspace from rls_context where label='Team'),'PROBLEM','Other Project Object','Private same-Workspace different-Project content','User'));
-- Remaining authorized Team A contributor can still use both approved link RPCs.
select public.add_activity_input(activity,object,true) from rls_context where label='Team';
select public.add_activity_output(activity,object) from rls_context where label='Team';
select pg_temp.read_matrix('Team',true);select pg_temp.read_matrix('Personal',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.read_matrix('Team',true);select pg_temp.read_matrix('Personal',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
insert into resumed_fixture select 'Leakage B',(v->'activity'->>'id')::uuid,null from logged_projects p cross join lateral(select public.start_activity('00000000-0000-4000-8000-000000740801',(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(p.payload->>'owner_team_id')::uuid) v) f where p.label='Leakage B';
insert into logged_objects values('Leakage B',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Leakage B'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Leakage B'),'PROBLEM','Team B canonical Object','Private Team B content','User'));
select public.add_activity_input((select id from resumed_fixture where label='Leakage B'),(select (payload->>'id')::uuid from logged_objects where label='Leakage B'),true);
select public.add_activity_output((select id from resumed_fixture where label='Leakage B'),(select (payload->>'id')::uuid from logged_objects where label='Leakage B'));
reset role;
insert into rls_context select 'TeamB',a.id,a.activity_definition_id,a.project_id,a.workspace_id,a.team_id,a.cohort_id,
(select id from public.activity_participants where activity_instance_id=a.id),
(select id from public.activity_inputs where activity_instance_id=a.id),
(select id from public.activity_outputs where activity_instance_id=a.id),
(select development_object_id from public.activity_outputs where activity_instance_id=a.id)
from public.activity_instances a where id=(select id from resumed_fixture where label='Leakage B');
-- Return only safe SQLSTATE/message for comparing known-inaccessible and random.
-- Trusted test-only dynamic execution; production helper inventory was audited above.
create function pg_temp.rpc_denial(sql0 text) returns text language plpgsql as $$
declare before0 jsonb;denial0 text;begin before0:=pg_temp.public_fingerprint();
 begin execute sql0;raise exception 'Unauthorized RPC succeeded';
 exception when insufficient_privilege then denial0:=sqlstate||':'||sqlerrm;end;
 assert before0=pg_temp.public_fingerprint(),'denied RPC performs zero writes';return denial0;
end $$;
create function pg_temp.foreign_operations(label0 text,object0 uuid) returns void language plpgsql as $$
declare c rls_context;known0 text;random0 text;v jsonb;before0 jsonb;begin
 select * into c from rls_context where label=label0;before0:=pg_temp.public_fingerprint();
 assert (select coalesce(jsonb_agg(to_jsonb(o)),'[]'::jsonb) from public.development_objects o where id=c.object)=(select coalesce(jsonb_agg(to_jsonb(o)),'[]'::jsonb) from public.development_objects o where id='00000000-0000-4000-8000-000000719999'),'foreign Object exact/nonexistent metadata equivalent';
 known0:=pg_temp.rpc_denial(format('select public.add_activity_input(%L,%L,true)',c.activity,object0));
 random0:=pg_temp.rpc_denial(format('select public.add_activity_input(%L,%L,true)','00000000-0000-4000-8000-000000719999',object0));
 assert known0=random0,'input error does not expose existence';
 known0:=pg_temp.rpc_denial(format('select public.add_activity_output(%L,%L)',c.activity,object0));
 random0:=pg_temp.rpc_denial(format('select public.add_activity_output(%L,%L)','00000000-0000-4000-8000-000000719999',object0));
 assert known0=random0,'output error does not expose existence';
 known0:=pg_temp.rpc_denial(format('select public.complete_activity(%L)',c.activity));
 random0:=pg_temp.rpc_denial('select public.complete_activity(''00000000-0000-4000-8000-000000719999'')');
 assert known0=random0,'completion error does not expose existence';
 v:=public.start_activity(c.definition,c.project,c.workspace,c.team);
 assert v='{"started":false,"reasonCode":"INVALID_CONTEXT"}'::jsonb,'unauthorized duplicate path leaks no existing instance ID';
 v:=public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000750801',c.project,c.workspace,c.team);
 assert v->>'blockingReason'='INVALID_CONTEXT' and v->'missingRequiredDependencies'='[]'::jsonb and v->'optionalUnsatisfiedDependencies'='[]'::jsonb,'inaccessible dependency details sanitized';
 assert not(v ? 'activity') and not(v ? 'completed_at');
 assert before0=pg_temp.public_fingerprint(),'foreign operation matrix is read only';
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.read_matrix('TeamB',true);
select pg_temp.read_matrix('Team',false);select pg_temp.read_matrix('Personal',false);
select pg_temp.foreign_operations('Team',object) from rls_context where label='TeamB';
select pg_temp.foreign_operations('Personal',object) from rls_context where label='TeamB';
select pg_temp.mutation_matrix('Team');select pg_temp.mutation_matrix('Personal');
-- Fake verified-claim metadata is only client data, never authority.
select set_config('request.jwt.claim.user_metadata','{"user_id":"00000000-0000-4000-8000-000000006005","role":"MASTER","team_lead":true,"dependencySatisfied":true,"cohort_id":"00000000-0000-4000-8000-000000000601"}',true);
select pg_temp.foreign_operations('Team',object) from rls_context where label='TeamB';
select set_config('request.jwt.claim.user_metadata','{}',true);
-- R1 remains removed with participant/Project history but no effective access.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.read_matrix('Team',false);select pg_temp.read_matrix('Personal',false);
select pg_temp.foreign_operations('Team',object) from rls_context where label='Team';
select pg_temp.foreign_operations('Personal',object) from rls_context where label='Personal';
select pg_temp.mutation_matrix('Team');
-- Unrelated Master and Admin product role cannot bypass private educational scope.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.foreign_operations('Team',object) from rls_context where label='TeamB';
select pg_temp.foreign_operations('Personal',object) from rls_context where label='TeamB';
select pg_temp.read_matrix('Team',false);select pg_temp.read_matrix('Personal',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select pg_temp.foreign_operations('Personal',object) from rls_context where label='TeamB';
-- Contextual Mentor retains approved Team read only, no completion or mutation.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
select pg_temp.read_matrix('Team',true);select pg_temp.read_matrix('TeamB',false);select pg_temp.read_matrix('Personal',false);
select pg_temp.rpc_denial(format('select public.add_activity_input(%L,%L,true)',activity,object)) from rls_context where label='Team';
select pg_temp.rpc_denial(format('select public.add_activity_output(%L,%L)',activity,object)) from rls_context where label='Team';
select pg_temp.rpc_denial(format('select public.complete_activity(%L)',activity)) from rls_context where label='Team';
select pg_temp.foreign_operations('Personal',object) from rls_context where label='Personal';
-- Positive caller can read both its Personal and Team objects, but cannot cross-link.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.rpc_denial(format('select public.add_activity_input(%L,%L,true)',t.activity,p.object)) from rls_context t cross join rls_context p where t.label='Team' and p.label='Personal';
select pg_temp.rpc_denial(format('select public.add_activity_output(%L,%L)',p.activity,t.object)) from rls_context t cross join rls_context p where t.label='Team' and p.label='Personal';
select pg_temp.rpc_denial(format('select public.add_activity_input(%L,%L,true)',c.activity,(o.payload->>'id')::uuid)) from rls_context c cross join logged_objects o where c.label='Team' and o.label='Leakage Other';
select pg_temp.rpc_denial(format('select public.add_activity_output(%L,%L)',c.activity,(o.payload->>'id')::uuid)) from rls_context c cross join logged_objects o where c.label='Team' and o.label='Leakage Other';
select pg_temp.read_matrix('Team',true);select pg_temp.read_matrix('TeamB',false);
-- Same-Project/different-Workspace corruption is rejected by the real composite FK.
reset role;
do $$declare before0 jsonb;begin before0:=pg_temp.public_fingerprint();
 begin insert into public.development_objects(project_id,workspace_id,object_type,title,created_by)
 select t.project,p.workspace,'PROBLEM','Impossible cross-Workspace fixture','00000000-0000-4000-8000-000000006004' from rls_context t cross join rls_context p where t.label='Team' and p.label='Personal';
 raise exception 'cross-Workspace Object admitted';exception when foreign_key_violation then null;end;
 assert before0=pg_temp.public_fingerprint(),'invalid pairing cannot fabricate a cross-Workspace Object';
 assert exists(select 1 from public.activity_participants where activity_instance_id=(select activity from rls_context where label='Team') and user_id='00000000-0000-4000-8000-000000006005'),'removed initiator history preserved';
 assert exists(select 1 from public.development_objects where created_by='00000000-0000-4000-8000-000000006005' and id=(select object from rls_context where label='Team')),'removed author attribution preserved';
end $$;
-- Required dependency cannot borrow the inaccessible Team B completed Activity.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select public.complete_activity((select activity from rls_context where label='TeamB'));
-- Availability/dependency evaluation needs current start authority, not read-only membership.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare c rls_context;v jsonb;before0 jsonb;begin select * into c from rls_context where label='Team';before0:=pg_temp.public_fingerprint();
 v:=public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000750801',c.project,c.workspace,c.team);
 assert not(v->>'satisfied')::boolean and jsonb_array_length(v->'missingRequiredDependencies')=1;
 assert not exists(select 1 from public.activity_instances where id=(select activity from rls_context where label='TeamB')),'foreign completed upstream invisible';
 assert position((select activity::text from rls_context where label='TeamB') in v::text)=0;
 assert position((select workspace::text from rls_context where label='TeamB') in v::text)=0;
 assert before0=pg_temp.public_fingerprint(),'dependency attack performs zero writes';
end $$;
reset role;
rollback;
\echo M7.16 adversarial TeamB/Personal/removed/Master/Mentor/anonymous/CRUD/RPC/IDs/Object-RLS/dependency/positive controls PASS
