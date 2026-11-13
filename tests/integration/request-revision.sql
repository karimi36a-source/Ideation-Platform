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

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Team'));
select public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),'COMMENT','Prior feedback preserved');
reset role;
-- Trusted historical CURRENT fixture; requestRevision must never retarget it.
insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by,approved_by,approved_at)
select (payload->>'artifactId')::uuid,3,'{"historical":true}','CURRENT','00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006002',clock_timestamp() from submitted_fixtures where label='Personal';
update public.artifacts set current_version_id=(select v.id from public.artifact_versions v where v.artifact_id=artifacts.id and v.status='CURRENT') where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal');
create temporary table revision_before as select
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(a) order by id) from public.activity_instances a) activities,
 (select jsonb_agg(to_jsonb(a) order by id) from public.development_objects a) objects,
 (select jsonb_agg(to_jsonb(a)-'status' order by id) from public.artifact_versions a) versions,
 (select jsonb_agg(to_jsonb(a)-'status' order by id) from public.submissions a) submissions,
 (select jsonb_agg(to_jsonb(a) order by id) from public.feedback_items a) feedback,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifact_object_links a) links;
-- Real database failures at each required transaction boundary.
create function pg_temp.fail_revision() returns trigger language plpgsql as $$begin raise exception 'Injected failure' using errcode='P0002';end$$;
do $$declare table_name text;sid uuid;begin
 select (payload->>'id')::uuid into sid from review_fixtures where label='Personal';
 foreach table_name in array array['artifact_versions','review_actions','feedback_items','audit_events'] loop
 execute format('create trigger revision_failure before %s on public.%I for each row execute function pg_temp.fail_revision()',case when table_name='artifact_versions' then 'update' else 'insert' end,table_name);
 begin
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 perform public.request_revision(sid,'Revise safely');raise exception 'Failure injection bypass';
 exception when no_data_found then null;end;
 execute format('drop trigger revision_failure on public.%I',table_name);
 if (select status from public.submissions where id=sid)<>'UNDER_REVIEW'
 or (select status from public.artifact_versions where id=(select artifact_version_id from public.submissions where id=sid))<>'UNDER_REVIEW'
 or exists(select 1 from public.review_actions where action_type='REQUESTED_REVISION')
 or exists(select 1 from public.feedback_items where feedback_type='REVISION_REQUEST')
 or exists(select 1 from public.audit_events where event_type='REVISION_REQUESTED') then raise exception 'Partial revision state';end if;
 end loop;
end$$;
-- Stored reviewer plus current exact scope, never a client/platform role claim.
set local role authenticated;
do $$declare actor text;sid uuid;begin
 select (payload->>'id')::uuid into sid from review_fixtures where label='Personal';
 foreach actor in array array['6001','6003','6004','6005','6006','6007','6008'] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000'||actor,true);
 begin perform public.request_revision(sid,'Denied');raise exception 'Unauthorized revision';exception when insufficient_privilege then null;end;
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.request_revision((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'  Revise safely  ');
select public.request_revision((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'Revise safely');
select public.request_revision((select (payload->>'id')::uuid from review_fixtures where label='Team'),'Team revision');
do $$begin
 begin perform public.request_revision((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'Changed retry');raise exception 'Changed retry accepted';exception when invalid_parameter_value then null;end;
 begin perform public.request_revision((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'   ');raise exception 'Empty accepted';exception when invalid_parameter_value then null;end;
end$$;
reset role;
do $$begin
 if (select count(*) from public.review_actions where action_type='REQUESTED_REVISION')<>2 or (select count(*) from public.feedback_items where feedback_type='REVISION_REQUEST')<>2 or (select count(*) from public.audit_events where event_type='REVISION_REQUESTED')<>2 then raise exception 'Revision duplicate/missing history';end if;
 if exists(select 1 from public.feedback_items f join public.submissions s on s.id=f.submission_id join public.artifacts a on a.id=s.artifact_id where f.feedback_type='REVISION_REQUEST' and (f.target_version_id<>s.artifact_version_id or f.target_entity_id<>a.id or f.project_id<>a.project_id or f.author_user_id<>s.reviewer_user_id or f.status<>'OPEN' or f.resolved_at is not null)) then raise exception 'Feedback context mismatch';end if;
 if exists(select 1 from public.audit_events where event_type='REVISION_REQUESTED' and (metadata<>'{}'::jsonb or actor_user_id<>'00000000-0000-4000-8000-000000006002')) then raise exception 'Audit private payload/actor mismatch';end if;
 if (select artifacts from revision_before) is distinct from (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a)
 or (select activities from revision_before) is distinct from (select jsonb_agg(to_jsonb(a) order by id) from public.activity_instances a)
 or (select objects from revision_before) is distinct from (select jsonb_agg(to_jsonb(a) order by id) from public.development_objects a)
 or (select versions from revision_before) is distinct from (select jsonb_agg(to_jsonb(a)-'status' order by id) from public.artifact_versions a)
 or (select submissions from revision_before) is distinct from (select jsonb_agg(to_jsonb(a)-'status' order by id) from public.submissions a) or (select feedback from revision_before) is distinct from (select jsonb_agg(to_jsonb(a) order by id) from public.feedback_items a where feedback_type<>'REVISION_REQUEST')
 or (select links from revision_before) is distinct from (select jsonb_agg(to_jsonb(a) order by id) from public.artifact_object_links a)
 then raise exception 'Protected history changed';end if;
end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 if (select count(*) from public.feedback_items where feedback_type='REVISION_REQUEST')<>2 then raise exception 'Submitter revision feedback missing';end if;
 begin update public.submissions set status='UNDER_REVIEW';raise exception 'Client transition';exception when insufficient_privilege then null;end;
 begin insert into public.review_actions(submission_id,reviewer_user_id,action_type) values(gen_random_uuid(),auth.uid(),'REQUESTED_REVISION');raise exception 'Client fake action';exception when insufficient_privilege then null;end;
 begin insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id) values(auth.uid(),'REVISION_REQUESTED','submission',gen_random_uuid(),'submission',gen_random_uuid());raise exception 'Client fake audit';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin if exists(select 1 from public.feedback_items) or exists(select 1 from public.review_actions) then raise exception 'Foreign Team leaked';end if;end$$;
reset role;
-- Actual Team removal revokes the new revision history without erasing it.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 if exists(select 1 from public.feedback_items where submission_id=(select (payload->>'id')::uuid from review_fixtures where label='Team'))
 or exists(select 1 from public.review_actions where submission_id=(select (payload->>'id')::uuid from review_fixtures where label='Team')) then raise exception 'Removed member revision leakage';end if;
 if not exists(select 1 from public.feedback_items where submission_id=(select (payload->>'id')::uuid from review_fixtures where label='Personal')) then raise exception 'Personal revision access affected';end if;
end$$;
reset role;
do $$declare sid uuid;begin
 select (payload->>'id')::uuid into sid from review_fixtures where label='Personal';
 -- A corrupt trusted duplicate must not be accepted as an idempotent retry.
 begin
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id) values('00000000-0000-4000-8000-000000006002','REVISION_REQUESTED','submission',sid,'submission',sid);
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 begin perform public.request_revision(sid,'Revise safely');raise exception 'Inconsistent retry accepted';exception when invalid_parameter_value then null;end;
 raise exception 'Undo trusted fixture' using errcode='P0002';
 exception when no_data_found then null;end;
 begin insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id) values('00000000-0000-4000-8000-000000006002','REVISION_REQUESTED','submission',gen_random_uuid(),'submission',gen_random_uuid());raise exception 'Invalid audit target';exception when check_violation or foreign_key_violation then null;end;
 begin insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata) values('00000000-0000-4000-8000-000000006002','REVISION_REQUESTED','submission',sid,'submission',sid,'{"note":"Must not copy"}');raise exception 'Private audit payload';exception when check_violation then null;end;
end$$;
update public.role_assignments set status='inactive'  where user_id='00000000-0000-4000-8000-000000006002';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 if exists(select 1 from public.feedback_items) then raise exception 'Revoked reviewer read';end if;
 begin perform public.request_revision((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'Revise safely');raise exception 'Revoked retry';exception when insufficient_privilege then null;end;
end$$;
reset role;
set local role anon;
do $$begin begin perform public.request_revision(gen_random_uuid(),'Denied');raise exception 'Anonymous revision';exception when insufficient_privilege then null;end;end$$;
reset role;
select 'M8.9 revision/feedback/audit/retry/rollback/privacy PASS';
rollback;

