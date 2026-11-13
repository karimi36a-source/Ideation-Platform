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
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.av('Personal','{}','{"available":true}');
select pg_temp.av('Team','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}'); -- ordinary member
select pg_temp.av('Personal','{"definition":"00000000-0000-4000-8000-000000740801"}','{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}');
select pg_temp.av('Personal',jsonb_build_object('team',(select team from av_context where label='Team')),'{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.av('Team','{}','{"available":true}'); -- exact active Lead
select pg_temp.av('Personal','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
select pg_temp.av('Team','{"team":null}','{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}');
select pg_temp.av('Team','{"definition":"00000000-0000-4000-8000-000000740806"}','{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}');
select pg_temp.av('Team','{"definition":"00000000-0000-4000-8000-000000740807"}','{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}');
select pg_temp.av('Team','{"definition":"00000000-0000-4000-8000-000000740802"}','{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}');
select pg_temp.av('Team','{"definition":"00000000-0000-4000-8000-000000740803"}','{"available":false,"reasonCode":"DEPENDENCY_NOT_MET"}');
select pg_temp.av('Team','{"definition":"00000000-0000-4000-8000-000000740804"}','{"available":true}');
select pg_temp.av('Team','{"definition":"00000000-0000-4000-8000-000000740805"}','{"available":false,"reasonCode":"ACTIVITY_NOT_AVAILABLE"}');
select pg_temp.av('Team','{"definition":"00000000-0000-4000-8000-000000000801"}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
select pg_temp.av('Team','{"definition":"00000000-0000-4000-8000-000000009999"}','{"available":false,"reasonCode":"INVALID_CONTEXT"}'); -- wrong curriculum
select pg_temp.av('Team',jsonb_build_object('workspace',(select workspace from av_context where label='Personal')),'{"available":false,"reasonCode":"INVALID_CONTEXT"}');
select pg_temp.av('Team',jsonb_build_object('team',(select payload->>'teamId' from acceptance_teams where label='B')),'{"available":false,"reasonCode":"INVALID_CONTEXT"}');
do $$declare u uuid;begin foreach u in array array['00000000-0000-4000-8000-000000006001'::uuid,'00000000-0000-4000-8000-000000006003'::uuid,'00000000-0000-4000-8000-000000006006'::uuid,'00000000-0000-4000-8000-000000006008'::uuid] loop
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform pg_temp.av('Team','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
 perform pg_temp.av('Personal','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
 perform pg_temp.av('Team','{"project":"00000000-0000-4000-8000-000000009999"}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');end loop;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.av('Case','{}','{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}');
select pg_temp.av('Team','{}','{"available":true}'); -- exact Master with canonical membership/Project access
select pg_temp.av('Personal','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.av('Team','{}','{"available":false,"reasonCode":"UNAUTHENTICATED"}');
reset role;
-- Valid owner but enrollment not active must fail. Existing lifecycle trigger sets timestamps.
savepoint enrollment;
update public.enrollments set status='completed' where user_id='00000000-0000-4000-8000-000000006004' and cohort_id=(select id from acceptance_cohorts where label='Test') and status='active';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.av('Personal','{}','{"available":false,"reasonCode":"NOT_ENROLLED"}');
reset role;rollback to enrollment;
savepoint enrollment;
update public.enrollments set status='withdrawn' where user_id='00000000-0000-4000-8000-000000006004' and cohort_id=(select id from acceptance_cohorts where label='Test') and status='active';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.av('Personal','{}','{"available":false,"reasonCode":"NOT_ENROLLED"}');
reset role;rollback to enrollment;
savepoint enrollment;
update public.enrollments set status='removed' where user_id='00000000-0000-4000-8000-000000006004' and cohort_id=(select id from acceptance_cohorts where label='Test') and status='active';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.av('Personal','{}','{"available":false,"reasonCode":"NOT_ENROLLED"}');
reset role;rollback to enrollment;
savepoint closed_link;
update public.project_program_links set completed_at=clock_timestamp() where project_id=(select project from av_context where label='Personal');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.av('Personal','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
reset role;rollback to closed_link;
-- Lifecycle and canonical scope fail closed; no special archive/read permission is introduced.
savepoint archived_project;
update public.development_projects set status='archived',archived_at=clock_timestamp() where id=(select project from av_context where label='Personal');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.av('Personal','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
reset role;rollback to archived_project;
savepoint archived_workspace;
update public.workspaces set status='archived',archived_at=clock_timestamp() where id=(select workspace from av_context where label='Personal');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.av('Personal','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
reset role;rollback to archived_workspace;
savepoint archived_team;
update public.teams set status='archived',archived_at=clock_timestamp() where id=(select team from av_context where label='Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.av('Team','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
reset role;rollback to archived_team;
-- Every nonterminal status blocks, while completed/archived history does not.
do $$declare status0 public.activity_instance_status;instance_id uuid;result jsonb;before jsonb;begin
 foreach status0 in array array['not_started','active','submitted','under_review','revision_requested','completed','archived']::public.activity_instance_status[] loop
 insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,started_by,started_at,completed_at)
 select definition,(select id from acceptance_cohorts where label='Availability'),project,workspace,team,status0,
 case when status0='not_started' then null else '00000000-0000-4000-8000-000000006005'::uuid end,
 case when status0='not_started' then null else now() end,case when status0='completed' then now() else null end from av_context where label='Team' returning id into instance_id;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 before:=pg_temp.public_fingerprint();
 result:=public.resolve_activity_availability('00000000-0000-4000-8000-000000740801',(select project from av_context where label='Team'),(select workspace from av_context where label='Team'),(select team from av_context where label='Team'));
 if status0 in ('completed','archived') then assert result='{"available":true}'::jsonb,'history alone must not block';
 else assert result=jsonb_build_object('available',false,'reasonCode','ACTIVE_INSTANCE_EXISTS','existingActiveInstanceId',instance_id),'canonical duplicate ID';
 -- Close nonterminal fixture so the next status can be tested without deleting history.
 end if;
 assert before=pg_temp.public_fingerprint(),'duplicate resolver does not write';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
 perform pg_temp.av('Team','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
 perform pg_temp.av('Team','{"project":"00000000-0000-4000-8000-000000009999"}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 if status0='not_started' then update public.activity_instances set status='completed',started_by='00000000-0000-4000-8000-000000006005',started_at=now(),completed_at=now() where id=instance_id;
 elsif status0 not in ('completed','archived') then update public.activity_instances set status='completed',completed_at=now() where id=instance_id;end if;
 end loop;end $$;
-- An invited owner retains Project ownership but has no start eligibility.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000740901','availability-invited@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000740901','active');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000740901','participant','invited' from acceptance_cohorts where label='Test';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000740901',true);
select public.create_personal_workspace();
insert into logged_projects select 'Invited',public.create_development_project('Invited availability fixture','individual',id) from public.workspaces where workspace_type='PERSONAL';
reset role;
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test') from logged_projects where label='Invited';
insert into av_context select 'Invited','00000000-0000-4000-8000-000000000801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,null from logged_projects where label='Invited';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000740901',true);
select pg_temp.av('Invited','{}','{"available":false,"reasonCode":"NOT_ENROLLED"}');
reset role;
-- Removed Lead loses launch authority despite physically preserved Project participation.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006005');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.av('Team','{}','{"available":false,"reasonCode":"INVALID_CONTEXT"}');
reset role;
do $$begin
 assert not exists(select 1 from public.activity_participants) and not exists(select 1 from public.activity_inputs) and not exists(select 1 from public.activity_outputs),'no execution side effects';
 assert (select workspace_mode from public.activity_definitions where id='00000000-0000-4000-8000-000000000801')='Personal Workspace','production seed unchanged';
 assert (select prosecdef and provolatile='s' and proconfig=array['search_path=""'] from pg_proc where oid='public.resolve_activity_availability(uuid,uuid,uuid,uuid)'::regprocedure),'stable scoped definer fixed search path';
 assert not has_function_privilege('anon','public.resolve_activity_availability(uuid,uuid,uuid,uuid)','EXECUTE') and not has_function_privilege('service_role','public.resolve_activity_availability(uuid,uuid,uuid,uuid)','EXECUTE'),'restricted RPC';
 assert not has_function_privilege('authenticated','public.activity_dependencies_in_context(uuid,uuid,uuid,uuid,uuid)','EXECUTE'),'private dependency branch';
end $$;
set local role anon;
do $$begin begin perform public.resolve_activity_availability('00000000-0000-4000-8000-000000000801',null,null,null);raise exception 'anonymous RPC';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
\echo M7.4 availability/authority/modes/context/dependency/duplicates/privacy/no-write security PASS
\echo M7.4 availability Personal/auth/context/enrollment/duplicates/privacy/no-writes PASS
