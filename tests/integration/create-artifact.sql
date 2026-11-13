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

-- Canonical parent resource counts establish that schema writes have no side effects.
create temporary table parent_counts as select (select count(*) from public.development_projects) projects,(select count(*) from public.workspaces) workspaces,(select count(*) from public.teams) teams,(select count(*) from public.cohorts) cohorts,(select count(*) from public.project_program_links) links;
create temporary table instances(label text primary key,id uuid);grant select on instances to authenticated,anon;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
 select '00000000-0000-4000-8000-000000000801',c.id,(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,
 case when p.label='Team' then (select (payload->>'teamId')::uuid from acceptance_teams where label='A') else null end,
 case when p.label='Case' then '00000000-0000-4000-8000-000000006002'::uuid else '00000000-0000-4000-8000-000000006004'::uuid end,
 now(),'active','{"role":"ADMIN","owner":"not-authority"}' from logged_projects p cross join acceptance_cohorts c where c.label='Test';
insert into instances select p.label,i.id from public.activity_instances i join logged_projects p on (p.payload->>'id')::uuid=i.project_id;


grant select on logged_projects,instances to anon;
-- M8.4 TEST CASES

create temporary table created_artifacts(label text,payload jsonb);grant select,insert on created_artifacts to authenticated;
create temporary table creation_before as select
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i) activities,
 (select count(*) from public.activity_outputs) outputs,
 (select count(*) from public.artifact_object_links) links,
 (select count(*) from public.change_log) logs;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into created_artifacts select 'Personal',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PITCH_DECK_RECORD','  Personal Bank  ',null,true,false) from logged_projects where label='Individual';
-- M10.13 reserves TEAM_DECISION_RECORD for configured Decision composition.
insert into created_artifacts select 'Team',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PITCH_DECK_RECORD','Team Draft',null,false,true) from logged_projects where label='Team';
insert into created_artifacts select 'Active provenance',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PITCH_DECK_RECORD','Active provenance',(select id from instances where label='Individual'),true,true) from logged_projects where label='Individual';
reset role;
do $$declare x record;begin
 for x in select a.*,v.id version_id,v.version_number,v.version_label,v.content_snapshot,v.change_summary,v.status version_status,v.created_by version_creator,v.created_at version_created,v.previous_version_id,v.approved_by,v.approved_at,v.approval_note from created_artifacts f join public.artifacts a on a.id=(f.payload->>'artifactId')::uuid join public.artifact_versions v on v.artifact_id=a.id loop
 assert x.status='ACTIVE' and x.archived_at is null and x.current_version_id is null;
 assert x.created_by='00000000-0000-4000-8000-000000006004' and x.version_creator=x.created_by;
 assert x.version_status='DRAFT' and x.version_number=1 and x.version_label is null and x.change_summary is null and x.content_snapshot='{}'::jsonb;
 assert x.previous_version_id is null and x.approved_by is null and x.approved_at is null and x.approval_note is null;
 assert x.created_at is not null and x.version_created is not null;
 assert (select count(*) from public.artifact_versions where artifact_id=x.id)=1;
 end loop;
 assert (select title from public.artifacts where id=(select (payload->>'artifactId')::uuid from created_artifacts where label='Personal'))='Personal Bank';
 assert (select review_required and not approval_required from public.artifacts where id=(select (payload->>'artifactId')::uuid from created_artifacts where label='Personal'));
 assert (select not review_required and approval_required from public.artifacts where id=(select (payload->>'artifactId')::uuid from created_artifacts where label='Team'));
 assert (select activities from creation_before)=(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i),'active provenance unchanged';
 assert (select objects from creation_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),'no Object creation/mutation';
 assert (select outputs from creation_before)=(select count(*) from public.activity_outputs);
 assert (select links from creation_before)=(select count(*) from public.artifact_object_links);
 assert (select logs from creation_before)=(select count(*) from public.change_log),'no invented audit';
 assert to_regclass('public.project_baselines') is null and to_regclass('public.project_baselines') is null;
 assert (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean)'::regprocedure);
 assert has_function_privilege('authenticated','public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean)','EXECUTE');
 assert not has_function_privilege('anon','public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean)','EXECUTE');
 assert not has_function_privilege('service_role','public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean)','EXECUTE');
end $$;
create function pg_temp.deny_create(p uuid,w uuid,i uuid default null,expected text default '42501') returns void language plpgsql as $$
declare na bigint;nv bigint;begin
 select count(*) into na from public.artifacts;select count(*) into nv from public.artifact_versions;
 begin perform public.create_artifact(p,w,'PITCH_DECK_RECORD','Rejected',i,true,true);raise exception 'Unauthorized Artifact creation accepted';exception when others then if sqlstate<>expected then raise;end if;end;
 assert (select count(*) from public.artifacts)=na and (select count(*) from public.artifact_versions)=nv,'failed creation no rows';
end $$;
set local role authenticated;
-- Same/foreign Project/Workspace/Activity IDs, nonexistent IDs and blank title.
select pg_temp.deny_create('00000000-0000-4000-8000-000000999999',(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'));
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),'00000000-0000-4000-8000-000000999999');
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'));
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),(select id from instances where label='Team'));
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),(select id from instances where label='Individual'));
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'00000000-0000-4000-8000-000000999999');
do $$begin
 begin perform public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'CUSTOM'::public.artifact_type,'Bad',null,false,false);raise exception 'invalid type accepted';exception when invalid_text_representation then null;end;
 begin perform public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'PITCH_DECK_RECORD',' ',null,false,false);raise exception 'blank title accepted';exception when invalid_parameter_value then null;end;
end $$;
reset role;
-- Exact Team B active/completed provenance is never usable in Team A.
insert into public.development_projects(id,name,project_type,owner_team_id,primary_workspace_id)
select '00000000-0000-4000-8000-000000825001','Team B provenance fixture','team',(payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid from acceptance_teams where label='B';
insert into public.project_program_links(project_id,program_id,cohort_id) select '00000000-0000-4000-8000-000000825001','00000000-0000-4000-8000-000000000601',id from acceptance_cohorts where label='Test';
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status)
select '00000000-0000-4000-8000-000000825002','00000000-0000-4000-8000-000000000801',c.id,'00000000-0000-4000-8000-000000825001',(t.payload->>'workspaceId')::uuid,(t.payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006006',now(),'active' from acceptance_teams t cross join acceptance_cohorts c where t.label='B' and c.label='Test';
set local role authenticated;
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),'00000000-0000-4000-8000-000000825002');
-- Team's own ACTIVE provenance is allowed before its later completion.
insert into created_artifacts select 'Active Team provenance',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PITCH_DECK_RECORD','Active Team',(select id from instances where label='Team'),false,false) from logged_projects where label='Team';
reset role;
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id='00000000-0000-4000-8000-000000825002';
set local role authenticated;
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),'00000000-0000-4000-8000-000000825002');
reset role;

-- All disallowed statuses tested using trusted, reversible fixture transitions.
do $$declare s public.activity_instance_status;begin
 foreach s in array array['submitted','under_review','revision_requested']::public.activity_instance_status[] loop
 update public.activity_instances set status=s where id=(select id from instances where label='Individual');
 set local role authenticated;
 perform pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),(select id from instances where label='Individual'));
 reset role;
 end loop;
 update public.activity_instances set status='active' where id=(select id from instances where label='Individual');
end $$;
-- not_started fixture cannot borrow historical started timestamps.
do $$declare ni uuid;begin
 begin
 update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from instances where label='Individual');
 insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,status)
 select activity_definition_id,cohort_id,project_id,workspace_id,'not_started' from public.activity_instances where id=(select id from instances where label='Individual') returning id into ni;
 set local role authenticated;
 perform pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),ni);
 reset role;
 raise exception using errcode='P0002';
 exception when no_data_found then null;end;
end $$;
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id in (select id from instances where label in ('Individual','Team'));
create temporary table completed_before as select jsonb_agg(to_jsonb(i) order by id) data from public.activity_instances i;
set local role authenticated;
insert into created_artifacts select 'Completed provenance',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PITCH_DECK_RECORD','Completed provenance',(select id from instances where label='Individual'),false,false) from logged_projects where label='Individual';
insert into created_artifacts select 'Completed Team provenance',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PITCH_DECK_RECORD','Completed Team',(select id from instances where label='Team'),false,false) from logged_projects where label='Team';
-- Foreign completed provenance remains denied.
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),(select id from instances where label='Team'));
reset role;
do $$begin assert (select data from completed_before)=(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i),'completed provenance never reopens or rewrites execution';end $$;
do $$begin
 begin
 update public.activity_instances set status='archived' where id=(select id from instances where label='Individual');
 set local role authenticated;
 perform pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),(select id from instances where label='Individual'));
 reset role;raise exception using errcode='P0002';exception when no_data_found then null;end;
end $$;
-- Forced failure after Artifact insert must roll back the entire RPC.
create function pg_temp.fail_v1() returns trigger language plpgsql as $$begin raise exception 'Injected V1 failure' using errcode='23514';end$$;
create trigger m84_fail_v1 before insert on public.artifact_versions for each row execute function pg_temp.fail_v1();
set local role authenticated;
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),null,'23514');
reset role;drop trigger m84_fail_v1 on public.artifact_versions;
-- Browser mutation/creator/number/pointer spoofing remains impossible.
set local role authenticated;
do $$declare a uuid;v uuid;begin
 select (payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid into a,v from created_artifacts where label='Personal';
 begin insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by) select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PITCH_DECK_RECORD','Spoof','00000000-0000-4000-8000-000000006001' from logged_projects where label='Individual';raise exception 'direct Artifact insert accepted';exception when insufficient_privilege then null;end;
 begin insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by) values(a,99,'{}','CURRENT','00000000-0000-4000-8000-000000006001');raise exception 'direct Version insert accepted';exception when insufficient_privilege then null;end;
 begin update public.artifacts set current_version_id=v where id=a;raise exception 'Draft current pointer accepted';exception when insufficient_privilege then null;end;
end $$;
-- Privacy: other Student, Team B, Master, Mentor and Admin product roles.
do $$declare u integer;begin
 foreach u in array array[6005,6006,6007,6002,6003,6008,6001] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
 perform pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),(select id from instances where label='Individual'));
 end loop;
 foreach u in array array[6006,6007,6003,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
 perform pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'));
 end loop;
end $$;
-- A fake role/user ID in claims never changes verified actor.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select set_config('request.jwt.claims','{"user_metadata":{"role":"ADMIN","userId":"00000000-0000-4000-8000-000000006004"}}',true);
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'));
select set_config('request.jwt.claims','{}',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),(select id from instances where label='Team'));
reset role;
-- A trusted new ACTIVE Team A fixture preserves the completed row; removed
-- historical participation still cannot authorize creating from either state.
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status)
select '00000000-0000-4000-8000-000000825003',activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,'active' from public.activity_instances where id=(select id from instances where label='Team');
set local role authenticated;
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),'00000000-0000-4000-8000-000000825003');
reset role;

-- Removed member + active provenance also fails; preserve completed timestamp.
-- Use the still-active Case instance as an inaccessible active-context regression.
set local role authenticated;
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Case'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Case'),(select id from instances where label='Case'));
select set_config('request.jwt.claim.sub','',true);
select pg_temp.deny_create((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),null,'28000');
reset role;
set local role anon;
do $$begin begin perform public.create_artifact('00000000-0000-4000-8000-000000999999','00000000-0000-4000-8000-000000999998','PITCH_DECK_RECORD','Anon',null,false,false);raise exception 'anonymous RPC allowed';exception when insufficient_privilege then null;end;end $$;
reset role;
\echo M8.4 atomic V1/current-null/active-completed provenance/privacy/rollback/security PASS
rollback;
