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

create temporary table review_fixtures(label text primary key,payload jsonb);grant select,insert on review_fixtures to authenticated,anon;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into review_fixtures select 'Personal',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Individual')) from submitted_fixtures where label='Personal';
insert into review_fixtures select 'Future',public.create_artifact_version((payload->>'artifactId')::uuid,'{"future":true}','Future Draft') from submitted_fixtures where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into review_fixtures select 'Team',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team')) from submitted_fixtures where label='Team';
reset role;
create temporary table review_before as select
(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i) activities,
(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l) links,
(select jsonb_agg(to_jsonb(v)-'status' order by id) from public.artifact_versions v) versions;
create function pg_temp.start_denied(target uuid) returns void language plpgsql as $$begin
begin perform public.start_review(target);raise exception 'Unauthorized review';exception when insufficient_privilege then null;end;end$$;
create function pg_temp.feedback_denied(entity uuid,version uuid,kind public.feedback_target_type default 'ARTIFACT') returns void language plpgsql as $$begin
begin perform public.add_feedback(kind,entity,version,'COMMENT','Private feedback');raise exception 'Unauthorized feedback';exception when insufficient_privilege then null;end;end$$;
set local role authenticated;
do $$declare u integer;begin foreach u in array array[6001,6003,6004,6005,6006,6007,6008] loop
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
perform pg_temp.start_denied((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
perform pg_temp.start_denied((select (payload->>'id')::uuid from review_fixtures where label='Team'));
end loop;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.feedback_denied((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null);
reset role;

-- Archived targets, mismatched Version state and inconsistent retry fail closed.
reset role;
do $$begin
begin
update public.artifacts set status='ARCHIVED',archived_at=clock_timestamp() where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal');
set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
perform pg_temp.start_denied((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
reset role;raise exception 'Fixture rolled back' using errcode='P0002';exception when no_data_found then reset role;end;
begin
update public.artifact_versions set status='UNDER_REVIEW' where id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal');
set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
begin perform public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Personal'));raise exception 'Mismatched Version bypass';exception when invalid_parameter_value then null;end;
reset role;
update public.submissions set status='UNDER_REVIEW' where id=(select (payload->>'id')::uuid from review_fixtures where label='Personal');
set local role authenticated;
begin perform public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Personal'));raise exception 'Missing canonical action retry';exception when invalid_parameter_value then null;end;
reset role;raise exception 'Fixture rolled back' using errcode='P0002';exception when no_data_found then reset role;end;
end$$;
-- Failure after Submission update: Version and action remain untouched.
create function pg_temp.fail_version_review() returns trigger language plpgsql as $$begin if new.status='UNDER_REVIEW' then raise exception 'Forced Version failure' using errcode='23514';end if;return new;end$$;
create trigger fail_version_review before update on public.artifact_versions for each row execute function pg_temp.fail_version_review();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Personal'));raise exception 'Partial review';exception when check_violation then null;end;end$$;
reset role;drop trigger fail_version_review on public.artifact_versions;
do $$begin assert not exists(select 1 from public.submissions where status<>'SUBMITTED');assert not exists(select 1 from public.artifact_versions where status='UNDER_REVIEW');assert not exists(select 1 from public.review_actions);end$$;
-- Failure after Version update, before action: both transitions roll back.
create function pg_temp.fail_review_action() returns trigger language plpgsql as $$begin raise exception 'Forced action failure' using errcode='23514';end$$;
create trigger fail_review_action before insert on public.review_actions for each row execute function pg_temp.fail_review_action();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Personal'));raise exception 'Partial action';exception when check_violation then null;end;end$$;
reset role;drop trigger fail_review_action on public.review_actions;
do $$begin assert not exists(select 1 from public.submissions where status<>'SUBMITTED');assert not exists(select 1 from public.artifact_versions where status='UNDER_REVIEW');assert not exists(select 1 from public.review_actions);end$$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare first jsonb;retry jsonb;begin
first:=public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
retry:=public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
assert first=retry;assert first->>'status'='UNDER_REVIEW';assert (select count(*) from public.review_actions)=1;
end$$;
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Team'));
create temporary table written_feedback(label text,payload jsonb);grant select,insert on written_feedback to authenticated;
insert into written_feedback select 'Version',public.add_feedback('ARTIFACT',(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,'COMMENT',E' \t Version feedback \n ') from submitted_fixtures where label='Personal';
insert into written_feedback select 'Object',public.add_feedback('DEVELOPMENT_OBJECT',(payload->>'id')::uuid,(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),'CORRECTION','Canonical correction') from logged_objects where label='Problem';
insert into written_feedback select 'Artifact',public.add_feedback('ARTIFACT',(payload->>'artifactId')::uuid,null,'QUESTION','Artifact-level question') from submitted_fixtures where label='Personal';
insert into written_feedback select 'Team',public.add_feedback('ARTIFACT',(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,'WARNING','Team feedback') from submitted_fixtures where label='Team';
select pg_temp.feedback_denied((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Sibling'),null);
select pg_temp.feedback_denied((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'id')::uuid from review_fixtures where label='Future'));
select pg_temp.feedback_denied((select (payload->>'id')::uuid from logged_objects where label='Solution'),null,'DEVELOPMENT_OBJECT');
do $$begin
begin perform public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null,'REVISION_REQUEST','No future workflow');raise exception 'Revision bypass';exception when invalid_parameter_value then null;end;
begin perform public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null,'APPROVAL_NOTE','No approval');raise exception 'Approval bypass';exception when invalid_parameter_value then null;end;
begin perform public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null,'COMMENT',E'\t \n');raise exception 'Blank content';exception when invalid_parameter_value then null;end;
end$$;
reset role;
do $$begin assert (select count(*) from public.feedback_items)=4;assert (select count(*) from public.review_actions where action_type='COMMENTED')=4;
assert not exists(select 1 from public.review_actions where note is not null or reviewer_user_id<>'00000000-0000-4000-8000-000000006002');
assert not exists(select 1 from public.feedback_items where status<>'OPEN' or resolved_at is not null or author_user_id<>'00000000-0000-4000-8000-000000006002');
assert (select content from public.feedback_items where id=(select (payload->>'id')::uuid from written_feedback where label='Version'))='Version feedback';
assert (select artifacts from review_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
assert (select activities from review_before)=(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i);
assert (select objects from review_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
assert (select links from review_before)=(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l);
assert (select versions from review_before)=(select jsonb_agg(to_jsonb(v)-'status' order by id) from public.artifact_versions v);
end$$;
-- Failed COMMENTED insertion rolls back newly inserted Feedback too.
create trigger fail_review_action before insert on public.review_actions for each row execute function pg_temp.fail_review_action();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null,'SUGGESTION','Must roll back');raise exception 'Partial Feedback';exception when check_violation then null;end;end$$;
reset role;drop trigger fail_review_action on public.review_actions;
do $$begin assert (select count(*) from public.feedback_items)=4;assert (select count(*) from public.review_actions)=6;end$$;
-- Exact ambiguity policy: same Artifact and same Object across two active reviews.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into review_fixtures select 'Second',public.submit_artifact((payload->>'artifactId')::uuid,(select (payload->>'id')::uuid from review_fixtures where label='Future'),(select id from instances where label='Individual')) from submitted_fixtures where label='Personal';
reset role;
insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id)
select (payload->>'artifactId')::uuid,(select (payload->>'id')::uuid from review_fixtures where label='Future'),(select (payload->>'id')::uuid from logged_objects where label='Problem') from submitted_fixtures where label='Personal';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Second'));
do $$begin
begin perform public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null,'COMMENT','Ambiguous');raise exception 'Newest inferred';exception when invalid_parameter_value then null;end;
begin perform public.add_feedback('DEVELOPMENT_OBJECT',(select (payload->>'id')::uuid from logged_objects where label='Problem'),null,'COMMENT','Ambiguous Object');raise exception 'Object review inferred';exception when invalid_parameter_value then null;end;
end$$;
select public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),'SUGGESTION','Intentional identical comment');
select public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),'SUGGESTION','Intentional identical comment');
reset role;
do $$begin assert (select count(*) from public.feedback_items where content='Intentional identical comment')=2;
assert (select target_version_id from public.feedback_items where id=(select (payload->>'id')::uuid from written_feedback where label='Version'))=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal');
assert not exists(select 1 from public.feedback_items where target_version_id=(select (payload->>'id')::uuid from review_fixtures where label='Future'));
end$$;
-- Authorized owner/team reads, exact-ID isolation, and no normal client CRUD.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert (select count(*) from public.feedback_items)=6;assert (select count(*) from public.review_actions)=9;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert (select count(*) from public.feedback_items)=1;assert (select count(*) from public.review_actions)=2;
assert not exists(select 1 from public.feedback_items where id=(select (payload->>'id')::uuid from written_feedback where label='Version'));end$$;
do $$declare u integer;begin foreach u in array array[6001,6003,6006,6007,6008] loop
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
assert not exists(select 1 from public.feedback_items);assert not exists(select 1 from public.review_actions);
perform pg_temp.feedback_denied((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null);
end loop;end$$;
do $$begin
begin insert into public.feedback_items default values;raise exception 'Client Feedback insert';exception when insufficient_privilege then null;end;
begin update public.feedback_items set content='Forged',status='RESOLVED',resolved_at=now();raise exception 'Client edit/resolve';exception when insufficient_privilege then null;end;
begin delete from public.feedback_items;raise exception 'Client Feedback delete';exception when insufficient_privilege then null;end;
begin insert into public.review_actions default values;raise exception 'Client reviewer impersonation';exception when insufficient_privilege then null;end;
begin delete from public.review_actions;raise exception 'Client history delete';exception when insufficient_privilege then null;end;
begin update public.artifact_versions set status='UNDER_REVIEW';raise exception 'Client Version transition';exception when insufficient_privilege then null;end;
end$$;
reset role;
-- Removing a member revokes future Team feedback reads without rewriting authors.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not exists(select 1 from public.feedback_items);assert not exists(select 1 from public.review_actions);end$$;
reset role;
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.start_denied((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
select pg_temp.feedback_denied((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null);
do $$begin assert not exists(select 1 from public.feedback_items);assert not exists(select 1 from public.review_actions);assert not exists(select 1 from public.artifact_versions);end$$;

reset role;
-- Current scope validity is required after review has started as well.
update public.role_assignments set status='active',starts_at=now()+interval '1 day',ends_at=null where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.start_denied((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
select pg_temp.feedback_denied((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null);
reset role;
update public.role_assignments set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;
select pg_temp.start_denied((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
select pg_temp.feedback_denied((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),null);
reset role;set local role anon;
do $$begin
begin perform public.start_review(null);raise exception 'Anonymous review';exception when insufficient_privilege then null;end;
begin perform * from public.feedback_items;raise exception 'Anonymous Feedback';exception when insufficient_privilege then null;end;
begin perform * from public.review_actions;raise exception 'Anonymous history';exception when insufficient_privilege then null;end;
end$$;
reset role;
do $$begin assert (select count(*) from public.feedback_items)=6;assert (select count(*) from public.review_actions)=9;
begin update public.feedback_items set target_version_id=(select (payload->>'id')::uuid from review_fixtures where label='Future') where id=(select (payload->>'id')::uuid from written_feedback where label='Version');raise exception 'Feedback migrated';exception when check_violation then null;end;
begin delete from public.review_actions;raise exception 'History destroyed';exception when check_violation then null;end;
assert to_regprocedure('public.request_revision(uuid)') is null and to_regprocedure('public.resolve_feedback(uuid)') is null;
end$$;

reset role;
do $$declare labels text[];begin
select array_agg(enumlabel order by enumsortorder) into labels from pg_enum where enumtypid='public.feedback_type'::regtype;
assert labels=array['COMMENT','QUESTION','CORRECTION','SUGGESTION','REVISION_REQUEST','APPROVAL_NOTE','WARNING'];
select array_agg(enumlabel order by enumsortorder) into labels from pg_enum where enumtypid='public.review_action_type'::regtype;
assert labels=array['STARTED_REVIEW','COMMENTED','REQUESTED_REVISION','APPROVED','REOPENED','REJECTED'];
select array_agg(enumlabel order by enumsortorder) into labels from pg_enum where enumtypid='public.feedback_status'::regtype;assert labels=array['OPEN','RESOLVED'];
begin update public.feedback_items set resolved_at=now() where id=(select (payload->>'id')::uuid from written_feedback where label='Version');raise exception 'OPEN resolved timestamp';exception when check_violation then null;end;
begin update public.feedback_items set status='RESOLVED' where id=(select (payload->>'id')::uuid from written_feedback where label='Version');raise exception 'RESOLVED missing timestamp';exception when check_violation then null;end;
begin update public.review_actions set note='Rewritten';raise exception 'Append-only history';exception when check_violation then null;end;
assert not has_function_privilege('authenticated','public.lock_review_submission(uuid)','EXECUTE');
assert not has_function_privilege('anon','public.start_review(uuid)','EXECUTE');
assert not has_function_privilege('service_role','public.add_feedback(public.feedback_target_type,uuid,uuid,public.feedback_type,text)','EXECUTE');
assert exists(select 1 from pg_proc where oid='public.start_review(uuid)'::regprocedure and prosecdef and proconfig=array['search_path=""']);
assert exists(select 1 from pg_proc where oid='public.add_feedback(public.feedback_target_type,uuid,uuid,public.feedback_type,text)'::regprocedure and prosecdef and proconfig=array['search_path=""']);
end$$;

-- A second valid review belongs to another primary Master/Cohort. Knowing its
-- exact Feedback/Submission/Artifact IDs must not disclose it to the first Master.
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006006','participant','active' from acceptance_cohorts where label='Unrelated';
update public.role_assignments set status='active',starts_at=now()-interval '2 days',ends_at=null where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select public.create_personal_workspace();
insert into logged_projects values('Other Personal',public.create_development_project('Other reviewer fixture','individual',(select id from public.workspaces where workspace_type='PERSONAL')));
select public.link_project_to_program((select (payload->>'id')::uuid from logged_projects where label='Other Personal'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Unrelated'));
reset role;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,started_by,started_at,status)
select '00000000-0000-4000-8000-000000000801',(select id from acceptance_cohorts where label='Unrelated'),(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'00000000-0000-4000-8000-000000006006',now(),'active' from logged_projects where label='Other Personal';
insert into instances select 'Other Personal',id from public.activity_instances where project_id=(select (payload->>'id')::uuid from logged_projects where label='Other Personal');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
insert into submitted_fixtures select 'Other Personal',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','Other Personal review',(select id from instances where label='Other Personal'),true,true) from logged_projects where label='Other Personal';
insert into review_fixtures select 'Other Personal',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Other Personal')) from submitted_fixtures where label='Other Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Other Personal'));
insert into written_feedback select 'Other Personal',public.add_feedback('ARTIFACT',(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,'COMMENT','Other private review content') from submitted_fixtures where label='Other Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
assert exists(select 1 from public.feedback_items where id=(select (payload->>'id')::uuid from written_feedback where label='Version')),'First reviewer still authorized for own target';
assert not exists(select 1 from public.feedback_items where id=(select (payload->>'id')::uuid from written_feedback where label='Other Personal')),'Exact foreign Feedback ID denied';
assert not exists(select 1 from public.review_actions where submission_id=(select (payload->>'id')::uuid from review_fixtures where label='Other Personal'));
assert public.get_submitted_artifact_metadata((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Other Personal')) is null;
end$$;
select pg_temp.start_denied((select (payload->>'id')::uuid from review_fixtures where label='Other Personal'));
select pg_temp.start_denied('00000000-0000-4000-8000-000000999999');
select pg_temp.feedback_denied((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Other Personal'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Other Personal'));
reset role;
rollback;
\echo M8.8 review/feedback/ambiguity/privacy/history/rollback PASS
