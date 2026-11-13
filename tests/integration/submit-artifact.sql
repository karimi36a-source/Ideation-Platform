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

insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team';
create temporary table submitted_fixtures(label text primary key,payload jsonb);grant select,insert on submitted_fixtures to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into submitted_fixtures select 'Personal',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','Submission fixture',(select id from instances where label='Individual'),false,false) from logged_projects where label='Individual';
insert into submitted_fixtures select 'Sibling',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','Private sibling',null,false,false) from logged_projects where label='Individual';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into submitted_fixtures select 'Team',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','Team submission',(select id from instances where label='Team'),true,true) from logged_projects where label='Team';
reset role;
insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id)
select (f.payload->>'artifactId')::uuid,(f.payload->>'initialVersionId')::uuid,(o.payload->>'id')::uuid from submitted_fixtures f join logged_objects o on o.label='Problem' where f.label='Personal';
create temporary table submission_before as select
(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i) activities,
(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l) links,
(select jsonb_agg(to_jsonb(v)-'status' order by id) from public.artifact_versions v) versions;
create function pg_temp.attempt_submit(label text,allowed boolean) returns void language plpgsql as $$
declare f jsonb;activity uuid;row jsonb;begin
select payload into f from submitted_fixtures where submitted_fixtures.label=attempt_submit.label;
select id into activity from instances where instances.label=case when attempt_submit.label='Team' then 'Team' else 'Individual' end;
begin row:=public.submit_artifact((f->>'artifactId')::uuid,(f->>'initialVersionId')::uuid,activity);assert allowed,'Unauthorized submission';assert row->>'submitted_by'=auth.uid()::text;assert row->>'reviewer_user_id'='00000000-0000-4000-8000-000000006002';assert row->>'status'='SUBMITTED';exception when insufficient_privilege then assert not allowed,'Valid submission denied';end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert public.get_submitted_artifact_metadata((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal')) is null;assert not exists(select 1 from public.artifact_versions);end $$;
-- All forbidden actors fail before any Submission exists.
do $$declare u integer;begin foreach u in array array[6001,6002,6003,6006,6007,6008] loop
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);perform pg_temp.attempt_submit('Personal',false);perform pg_temp.attempt_submit('Team',false);end loop;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);perform pg_temp.attempt_submit('Team',false);
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);perform pg_temp.attempt_submit('Personal',false);end $$;
reset role;
-- Force an INSERT failure after the real Version transition; no entitlement survives.
create function pg_temp.fail_submission() returns trigger language plpgsql as $$begin raise exception 'Forced rollback' using errcode='23514';end$$;
create trigger submission_failure before insert on public.submissions for each row execute function pg_temp.fail_submission();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform pg_temp.attempt_submit('Personal',true);raise exception 'Rollback failed';exception when check_violation then null;end;end $$;
reset role;drop trigger submission_failure on public.submissions;
do $$begin assert not exists(select 1 from public.submissions);assert not exists(select 1 from public.artifact_versions where status<>'DRAFT' and artifact_id in (select (payload->>'artifactId')::uuid from submitted_fixtures));end $$;

reset role;
do $$declare state public.artifact_version_status;aid uuid;vid uuid;activity uuid;begin
select id into activity from instances where label='Individual';
foreach state in array array['SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED','APPROVED','CURRENT','SUPERSEDED','ARCHIVED']::public.artifact_version_status[] loop
insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by)
select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','State fixture','00000000-0000-4000-8000-000000006004' from logged_projects where label='Individual' returning id into aid;
insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by,approved_by,approved_at)
values(aid,1,'{}',state,'00000000-0000-4000-8000-000000006004',case when state in ('APPROVED','CURRENT') then '00000000-0000-4000-8000-000000006002'::uuid end,case when state in ('APPROVED','CURRENT') then now() end) returning id into vid;
set local role authenticated;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
begin perform public.submit_artifact(aid,vid,activity);raise exception 'Non-Draft submission bypass';exception when unique_violation then null;end;
reset role;
end loop;
end$$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Sibling'),(select id from instances where label='Individual'));raise exception 'Foreign Version pair';exception when insufficient_privilege then null;end;
begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),(select id from instances where label='Team'));raise exception 'Foreign Activity';exception when insufficient_privilege then null;end;
end$$;
reset role;
-- Reviewer validity fails closed without picking another Master.
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select pg_temp.attempt_submit('Personal',false);
reset role;update public.role_assignments set status='active' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select pg_temp.attempt_submit('Personal',true);
do $$begin begin perform pg_temp.attempt_submit('Personal',true);raise exception 'Duplicate bypass';exception when unique_violation then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);select pg_temp.attempt_submit('Team',true);
reset role;
do $$begin assert (select count(*) from public.submissions)=2;assert (select count(*) from public.artifact_versions where status='SUBMITTED' and artifact_id in (select (payload->>'artifactId')::uuid from submitted_fixtures))=2;
assert (select artifacts from submission_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a where id in (select (payload->>'artifactId')::uuid from submitted_fixtures));
assert (select activities from submission_before)=(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i);
assert (select objects from submission_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
assert (select links from submission_before)=(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l);
assert (select versions from submission_before)=(select jsonb_agg(to_jsonb(v)-'status' order by id) from public.artifact_versions v where artifact_id in (select (payload->>'artifactId')::uuid from submitted_fixtures));end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.create_artifact_version((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),'{}','Future private Draft');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
assert (select count(*) from public.submissions)=2;
assert public.get_submitted_artifact_metadata((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'))->>'title'='Submission fixture';
assert public.get_submitted_artifact_metadata((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Sibling')) is null;
assert (select count(*) from public.artifact_versions)=2,'Only submitted exact Versions visible';
assert (select count(*) from public.artifact_object_links)=1;
assert (select count(*) from public.development_objects where project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual'))=1,'Only exact linked Personal Object';
assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from logged_objects where label='Solution')); 
assert not exists(select 1 from public.workspaces where workspace_type='PERSONAL');
assert not exists(select 1 from public.development_projects where project_type='individual');
assert not exists(select 1 from public.development_object_relationships);
end $$;
-- Revocation removes entitlement immediately, while preserving attribution.
reset role;update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert not exists(select 1 from public.submissions);assert not exists(select 1 from public.artifact_versions);assert not exists(select 1 from public.development_objects);end$$;
reset role;do $$begin assert (select count(*) from public.submissions)=2;end $$;
-- Ordinary direct mutation is never enabled, including forging reviewer or actor.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
begin update public.submissions set reviewer_user_id=auth.uid();raise exception 'Direct mutation';exception when insufficient_privilege then null;end;
begin delete from public.submissions;raise exception 'Direct delete';exception when insufficient_privilege then null;end;
begin insert into public.submissions default values;raise exception 'Direct insert';exception when insufficient_privilege then null;end;
begin update public.artifact_versions set status='DRAFT';raise exception 'Version reset';exception when insufficient_privilege then null;end;
end$$;

reset role;
-- Full Activity-state rejection matrix; trusted fixtures only, no lifecycle API.
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from instances where label='Individual');
do $$declare state public.activity_instance_status;activity uuid;f jsonb;begin
select payload into f from submitted_fixtures where label='Sibling';
foreach state in array array['not_started','submitted','under_review','revision_requested','archived']::public.activity_instance_status[] loop
begin
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status)
select activity_definition_id,cohort_id,project_id,workspace_id,team_id,
case when state='not_started' then null else started_by end,case when state='not_started' then null else started_at end,state from public.activity_instances where id=(select id from instances where label='Individual') returning id into activity;
set local role authenticated;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
begin perform public.submit_artifact((f->>'artifactId')::uuid,(f->>'initialVersionId')::uuid,activity);raise exception 'Invalid Activity state';exception when insufficient_privilege then null;end;
reset role;raise exception 'Fixture subtransaction complete' using errcode='P0002';exception when no_data_found then reset role;end;end loop;end$$;
-- Future/expired reviewer roles must also deny without mutating the Draft.
update public.role_assignments set status='active',starts_at=now()+interval '1 day',ends_at=null where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select pg_temp.attempt_submit('Sibling',false);
reset role;update public.role_assignments set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select pg_temp.attempt_submit('Sibling',false);
reset role;update public.role_assignments set starts_at=now()-interval '2 days',ends_at=null where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
-- Completed Activity provenance is allowed; V1 CURRENT remains pointed to after V2 submission.
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from instances where label='Individual') and status='active';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table pointer_draft as select public.create_artifact_version((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Sibling'),'{}','Submitted V2') payload;
reset role;
update public.artifact_versions set status='CURRENT',approved_by='00000000-0000-4000-8000-000000006002',approved_at=now() where id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Sibling');
update public.artifacts set current_version_id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Sibling') where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Sibling');
grant select on pointer_draft to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Sibling'),(select (payload->>'id')::uuid from pointer_draft),(select id from instances where label='Individual'));
reset role;
do $$begin assert (select current_version_id from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Sibling'))=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Sibling');
assert (select status from public.activity_instances where id=(select id from instances where label='Individual'))='completed';end$$;
-- Removed Lead cannot use old exact Artifact/Version/Activity/Submission IDs.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.attempt_submit('Team',false);
do $$begin assert not exists(select 1 from public.submissions where artifact_id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'));assert not exists(select 1 from public.artifact_versions where artifact_id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'));end$$;
-- Unrelated Master and Team B cannot enumerate exact Submission targets.
do $$declare u integer;begin foreach u in array array[6003,6006,6007,6008] loop
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
assert not exists(select 1 from public.submissions);
assert public.get_submitted_artifact_metadata((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal')) is null;
end loop;end$$;
reset role;set local role anon;
do $$begin begin perform public.submit_artifact(null,null,null);raise exception 'Anonymous RPC';exception when insufficient_privilege then null;end;begin perform * from public.submissions;raise exception 'Anonymous rows';exception when insufficient_privilege then null;end;end$$;
reset role;

reset role;
do $$declare codes text[];begin
select array_agg(enumlabel order by enumsortorder) into codes from pg_enum where enumtypid='public.submission_status'::regtype;
assert codes=array['SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED','APPROVED','REJECTED'];
begin insert into public.submissions(activity_instance_id,artifact_id,artifact_version_id,submitted_by,reviewer_user_id) select activity_instance_id,artifact_id,artifact_version_id,submitted_by,reviewer_user_id from public.submissions limit 1;raise exception 'Partial uniqueness backstop';exception when unique_violation then null;end;
begin update public.artifact_versions set content_snapshot='{"tampered":true}' where id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal');raise exception 'Submitted content mutation';exception when check_violation then null;end;
assert not has_function_privilege('anon','public.submit_artifact(uuid,uuid,uuid)','EXECUTE');
assert not has_function_privilege('service_role','public.submit_artifact(uuid,uuid,uuid)','EXECUTE');
assert exists(select 1 from pg_proc where oid='public.submit_artifact(uuid,uuid,uuid)'::regprocedure and prosecdef and proconfig=array['search_path=""']);
assert to_regclass('public.project_baselines') is null and to_regclass('public.project_baselines') is null;
end$$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.assign_master_to_cohort((select id from acceptance_cohorts where label='Test'),'00000000-0000-4000-8000-000000006003');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert public.get_submitted_artifact_metadata((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal')) is null;assert not exists(select 1 from public.submissions);end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
do $$begin assert not exists(select 1 from public.submissions),'New primary does not silently inherit historical reviewer target';end$$;
reset role;do $$begin assert (select count(*) from public.submissions)=3;assert not exists(select 1 from public.submissions where reviewer_user_id<>'00000000-0000-4000-8000-000000006002');end$$;
rollback;
\echo M8.7 submission/rollback/reviewer-entitlement/privacy PASS
