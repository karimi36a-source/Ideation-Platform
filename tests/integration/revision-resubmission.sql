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
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into review_fixtures select 'Team',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team')) from submitted_fixtures where label='Team';
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Team'));
select public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),'COMMENT','Original review');
select public.request_revision((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'Revise Personal');
select public.request_revision((select (payload->>'id')::uuid from review_fixtures where label='Team'),'Revise Team');
reset role;
create temporary table cycle_before as select
 (select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x) artifacts,
 (select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x) versions,
 (select jsonb_agg(to_jsonb(x) order by id) from public.submissions x) submissions,
 (select jsonb_agg(to_jsonb(x) order by id) from public.feedback_items x) feedback,
 (select jsonb_agg(to_jsonb(x) order by id) from public.review_actions x) actions,
 (select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x) activities,
 (select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x) objects,
 (select jsonb_agg(to_jsonb(x) order by id) from public.audit_events x) audit;
create temporary table revised(label text primary key,payload jsonb);grant select,insert on revised to authenticated;
-- Failure after Version insertion still rolls back the complete Draft operation.
create function pg_temp.fail_cycle() returns trigger language plpgsql as $$begin raise exception 'Injected' using errcode='P0002';end$$;
create trigger cycle_failure after insert on public.artifact_versions for each row execute function pg_temp.fail_cycle();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.create_revision_draft((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'{}','Change');raise exception 'Rollback injection bypass';exception when no_data_found then null;end;end$$;
reset role;
drop trigger cycle_failure on public.artifact_versions;
do $$begin if (select versions from cycle_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x) then raise exception 'Partial Draft';end if;end$$;
set local role authenticated;
do $$declare n integer;begin foreach n in array array[6001,6002,6003,6005,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.create_revision_draft((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'{}','Denied');raise exception 'Foreign Personal revision';exception when insufficient_privilege then null;end;
end loop;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into revised select 'Personal',public.create_revision_draft((payload->>'id')::uuid,'{"revised":"Personal"}','Personal change') from review_fixtures where label='Personal';
-- Ordinary Team editor may prepare content; only Lead can submit.
insert into revised select 'Team',public.create_revision_draft((payload->>'id')::uuid,'{"revised":"Team"}','Team change') from review_fixtures where label='Team';
do $$begin
 begin perform public.create_revision_draft((select (payload->>'id')::uuid from review_fixtures where label='Team'),'{}','Competing');raise exception 'Duplicate formal child';exception when invalid_parameter_value then null;end;
 begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),(select (payload->>'id')::uuid from revised where label='Team'),(select id from instances where label='Team'));raise exception 'Ordinary member submitted';exception when insufficient_privilege then null;end;
end$$;
reset role;
do $$begin
 if exists(select 1 from revised r join review_fixtures s using(label) where (r.payload->>'previous_version_id')::uuid<>(s.payload->>'artifact_version_id')::uuid or r.payload->>'status'<>'DRAFT' or (r.payload->>'version_number')::int<>2 or r.payload->>'approved_by' is not null or r.payload->>'version_label' is not null) then raise exception 'Draft lineage/state';end if;
 if exists(select 1 from public.artifact_object_links where artifact_version_id in(select (payload->>'id')::uuid from revised)) then raise exception 'Implicit link copy';end if;
end$$;
-- Explicit trusted link to the SAME canonical Object, no clone.
insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id)
select (r.payload->>'artifact_id')::uuid,(r.payload->>'id')::uuid,(o.payload->>'id')::uuid from revised r join logged_objects o on o.label='Problem' where r.label='Personal';
-- A second same-scope Activity is valid generally but cannot replace this cycle's Activity.
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot,completed_at)
select activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,'completed',configuration_snapshot,clock_timestamp() from public.activity_instances where id=(select id from instances where label='Individual');
create temporary table alternate_activity as select id from public.activity_instances where project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual') and id<>(select id from instances where label='Individual');grant select on alternate_activity to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'id')::uuid from revised where label='Personal'),(select id from alternate_activity));raise exception 'Activity switching accepted';exception when invalid_parameter_value then null;end;end$$;
reset role;
-- S2 insertion failure rolls back the earlier V2 status update.
create trigger cycle_failure after insert on public.submissions for each row execute function pg_temp.fail_cycle();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'id')::uuid from revised where label='Personal'),(select id from instances where label='Individual'));raise exception 'Submit rollback bypass';exception when no_data_found then null;end;end$$;
reset role;
drop trigger cycle_failure on public.submissions;
do $$begin if exists(select 1 from public.artifact_versions where id in(select (payload->>'id')::uuid from revised) and status<>'DRAFT') or (select count(*) from public.submissions)<>2 then raise exception 'Partial resubmission';end if;end$$;
-- Re-resolve reviewer from current Primary Master; preserve historical S1 M1.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.assign_master_to_cohort((select id from acceptance_cohorts where label='Test'),'00000000-0000-4000-8000-000000006003');
create temporary table resubmitted(label text primary key,payload jsonb);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into resubmitted select 'Personal',public.submit_artifact((payload->>'artifact_id')::uuid,(payload->>'id')::uuid,(select id from instances where label='Individual')) from revised where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into resubmitted select 'Team',public.submit_artifact((payload->>'artifact_id')::uuid,(payload->>'id')::uuid,(select id from instances where label='Team')) from revised where label='Team';
reset role;
do $$begin
 if exists(select 1 from resubmitted n join review_fixtures old using(label) join revised r using(label) where n.payload->>'id'=old.payload->>'id' or n.payload->>'artifact_version_id'<>r.payload->>'id' or n.payload->>'activity_instance_id'<>old.payload->>'activity_instance_id' or n.payload->>'reviewer_user_id'<>'00000000-0000-4000-8000-000000006003' or n.payload->>'status'<>'SUBMITTED') then raise exception 'New cycle mismatch';end if;
 if (select submissions from cycle_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.submissions x where id in(select (payload->>'id')::uuid from review_fixtures))
 or (select versions from cycle_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x where id not in(select (payload->>'id')::uuid from revised))
 or (select artifacts from cycle_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x)
 or (select feedback from cycle_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.feedback_items x)
 or (select actions from cycle_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.review_actions x)
 or (select objects from cycle_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x)
 or (select activities from cycle_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x where id not in(select id from alternate_activity)) then raise exception 'Historical mutation';end if;
 if exists(select 1 from public.review_actions where submission_id in(select (payload->>'id')::uuid from resubmitted)) then raise exception 'Premature S2 review';end if;
end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 if (select count(*) from public.artifact_versions where artifact_id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'))<>2 then raise exception 'History retrieval';end if;
 begin update public.submissions set artifact_version_id=(select (payload->>'id')::uuid from revised where label='Personal');raise exception 'Retarget S1';exception when insufficient_privilege then null;end;
 begin update public.artifact_versions set status='DRAFT',content_snapshot='{}';raise exception 'Rewrite V1';exception when insufficient_privilege then null;end;
 begin delete from public.submissions;raise exception 'Delete history';exception when insufficient_privilege then null;end;
 begin update public.feedback_items set target_version_id=(select (payload->>'id')::uuid from revised where label='Personal');raise exception 'Retarget feedback';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
do $$begin
 if not exists(select 1 from public.artifact_versions where id=(select (payload->>'id')::uuid from revised where label='Personal')) then raise exception 'S2 reviewer denied';end if;
 if exists(select 1 from public.artifact_versions where id=(select (payload->>'artifact_version_id')::uuid from review_fixtures where label='Personal')) then raise exception 'S2 exposed V1';end if;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin if exists(select 1 from public.artifact_versions where artifact_id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal')) then raise exception 'Old reviewer retained access';end if;end$$;
reset role;
set local role anon;
do $$begin begin perform public.create_revision_draft(gen_random_uuid(),'{}',null);raise exception 'Anonymous revision';exception when insufficient_privilege then null;end;end$$;
reset role;

-- Current baseline stays fixed across a full additional revision cycle.
do $$declare a jsonb;v2 jsonb;v3 jsonb;s1 jsonb;s2 jsonb;baseline jsonb;oldversion jsonb;begin
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 a:=public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'PITCH_DECK_RECORD','Current pointer regression',(select id from instances where label='Individual'),false,false);
 update public.artifact_versions set status='CURRENT',approved_by='00000000-0000-4000-8000-000000006003',approved_at=clock_timestamp() where id=(a->>'initialVersionId')::uuid;
 update public.artifacts set current_version_id=(a->>'initialVersionId')::uuid where id=(a->>'artifactId')::uuid;
 select to_jsonb(x) into baseline from public.artifacts x where id=(a->>'artifactId')::uuid;
 select to_jsonb(x) into oldversion from public.artifact_versions x where id=(a->>'initialVersionId')::uuid;
 v2:=public.create_artifact_version((a->>'artifactId')::uuid,'{"source":true}',null);
 s1:=public.submit_artifact((a->>'artifactId')::uuid,(v2->>'id')::uuid,(select id from instances where label='Individual'));
 -- Formal source must not be SUBMITTED/UNDER_REVIEW.
 begin perform public.create_revision_draft((s1->>'id')::uuid,'{}',null);raise exception 'Submitted revision accepted';exception when invalid_parameter_value then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
 perform public.start_review((s1->>'id')::uuid);
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 begin perform public.create_revision_draft((s1->>'id')::uuid,'{}',null);raise exception 'Under-review revision accepted';exception when invalid_parameter_value then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
 perform public.request_revision((s1->>'id')::uuid,'Revise pointer fixture');
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 -- A generic later Version causes safe formal conflict and remains generic.
 begin
 perform public.create_artifact_version((a->>'artifactId')::uuid,'{"generic":true}',null);
 begin perform public.create_revision_draft((s1->>'id')::uuid,'{}',null);raise exception 'Latest source bypass';exception when invalid_parameter_value then null;end;
 raise exception 'Undo generic fixture' using errcode='P0002';exception when no_data_found then null;end;
 -- Archive denies creation without restoring any production record.
 begin
 perform public.archive_artifact((a->>'artifactId')::uuid);
 begin perform public.create_revision_draft((s1->>'id')::uuid,'{}',null);raise exception 'Archived revision bypass';exception when insufficient_privilege then null;end;
 raise exception 'Undo archive fixture' using errcode='P0002';exception when no_data_found then null;end;
 v3:=public.create_revision_draft((s1->>'id')::uuid,'{"revised":true}','New snapshot');
 s2:=public.submit_artifact((a->>'artifactId')::uuid,(v3->>'id')::uuid,(select id from instances where label='Individual'));
 if v3->>'previous_version_id'<>v2->>'id' or (v3->>'version_number')::int<>3 or s2->>'id'=s1->>'id'
 or baseline is distinct from (select to_jsonb(x) from public.artifacts x where id=(a->>'artifactId')::uuid)
 or oldversion is distinct from (select to_jsonb(x) from public.artifact_versions x where id=(a->>'initialVersionId')::uuid) then raise exception 'Current baseline/lineage changed';end if;
end$$;
set local role authenticated;
do $$declare n integer;begin foreach n in array array[6001,6002,6003,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.create_revision_draft((select (payload->>'id')::uuid from review_fixtures where label='Team'),'{}','Denied');raise exception 'Foreign Team revision';exception when insufficient_privilege then null;end;
 begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),(select (payload->>'id')::uuid from revised where label='Team'),(select id from instances where label='Team'));raise exception 'Foreign Team submit';exception when insufficient_privilege then null;end;
end loop;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.create_revision_draft((select (payload->>'id')::uuid from review_fixtures where label='Team'),'{}','Removed');raise exception 'Removed revision';exception when insufficient_privilege then null;end;
 if exists(select 1 from public.artifact_versions where id=(select (payload->>'id')::uuid from revised where label='Team')) then raise exception 'Removed Version read';end if;
end$$;
reset role;

select 'M8.10 AT-REV-003 / AT-VER-002 lineage/history/reviewer/rollback/privacy PASS';
rollback;
