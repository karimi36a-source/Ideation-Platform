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
do $$begin begin perform public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Personal'));raise exception 'Unreviewed approval';exception when invalid_parameter_value then null;end;end$$;
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Personal'));
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Team'));
select public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),'COMMENT','Keep this Feedback unchanged');
reset role;
create function pg_temp.approval_state() returns jsonb language sql as $$select jsonb_build_object(
 'artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),
 'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),
 'submissions',(select jsonb_agg(to_jsonb(x) order by id) from public.submissions x),
 'actions',(select jsonb_agg(to_jsonb(x) order by id) from public.review_actions x),
 'audit',(select jsonb_agg(to_jsonb(x) order by id) from public.audit_events x),
 'feedback',(select jsonb_agg(to_jsonb(x) order by id) from public.feedback_items x));$$;
create temporary table approval_before as select pg_temp.approval_state() data,
 (select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x) activities,
 (select jsonb_agg(to_jsonb(x) order by id) from public.artifact_object_links x) links,
 (select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x) objects;
create function pg_temp.fail_approval() returns trigger language plpgsql as $$begin raise exception 'Injected approval failure' using errcode='P0002';end$$;
-- All five AFTER-write boundaries, including after audit insertion.
do $$declare t text;sid uuid;before_state jsonb;begin
 select (payload->>'id')::uuid into sid from review_fixtures where label='Personal';
 before_state:=pg_temp.approval_state();
 foreach t in array array['artifact_versions','artifacts','submissions','review_actions','audit_events'] loop
 execute format('create trigger approval_failure after %s on public.%I for each row execute function pg_temp.fail_approval()',case when t in ('review_actions','audit_events') then 'insert' else 'update' end,t);
 begin perform public.approve_artifact(sid,'Approved note');raise exception 'Failure injection bypass';exception when no_data_found then null;end;
 execute format('drop trigger approval_failure on public.%I',t);
 if before_state is distinct from pg_temp.approval_state() then raise exception 'Partial first approval';end if;
 end loop;
end$$;
-- No actor role/title/ownership can replace the exact reviewer.
set local role authenticated;
do $$declare n integer;f record;begin foreach n in array array[6001,6003,6004,6005,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 for f in select payload from review_fixtures where label in ('Personal','Team') loop
 begin perform public.approve_artifact((f.payload->>'id')::uuid);raise exception 'Unauthorized approval';exception when insufficient_privilege then null;end;
 end loop;
end loop;end$$;
reset role;
-- Revoked/future/expired authority, archive and inconsistent pointer fail closed.
do $$declare scenario text;sid uuid;begin
 select (payload->>'id')::uuid into sid from review_fixtures where label='Personal';
 foreach scenario in array array['inactive','future','expired','archived','pointer','mismatch'] loop
 begin
 if scenario='inactive' then update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002';
 elsif scenario='future' then update public.role_assignments set starts_at=now()+interval '1 day' where user_id='00000000-0000-4000-8000-000000006002';
 elsif scenario='expired' then update public.role_assignments set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where user_id='00000000-0000-4000-8000-000000006002';
 elsif scenario='archived' then update public.artifacts set status='ARCHIVED',archived_at=clock_timestamp() where id=(select artifact_id from public.submissions where id=sid);
 elsif scenario='pointer' then update public.artifacts set current_version_id=(select artifact_version_id from public.submissions where id=sid) where id=(select artifact_id from public.submissions where id=sid);
 else update public.submissions set status='SUBMITTED' where id=sid;end if;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 begin perform public.approve_artifact(sid);raise exception 'Invalid approval accepted';exception when insufficient_privilege or invalid_parameter_value then null;end;
 raise exception 'Undo negative fixture' using errcode='P0002';exception when no_data_found then null;end;
 end loop;
end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'  Approved note  ');
reset role;
create temporary table first_approval as select pg_temp.approval_state() data;
set local role authenticated;
select public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'Approved note');
do $$begin
 begin perform public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'Changed');raise exception 'Changed note retry';exception when invalid_parameter_value then null;end;
 begin perform public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Personal'),' ');raise exception 'Empty note accepted';exception when invalid_parameter_value then null;end;
 begin perform public.request_revision((select (payload->>'id')::uuid from review_fixtures where label='Personal'),'Too late');raise exception 'Contradictory terminal transition';exception when invalid_parameter_value then null;end;
end$$;
reset role;
do $$begin
 if (select data from first_approval) is distinct from pg_temp.approval_state() then raise exception 'Retry mutated approval';end if;
 if not exists(select 1 from public.artifact_versions v join public.artifacts a on a.current_version_id=v.id join public.submissions s on s.artifact_version_id=v.id where s.id=(select (payload->>'id')::uuid from review_fixtures where label='Personal') and v.status='CURRENT' and v.approved_by='00000000-0000-4000-8000-000000006002' and v.approved_at is not null and v.approval_note='Approved note' and s.status='APPROVED') then raise exception 'First approval state';end if;
 if (select count(*) from public.review_actions where action_type='APPROVED')<>1 or (select count(*) from public.audit_events where event_type='ARTIFACT_APPROVED' and metadata='{}'::jsonb)<>1 then raise exception 'First approval history';end if;
end$$;
-- Submit/review the existing second Draft; approved history stays unchanged.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into review_fixtures select 'Replacement',public.submit_artifact((payload->>'artifact_id')::uuid,(payload->>'id')::uuid,(select id from instances where label='Individual')) from review_fixtures where label='Future';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Replacement'));
reset role;
create temporary table prior_current as select to_jsonb(v) data from public.artifact_versions v where id=(select (payload->>'artifact_version_id')::uuid from review_fixtures where label='Personal');
-- Version failure fires immediately AFTER prior CURRENT -> SUPERSEDED.
-- Other failures prove restoration of both Version states and old pointer.
do $$declare t text;sid uuid;before_state jsonb;begin
 select (payload->>'id')::uuid into sid from review_fixtures where label='Replacement';before_state:=pg_temp.approval_state();
 foreach t in array array['artifact_versions','artifacts','submissions','review_actions','audit_events'] loop
 execute format('create trigger approval_failure after %s on public.%I for each row execute function pg_temp.fail_approval()',case when t in ('review_actions','audit_events') then 'insert' else 'update' end,t);
 begin perform public.approve_artifact(sid);raise exception 'Replacement injection bypass';exception when no_data_found then null;end;
 execute format('drop trigger approval_failure on public.%I',t);
 if before_state is distinct from pg_temp.approval_state() then raise exception 'Partial replacement approval';end if;
 end loop;
end$$;
set local role authenticated;
select public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Replacement'));
select public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Team'));
reset role;
do $$declare vid uuid;begin
 select (payload->>'artifact_version_id')::uuid into vid from review_fixtures where label='Personal';
 if (select data-'status' from prior_current) is distinct from (select to_jsonb(v)-'status' from public.artifact_versions v where id=vid)
 or (select status from public.artifact_versions where id=vid)<>'SUPERSEDED' then raise exception 'Prior CURRENT changed beyond status';end if;
 if exists(select 1 from public.artifact_versions where status='CURRENT' group by artifact_id having count(*)>1) then raise exception 'Multiple CURRENT';end if;
 if exists(select 1 from public.artifacts a join public.artifact_versions v on v.id=a.current_version_id where v.artifact_id<>a.id or v.status<>'CURRENT') then raise exception 'Pointer mismatch';end if;
 if (select data->'feedback' from approval_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.feedback_items x)
 or (select activities from approval_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x)
 or (select links from approval_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.artifact_object_links x)
 or (select objects from approval_before) is distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x) then raise exception 'Approval rewrote content/history';end if;
 begin insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by,approved_by,approved_at) select artifact_id,99,'{}','CURRENT',created_by,approved_by,approved_at from public.artifact_versions where status='CURRENT' limit 1;raise exception 'CURRENT uniqueness bypass';exception when unique_violation then null;end;
 begin update public.artifact_versions set content_snapshot='{"rewritten":true}' where id=vid;raise exception 'Historical content mutable';exception when check_violation then null;end;
end$$;
-- All normal-client approval writes remain denied at the database boundary.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare col text;begin
 foreach col in array array['content_snapshot','version_number','created_by','previous_version_id','approved_by','approved_at','approval_note','status'] loop
 begin execute format('update public.artifact_versions set %I=%I',col,col);raise exception 'Direct Version mutation';exception when insufficient_privilege then null;end;
 end loop;
 begin update public.artifacts set current_version_id=null;raise exception 'Direct pointer mutation';exception when insufficient_privilege then null;end;
 begin update public.submissions set status='APPROVED';raise exception 'Direct Submission approval';exception when insufficient_privilege then null;end;
 begin insert into public.review_actions(submission_id,reviewer_user_id,action_type) values(gen_random_uuid(),auth.uid(),'APPROVED');raise exception 'Fake action';exception when insufficient_privilege then null;end;
 begin insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id) values(auth.uid(),'ARTIFACT_APPROVED','submission',gen_random_uuid(),'submission',gen_random_uuid());raise exception 'Fake audit';exception when insufficient_privilege then null;end;
 begin delete from public.artifact_versions;raise exception 'Delete history';exception when insufficient_privilege then null;end;
end$$;
do $$declare n integer;begin foreach n in array array[6003,6006,6007] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 if exists(select 1 from public.submissions) or exists(select 1 from public.review_actions) or exists(select 1 from public.artifacts) or exists(select 1 from public.artifact_versions) then raise exception 'Foreign approved history leaked';end if;
 begin perform 1 from public.audit_events;raise exception 'Audit exposed';exception when insufficient_privilege then null;end;
end loop;end$$;
reset role;
-- Real Primary Master reassignment revokes former reviewer's exact retry.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.assign_master_to_cohort((select id from acceptance_cohorts where label='Test'),'00000000-0000-4000-8000-000000006003');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Replacement'));raise exception 'Former primary retry';exception when insufficient_privilege then null;end;end$$;
reset role;
set local role anon;
do $$begin begin perform public.approve_artifact(gen_random_uuid());raise exception 'Anonymous approval';exception when insufficient_privilege then null;end;end$$;
reset role;
select 'M8.11 AT-REV-004 core / AT-REV-005 / AT-TX-001 approval/history/privacy PASS';
rollback;
