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

insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory) values('00000000-0000-4000-8000-000000750808','00000000-0000-4000-8000-000000740801','approved_output',false);
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



-- AT-ACT-002 uses the canonical A=740801, B=750801 completion dependency.
create temporary table dep_run(label text primary key,id uuid);
grant all on dep_run to authenticated;
create function pg_temp.check_dependency(def uuid,expected boolean) returns void language plpgsql as $$
declare c av_context;before jsonb;v jsonb;a jsonb;b jsonb;begin
 select * into c from av_context where label='Team';before:=pg_temp.public_fingerprint();
 v:=public.evaluate_activity_dependencies(def,c.project,c.workspace,c.team);
 assert (v->>'satisfied')::boolean=expected,'central evaluator outcome';
 a:=public.resolve_activity_availability(def,c.project,c.workspace,c.team);
 assert (a->>'available')::boolean=expected,'availability matches dependency result';
 assert before=pg_temp.public_fingerprint(),'evaluation is read only';
 if not expected then
  b:=public.start_activity(def,c.project,c.workspace,c.team);
  assert b='{"started":false,"reasonCode":"DEPENDENCY_NOT_MET"}'::jsonb,'blocked start is sanitized';
  assert before=pg_temp.public_fingerprint(),'failed start has zero partial mutation';
  assert not exists(select 1 from public.activity_instances where activity_definition_id=def and project_id=c.project),'no downstream instance';
  assert not exists(select 1 from public.activity_participants p join public.activity_instances i on i.id=p.activity_instance_id where i.activity_definition_id=def and i.project_id=c.project),'no downstream participant';
 end if;
end $$;
create function pg_temp.start_dep(label0 text,def uuid) returns void language plpgsql as $$
declare c av_context;v jsonb;i public.activity_instances;begin
 select * into c from av_context where label='Team';
 v:=public.start_activity(def,c.project,c.workspace,c.team);assert (v->>'started')::boolean,'canonical start';
 select * into i from public.activity_instances where id=(v->'activity'->>'id')::uuid;
 assert i.status='active' and i.activity_definition_id=def and i.project_id=c.project and i.workspace_id=c.workspace and i.team_id=c.team;
 assert i.cohort_id=(select id from acceptance_cohorts where label='Availability') and i.started_by=auth.uid();
 assert (select count(*) from public.activity_participants where activity_instance_id=i.id and user_id=auth.uid() and participant_role='participant')=1;
 insert into dep_run values(label0,i.id);
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;

savepoint matrix_state;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'not_started',null,null,null from av_context where label='Team';
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to matrix_state;

savepoint matrix_state;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'active','00000000-0000-4000-8000-000000006005'::uuid,now(),null from av_context where label='Team';
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to matrix_state;

savepoint matrix_state;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'submitted','00000000-0000-4000-8000-000000006005'::uuid,now(),null from av_context where label='Team';
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to matrix_state;

savepoint matrix_state;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'under_review','00000000-0000-4000-8000-000000006005'::uuid,now(),null from av_context where label='Team';
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to matrix_state;

savepoint matrix_state;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'revision_requested','00000000-0000-4000-8000-000000006005'::uuid,now(),null from av_context where label='Team';
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to matrix_state;

savepoint matrix_state;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,'archived','00000000-0000-4000-8000-000000006005'::uuid,now(),null from av_context where label='Team';
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to matrix_state;

-- Foreign Project completion must not unlock the exact Team context.
savepoint foreign_context;
alter table public.activity_instances disable trigger activity_instances_validate;
insert into public.activity_instances(activity_definition_id,project_id,workspace_id,team_id,cohort_id,status,started_by,started_at,completed_at)
select definition,(select (payload->>'id')::uuid from logged_projects where label='Individual'),workspace,team,(select id from acceptance_cohorts where label='Availability'),'completed','00000000-0000-4000-8000-000000006004',now(),now() from av_context where label='Team';
alter table public.activity_instances enable trigger activity_instances_validate;
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to foreign_context;

-- Foreign Workspace completion must not unlock the exact Team context.
savepoint foreign_context;
alter table public.activity_instances disable trigger activity_instances_validate;
insert into public.activity_instances(activity_definition_id,project_id,workspace_id,team_id,cohort_id,status,started_by,started_at,completed_at)
select definition,project,(select workspace from av_context where label='Personal'),team,(select id from acceptance_cohorts where label='Availability'),'completed','00000000-0000-4000-8000-000000006004',now(),now() from av_context where label='Team';
alter table public.activity_instances enable trigger activity_instances_validate;
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to foreign_context;

-- Foreign Team completion must not unlock the exact Team context.
savepoint foreign_context;
alter table public.activity_instances disable trigger activity_instances_validate;
insert into public.activity_instances(activity_definition_id,project_id,workspace_id,team_id,cohort_id,status,started_by,started_at,completed_at)
select definition,project,workspace,(select (payload->>'teamId')::uuid from acceptance_teams where label='B'),(select id from acceptance_cohorts where label='Availability'),'completed','00000000-0000-4000-8000-000000006004',now(),now() from av_context where label='Team';
alter table public.activity_instances enable trigger activity_instances_validate;
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to foreign_context;

-- Foreign Cohort completion must not unlock the exact Team context.
savepoint foreign_context;
alter table public.activity_instances disable trigger activity_instances_validate;
insert into public.activity_instances(activity_definition_id,project_id,workspace_id,team_id,cohort_id,status,started_by,started_at,completed_at)
select definition,project,workspace,team,(select id from acceptance_cohorts where label='Test'),'completed','00000000-0000-4000-8000-000000006004',now(),now() from av_context where label='Team';
alter table public.activity_instances enable trigger activity_instances_validate;
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to foreign_context;

-- Foreign Personal completion must not unlock the exact Team context.
savepoint foreign_context;
alter table public.activity_instances disable trigger activity_instances_validate;
insert into public.activity_instances(activity_definition_id,project_id,workspace_id,team_id,cohort_id,status,started_by,started_at,completed_at)
select definition,(select project from av_context where label='Personal'),(select workspace from av_context where label='Personal'),null,(select id from acceptance_cohorts where label='Availability'),'completed','00000000-0000-4000-8000-000000006004',now(),now() from av_context where label='Team';
alter table public.activity_instances enable trigger activity_instances_validate;
set local role authenticated;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;rollback to foreign_context;

set local role authenticated;
-- Optional completion and supported future dependencies remain unsatisfied/nonblocking.
savepoint optional_case;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750802',true);
select pg_temp.start_dep('Optional','00000000-0000-4000-8000-000000750802');
rollback to optional_case;
savepoint optional_case;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000740804',true);
select pg_temp.start_dep('Optional','00000000-0000-4000-8000-000000740804');
rollback to optional_case;
savepoint optional_case;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750807',true);
select pg_temp.start_dep('Optional','00000000-0000-4000-8000-000000750807');
rollback to optional_case;

savepoint optional_approval;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750808',true);
select pg_temp.start_dep('Optional','00000000-0000-4000-8000-000000750808');
rollback to optional_approval;
reset role;
-- Unknown vocabulary is rejected by the existing enum without altering it.
do $$begin
 begin insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory)
 values('00000000-0000-4000-8000-000000750808','00000000-0000-4000-8000-000000740801','unknown_required',true);
 raise exception 'unknown accepted';exception when invalid_text_representation then null;end;
end $$;
set local role authenticated;
select pg_temp.start_dep('A','00000000-0000-4000-8000-000000740801');
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
-- Fake completion/status and participant/input/output claims cannot mutate storage.
do $$declare i uuid;begin select id into i from dep_run where label='A';
 begin update public.activity_instances set status='completed',completed_at=now() where id=i;raise exception 'status bypass';exception when insufficient_privilege then null;end;
 begin insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,status,started_by,started_at,completed_at)
 select '00000000-0000-4000-8000-000000750801',(select id from acceptance_cohorts where label='Availability'),project,workspace,'completed',auth.uid(),now(),now() from av_context where label='Team';raise exception 'insert bypass';exception when insufficient_privilege then null;end;
 begin insert into public.activity_participants(activity_instance_id,user_id,joined_at) values(i,auth.uid(),now());raise exception 'participant bypass';exception when insufficient_privilege then null;end;
 begin insert into public.activity_inputs(activity_instance_id) values(i);raise exception 'input bypass';exception when insufficient_privilege then null;end;
 begin insert into public.activity_outputs(activity_instance_id) values(i);raise exception 'output bypass';exception when insufficient_privilege then null;end;
end $$;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',false);
reset role;
create temporary table unchanged_dependencies as select pg_temp.public_fingerprint()->'activity_dependencies' data;
grant select on unchanged_dependencies to authenticated;
set local role authenticated;
do $$declare result jsonb;begin
 result:=public.complete_activity((select id from dep_run where label='A'));
 assert result->>'status'='completed' and result->>'completed_at' is not null;
 assert (pg_temp.public_fingerprint()->'activity_dependencies')=(select data from unchanged_dependencies),'canonical completion does not mutate dependency definitions';
end $$;
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750801',true);
select pg_temp.start_dep('B','00000000-0000-4000-8000-000000750801');
-- Multiple mandatory upstreams: A alone insufficient, actual A2 completion unlocks.
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750803',false);
select pg_temp.start_dep('A2','00000000-0000-4000-8000-000000750804');
select public.complete_activity((select id from dep_run where label='A2'));
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750803',true);
select pg_temp.start_dep('Multi','00000000-0000-4000-8000-000000750803');
-- Completion never manufactures approval, Artifacts or Gate passage.
select pg_temp.check_dependency('00000000-0000-4000-8000-000000740803',false);
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750805',false);
select pg_temp.check_dependency('00000000-0000-4000-8000-000000750806',false);
-- Knowledge of IDs and client completion claims have no authorization weight.
select set_config('request.jwt.claim.user_metadata','{"completed":true,"dependencySatisfied":true,"role":"MASTER"}',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$declare c av_context;x jsonb;y jsonb;before jsonb;begin
 select * into c from av_context where label='Team';before:=pg_temp.public_fingerprint();
 x:=public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000750801',c.project,c.workspace,c.team);
 y:=public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000750801',gen_random_uuid(),c.workspace,c.team);
 assert x=y and x->'missingRequiredDependencies'='[]'::jsonb and x->>'blockingReason'='INVALID_CONTEXT','foreign context returns no private dependency metadata';
 assert public.start_activity('00000000-0000-4000-8000-000000750801',c.project,c.workspace,c.team)='{"started":false,"reasonCode":"INVALID_CONTEXT"}'::jsonb;
 assert not exists(select 1 from public.activity_instances where project_id=c.project);
 assert not exists(select 1 from public.activity_participants where activity_instance_id in(select id from dep_run));
 assert before=pg_temp.public_fingerprint(),'forged claims cannot mutate state';
end $$;
reset role;
rollback;
\echo AT-ACT-002 canonical complete-to-start/status matrix/optional/multiple/deferred/scope/privacy/no-bypass PASS
