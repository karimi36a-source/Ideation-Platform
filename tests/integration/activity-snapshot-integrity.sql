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

-- V1 changes only while the isolated source curriculum is still draft.
update public.activity_definitions set method_type='scamper',instructions='Snapshot V1 instructions',ai_role_code='snapshot_v1_ai',requires_review=false,requires_approval=false,completion_rule='{"min_required_inputs":0,"min_outputs":0}',configuration='{"revision":"V1","nested":{"weights":[1,2],"enabled":false}}' where id='00000000-0000-4000-8000-000000740801';
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



-- M7.17: no trigger disabling or approved-definition fixture rewriting.
create temporary table snapshot_versions(label text primary key,expected jsonb,definition uuid,curriculum uuid,cohort uuid,team uuid,workspace uuid,project uuid,instance uuid,object uuid,original jsonb);
grant all on snapshot_versions to authenticated;
insert into snapshot_versions(label,expected,definition,curriculum,cohort,team,workspace,project)
select 'V1',jsonb_build_object('method_type','scamper','workspace_mode','Team Workspace','instructions','Snapshot V1 instructions','ai_role_code','snapshot_v1_ai','requires_review',false,'requires_approval',false,'completion_rule','{"min_required_inputs":0,"min_outputs":0}'::text,'configuration','{"revision":"V1","nested":{"weights":[1,2],"enabled":false}}'::jsonb),definition,'00000000-0000-4000-8000-000000740602',(select id from acceptance_cohorts where label='Availability'),team,workspace,project from av_context where label='Team';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
update snapshot_versions set instance=(public.start_activity(definition,project,workspace,team)->'activity'->>'id')::uuid where label='V1';
update snapshot_versions set original=public.resume_activity(instance)->'activity' where label='V1';
do $$declare v snapshot_versions;begin select * into v from snapshot_versions where label='V1';
 assert v.instance is not null and v.original->'configuration_snapshot'=v.expected,'I1 exact coherent eight-field V1';
 assert v.original->>'activity_definition_id'=v.definition::text and v.original->>'started_at' is not null;
 assert (select count(*) from jsonb_object_keys(v.expected))=8;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
-- Normal Admin edit of approved V1 must fail; V2 gets its own canonical version.
do $$declare v snapshot_versions;before0 jsonb;begin select * into v from snapshot_versions where label='V1';before0:=pg_temp.public_fingerprint();
 begin perform public.manage_activity('00000000-0000-4000-8000-000000740702',v.definition,'{"name":"Forbidden rewrite","method_type":"reflection","sequence":1}');raise exception 'approved edit allowed';exception when insufficient_privilege then null;end;
 assert before0=pg_temp.public_fingerprint(),'approved V1 edit denied without writes';
end $$;
insert into snapshot_versions(label,expected,curriculum) values('V2',jsonb_build_object('method_type','reflection','workspace_mode','Team Workspace','instructions','Snapshot V2 instructions','ai_role_code','snapshot_v2_ai','requires_review',true,'requires_approval',true,'completion_rule','{"min_required_inputs":0,"min_outputs":1}'::text,'configuration','{"revision":"V2","nested":{"weights":[3,5],"enabled":true}}'::jsonb),(public.manage_curriculum('00000000-0000-4000-8000-000000000601',null,'M7.17 Snapshot V2',null,null,'Isolated approved version fixture')->>'id')::uuid);
do $$declare v snapshot_versions;s uuid;a jsonb;begin select * into v from snapshot_versions where label='V2';
 s:=(public.manage_session(v.curriculum,null,1,'Snapshot V2 session','Isolated integrity test','Snapshot integrity',1,'active')->>'id')::uuid;
 a:=public.manage_activity(s,null,v.expected||'{"name":"Snapshot V2 activity","sequence":1,"status":"active"}'::jsonb);
 update snapshot_versions set definition=(a->>'id')::uuid where label='V2';
 perform public.transition_curriculum(v.curriculum,'approved');
 perform public.set_current_curriculum('00000000-0000-4000-8000-000000000601',v.curriculum);
 update snapshot_versions set cohort=(public.create_cohort('00000000-0000-4000-8000-000000000601',v.curriculum,'Snapshot V2 Cohort','2026-10-01',null,'00000000-0000-4000-8000-000000006002','active','{}')->>'id')::uuid where label='V2';
end $$;
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select cohort,'00000000-0000-4000-8000-000000006005','participant','active' from snapshot_versions where label='V2';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare v snapshot_versions;t jsonb;begin select * into v from snapshot_versions where label='V2';
 t:=public.create_team(v.cohort,'Snapshot V2 Team',null,'00000000-0000-4000-8000-000000006005');
 update snapshot_versions set team=(t->>'teamId')::uuid,workspace=(t->>'workspaceId')::uuid where label='V2';
end $$;
reset role;update public.teams set status='active' where id=(select team from snapshot_versions where label='V2');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
update snapshot_versions set project=(public.create_development_project('Snapshot V2 Project','team',workspace,null,null,team)->>'id')::uuid where label='V2';
reset role;
insert into public.project_memberships(project_id,user_id) select project,'00000000-0000-4000-8000-000000006005' from snapshot_versions where label='V2';
insert into public.project_program_links(project_id,program_id,cohort_id) select project,'00000000-0000-4000-8000-000000000601',cohort from snapshot_versions where label='V2';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
update snapshot_versions set instance=(public.start_activity(definition,project,workspace,team)->'activity'->>'id')::uuid where label='V2';
update snapshot_versions set original=public.resume_activity(instance)->'activity' where label='V2';
create function pg_temp.snapshot_check() returns void language plpgsql as $$
declare v snapshot_versions;before0 jsonb;a jsonb;begin before0:=pg_temp.public_fingerprint();
 for v in select * from snapshot_versions loop
  a:=public.resume_activity(v.instance)->'activity';
  assert a->>'id'=v.instance::text and a->>'activity_definition_id'=v.definition::text,'stable instance/definition/version';
  assert a->'configuration_snapshot'=v.expected,'deep exact V1/V2 equality';
  assert a->>'started_at'=v.original->>'started_at' and a->>'started_by'=v.original->>'started_by','start history unchanged';
 end loop;
 assert before0=pg_temp.public_fingerprint(),'resume is read only';
end $$;
select pg_temp.snapshot_check();
-- Snapshot parameters do not exist on canonical RPC signatures.
reset role;
do $$declare n text;begin
 foreach n in array array['start_activity(uuid,uuid,uuid,uuid)','resume_activity(uuid)','add_activity_input(uuid,uuid,boolean)','add_activity_output(uuid,uuid)','complete_activity(uuid)'] loop
 assert pg_get_function_arguments(('public.'||n)::regprocedure)!~'(configuration|snapshot|instructions|completion_rule|ai_role)','no caller-controlled execution configuration';
 end loop;
 begin update public.activity_definitions set instructions='Forbidden approved V1 change' where id=(select definition from snapshot_versions where label='V1');raise exception 'approved direct rewrite';exception when check_violation then null;end;
 begin update public.activity_instances set configuration_snapshot='{}' where id=(select instance from snapshot_versions where label='V1');raise exception 'even trusted history rewrite';exception when check_violation then null;end;
 assert (select curriculum_version_id from public.cohorts where id=(select cohort from snapshot_versions where label='V1'))=(select curriculum from snapshot_versions where label='V1'),'old Cohort remains V1 despite current Program V2';
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare v snapshot_versions;before0 jsonb;begin before0:=pg_temp.public_fingerprint();
 for v in select * from snapshot_versions loop
  begin update public.activity_instances set configuration_snapshot='{"instructions":"spoof"}' where id=v.instance;raise exception 'client snapshot write';exception when insufficient_privilege then null;end;
 end loop;
 assert before0=pg_temp.public_fingerprint(),'client mutation denied';
end $$;
-- Approved registration must never alter the historical configuration.
update snapshot_versions set object=(public.create_development_object(project,workspace,'PROBLEM','Snapshot source '||label,'Canonical content','User')->>'id')::uuid;
select public.add_activity_input(instance,object,true) from snapshot_versions where label='V1';
select pg_temp.snapshot_check();
savepoint temporary_v1_output;
select public.add_activity_output(instance,object) from snapshot_versions where label='V1';
select pg_temp.snapshot_check();
rollback to temporary_v1_output;
-- I1 completes with zero outputs under its stored V1 rule, despite Program V2.
do $$declare v snapshot_versions;a jsonb;before0 jsonb;begin select * into v from snapshot_versions where label='V1';before0:=pg_temp.public_fingerprint();
 assert not exists(select 1 from public.activity_outputs where activity_instance_id=v.instance);
 a:=public.complete_activity(v.instance);assert a->>'status'='completed' and a->>'completed_at' is not null and a->'configuration_snapshot'=v.expected;
 assert (before0-'activity_instances')=(pg_temp.public_fingerprint()-'activity_instances'),'completion changes only collective Activity state';
end $$;
-- I2 must enforce its distinct stored V2 minimum, without fake approval.
do $$declare v snapshot_versions;before0 jsonb;begin select * into v from snapshot_versions where label='V2';before0:=pg_temp.public_fingerprint();
 begin perform public.complete_activity(v.instance);raise exception 'V2 output minimum ignored';exception when sqlstate 'P7011' then null;end;
 assert before0=pg_temp.public_fingerprint(),'unmet V2 rule is atomic';
end $$;
select public.add_activity_input(instance,object,true) from snapshot_versions where label='V2';
select public.add_activity_output(instance,object) from snapshot_versions where label='V2';
select pg_temp.snapshot_check();
select public.complete_activity(instance) from snapshot_versions where label='V2';
select pg_temp.snapshot_check();
-- Completed historical snapshots cannot be rewritten or detached.
do $$declare v snapshot_versions;before0 jsonb;begin before0:=pg_temp.public_fingerprint();
 for v in select * from snapshot_versions loop
  begin update public.activity_instances set configuration_snapshot='{}' where id=v.instance;raise exception 'completed client snapshot write';exception when insufficient_privilege then null;end;
  assert public.resume_activity(v.instance)->'activity'->>'status'='completed';
  assert (select count(*) from public.activity_participants where activity_instance_id=v.instance)=1;
 end loop;
 assert before0=pg_temp.public_fingerprint();
end $$;
-- Scope privacy still applies to both historical snapshots.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$declare v snapshot_versions;before0 jsonb;begin before0:=pg_temp.public_fingerprint();
 for v in select * from snapshot_versions loop
  assert public.resume_activity(v.instance) is null and public.resume_activity('00000000-0000-4000-8000-000000779999') is null;
  assert not exists(select 1 from public.activity_instances where id=v.instance);
  assert not exists(select 1 from public.activity_inputs where activity_instance_id=v.instance);
  assert not exists(select 1 from public.activity_outputs where activity_instance_id=v.instance);
 end loop;
 assert before0=pg_temp.public_fingerprint(),'unauthorized snapshot reads do not mutate state';
end $$;
reset role;
rollback;
\echo M7.17 approved V1/V2 versioned eight-field snapshots/start/resume/stored completion rules/active-completed immutability/privacy PASS
