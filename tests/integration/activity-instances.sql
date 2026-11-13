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
-- A completed historical execution may coexist with a new unstarted execution.
savepoint unstarted_fixture;
update public.activity_instances set status='completed',completed_at=now() where id=(select id from instances where label='Individual');
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id)
 select activity_definition_id,cohort_id,project_id,workspace_id from public.activity_instances where id=(select id from instances where label='Individual');
do $$begin
 assert exists(select 1 from public.activity_instances where status='not_started' and started_by is null and started_at is null and completed_at is null);
 begin update public.activity_instances set status='archived',started_by='00000000-0000-4000-8000-000000006004',started_at=now() where status='not_started';raise exception 'unstarted archive';exception when check_violation then null;end;
end $$;
rollback to unstarted_fixture;
create temporary table instance_baseline as select to_jsonb(i) data from public.activity_instances i where id=(select id from instances where label='Individual');
create function pg_temp.bad_instance(patch jsonb,expected text default '23514') returns void language plpgsql as $$declare s text;begin
 begin
 -- Isolate the attempted row from the existing execution so FK/shape errors
 -- remain independently tested rather than being masked by uniqueness.
 update public.activity_instances set status='completed',completed_at=now() where id=(select id from instances where label='Individual');
 insert into public.activity_instances select (jsonb_populate_record(null::public.activity_instances,(select data from instance_baseline)||patch||jsonb_build_object('id',gen_random_uuid()))).*;
 exception when others then get stacked diagnostics s=returned_sqlstate;end;
 assert s=expected,'bad instance expected '||expected||', got '||coalesce(s,'success')||' for '||patch::text;
end $$;
select pg_temp.bad_instance('{"activity_definition_id":"00000000-0000-4000-8000-000000009999"}','23503');
select pg_temp.bad_instance('{"cohort_id":"00000000-0000-4000-8000-000000009999"}','23503');
select pg_temp.bad_instance('{"project_id":"00000000-0000-4000-8000-000000009999"}','23503');
select pg_temp.bad_instance('{"workspace_id":"00000000-0000-4000-8000-000000009999"}','23503');
select pg_temp.bad_instance('{"started_by":"00000000-0000-4000-8000-000000009999"}','23503');
select pg_temp.bad_instance(jsonb_build_object('workspace_id',(select payload->>'workspaceId' from acceptance_teams where label='B')));
select pg_temp.bad_instance(jsonb_build_object('team_id',(select payload->>'teamId' from acceptance_teams where label='A')));
select pg_temp.bad_instance(jsonb_build_object('cohort_id',(select id from acceptance_cohorts where label='Unrelated')));
select pg_temp.bad_instance('{"status":"unsupported"}','22P02');
select pg_temp.bad_instance('{"started_by":null}');
select pg_temp.bad_instance('{"started_at":null}');
select pg_temp.bad_instance('{"completed_at":"2000-01-01T00:00:00Z","status":"completed"}');
select pg_temp.bad_instance('{"status":"completed","completed_at":null}');
select pg_temp.bad_instance(jsonb_build_object('completed_at',now()));
select pg_temp.bad_instance('{"status":"not_started"}');
select pg_temp.bad_instance('{"configuration_snapshot":[]}');
-- Same Program, different curriculum version must not substitute for exact matching.
insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000003602','00000000-0000-4000-8000-000000000601','M7.1 isolated draft','draft');
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence,status) values('00000000-0000-4000-8000-000000003702','00000000-0000-4000-8000-000000003602',1,'Isolated test session','Schema mismatch fixture only','Validate curriculum isolation',1,'active');
insert into public.activity_definitions(id,session_definition_id,name,method_type,sequence) values('00000000-0000-4000-8000-000000003801','00000000-0000-4000-8000-000000003702','Isolated test definition','custom',1);
select pg_temp.bad_instance('{"activity_definition_id":"00000000-0000-4000-8000-000000003801"}');
-- Team-specific mismatch attempts use the Team baseline, not Personal rows.
update instance_baseline set data=(select to_jsonb(i) from public.activity_instances i where id=(select id from instances where label='Team'));
select pg_temp.bad_instance('{"team_id":null}');
select pg_temp.bad_instance(jsonb_build_object('team_id',(select payload->>'teamId' from acceptance_teams where label='B')));
select pg_temp.bad_instance(jsonb_build_object('workspace_id',(select payload->>'workspaceId' from acceptance_teams where label='B')));
select pg_temp.bad_instance(jsonb_build_object('cohort_id',(select id from acceptance_cohorts where label='Unrelated')));
select pg_temp.bad_instance('{"team_id":"00000000-0000-4000-8000-000000009999"}');
update instance_baseline set data=(select to_jsonb(i) from public.activity_instances i where id=(select id from instances where label='Individual'));
do $$declare a public.activity_instances;begin
 for a in select * from public.activity_instances where status='active' loop
  begin
   insert into public.activity_instances select (jsonb_populate_record(null::public.activity_instances,to_jsonb(a)||jsonb_build_object('id',gen_random_uuid()))).*;
   raise exception 'Duplicate active execution accepted';
  exception when unique_violation then null;end;
 end loop;
 assert exists(select 1 from pg_index where indexrelid='public.activity_instances_one_nonterminal_context'::regclass and indisunique and indnullsnotdistinct);
end $$;
do $$declare x text;begin
 foreach x in array array['submitted','under_review','revision_requested','completed','archived'] loop
 if x in ('submitted','under_review','revision_requested') then
 begin
  insert into public.activity_instances select (jsonb_populate_record(null::public.activity_instances,(select data from instance_baseline)||jsonb_build_object('id',gen_random_uuid(),'status',x))).*;
  raise exception 'Duplicate nonterminal context accepted';
 exception when unique_violation then null;end;
 else
  insert into public.activity_instances select (jsonb_populate_record(null::public.activity_instances,(select data from instance_baseline)||jsonb_build_object('id',gen_random_uuid(),'status',x,'completed_at',case when x='completed' then now() else null end))).*;
 end if;
 end loop;

 begin update public.activity_instances set started_by='00000000-0000-4000-8000-000000006005' where id=(select id from instances where label='Individual');raise exception 'actor rewrite';exception when check_violation then null;end;
 begin update public.activity_instances set started_at=started_at+interval '1 day' where id=(select id from instances where label='Individual');raise exception 'timestamp rewrite';exception when check_violation then null;end;
 begin update public.activity_instances set configuration_snapshot='{"changed":true}' where id=(select id from instances where label='Individual');raise exception 'snapshot rewrite';exception when check_violation then null;end;
 begin update public.activity_instances set cohort_id=(select id from acceptance_cohorts where label='Unrelated') where id=(select id from instances where label='Individual');raise exception 'history scope rewrite';exception when check_violation then null;end;
 begin delete from public.activity_instances;raise exception 'history deletion';exception when check_violation then null;end;
end $$;
create temporary table activity_history as select id,to_jsonb(i) data from public.activity_instances i;
create function pg_temp.client_activity_denied() returns void language plpgsql as $$begin
 begin insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,started_by,started_at,status) select activity_definition_id,cohort_id,project_id,workspace_id,auth.uid(),now(),'active' from public.activity_instances;raise exception 'client insert';exception when insufficient_privilege then null;end;
 begin update public.activity_instances set started_by=auth.uid(),status='active',configuration_snapshot='{"role":"ADMIN"}';raise exception 'client spoof';exception when insufficient_privilege then null;end;
 begin delete from public.activity_instances;raise exception 'client delete';exception when insufficient_privilege then null;end;
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert exists(select 1 from public.activity_instances where id=(select id from instances where label='Individual')),'Personal owner allow';
 assert exists(select 1 from public.activity_instances where id=(select id from instances where label='Team')),'Team + Project participant allow';
 assert not exists(select 1 from public.activity_instances where id=(select id from instances where label='Case')),'Student Case denial';
end $$;
select pg_temp.client_activity_denied();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert exists(select 1 from public.activity_instances where id=(select id from instances where label='Case')),'Case Study Master owner allow';
 assert not exists(select 1 from public.activity_instances where id=(select id from instances where label='Individual')),'assigned Master no private Personal';
 assert not exists(select 1 from public.activity_instances where id=(select id from instances where label='Team')),'Master relationship alone not private Project access';
end $$;
select pg_temp.client_activity_denied();
do $$declare n integer;begin
 foreach n in array array[6001,6003,6005,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 assert not exists(select 1 from public.activity_instances),'Admin/unrelated Master/cohort peer/Team B/Mentor default deny';
 assert not public.can_read_activity_instance((select id from instances where label='Team')) and not public.can_read_activity_instance('00000000-0000-4000-8000-000000009999'),'exact IDs no existence distinction';
 perform pg_temp.client_activity_denied();
 end loop;
end $$;
reset role;
-- Completed participation cannot authorize new creation; history remains unchanged.
savepoint completed_participation;
update public.project_program_links set completed_at=clock_timestamp() where project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual');
select pg_temp.bad_instance('{}');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.activity_instances where project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual')),'closed participation no normal Activity access';end $$;
reset role;
do $$begin assert not exists(select 1 from activity_history b left join public.activity_instances i using(id) where i.id is null or b.data<>to_jsonb(i)),'closed participation preserves execution history';end $$;
rollback to completed_participation;
savepoint enrollment_gate;
update public.enrollments set status='completed' where user_id='00000000-0000-4000-8000-000000006004' and cohort_id=(select id from acceptance_cohorts where label='Test') and status='active';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert public.can_read_development_project((select (payload->>'id')::uuid from logged_projects where label='Individual')),'Personal Project owner still valid';assert not exists(select 1 from public.activity_instances),'non-active enrollment does not authorize Activities';end $$;
reset role;
do $$begin assert not exists(select 1 from activity_history b left join public.activity_instances i using(id) where i.id is null or b.data<>to_jsonb(i)),'enrollment state preserves Activity history';end $$;
rollback to enrollment_gate;
savepoint enrollment_gate;
update public.enrollments set status='withdrawn' where user_id='00000000-0000-4000-8000-000000006004' and cohort_id=(select id from acceptance_cohorts where label='Test') and status='active';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert public.can_read_development_project((select (payload->>'id')::uuid from logged_projects where label='Individual')),'Personal Project owner still valid';assert not exists(select 1 from public.activity_instances),'non-active enrollment does not authorize Activities';end $$;
reset role;
do $$begin assert not exists(select 1 from activity_history b left join public.activity_instances i using(id) where i.id is null or b.data<>to_jsonb(i)),'enrollment state preserves Activity history';end $$;
rollback to enrollment_gate;
savepoint enrollment_gate;
update public.enrollments set status='removed' where user_id='00000000-0000-4000-8000-000000006004' and cohort_id=(select id from acceptance_cohorts where label='Test') and status='active';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert public.can_read_development_project((select (payload->>'id')::uuid from logged_projects where label='Individual')),'Personal Project owner still valid';assert not exists(select 1 from public.activity_instances),'non-active enrollment does not authorize Activities';end $$;
reset role;
do $$begin assert not exists(select 1 from activity_history b left join public.activity_instances i using(id) where i.id is null or b.data<>to_jsonb(i)),'enrollment state preserves Activity history';end $$;
rollback to enrollment_gate;

do $$begin assert (select count(*) from public.development_projects)=(select projects from parent_counts) and (select count(*) from public.workspaces)=(select workspaces from parent_counts) and (select count(*) from public.teams)=(select teams from parent_counts) and (select count(*) from public.cohorts)=(select cohorts from parent_counts) and (select count(*) from public.project_program_links)=(select links from parent_counts),'Activity writes create no parent resources or links';end $$;
-- An invited owner can own a Project but cannot read its course Activity.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006009','activity-invited@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006009','active');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006009','participant','invited' from acceptance_cohorts where label='Test';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select public.create_personal_workspace();
create temporary table invited_project as select public.create_development_project('Invited test Project','individual',id) payload from public.workspaces where workspace_type='PERSONAL';
reset role;
insert into public.project_program_links(project_id,program_id,cohort_id) select (p.payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',c.id from invited_project p cross join acceptance_cohorts c where c.label='Test';
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id) select '00000000-0000-4000-8000-000000000801',c.id,(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid from invited_project p cross join acceptance_cohorts c where c.label='Test';
set local role authenticated;
do $$begin assert not exists(select 1 from public.activity_instances),'invited owner denied';end $$;
reset role;
-- Remaining A2 has separate explicit participation; Team removal revokes A1 only.
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert public.has_active_project_membership((select (payload->>'id')::uuid from logged_projects where label='Team')),'stale PM physically preserved';
 assert not exists(select 1 from public.activity_instances where id=(select id from instances where label='Team')),'removed member exact Activity denied';
 assert exists(select 1 from public.activity_instances where id=(select id from instances where label='Individual')),'Personal owner unaffected by Team removal';
end $$;
select pg_temp.client_activity_denied();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert exists(select 1 from public.activity_instances where id=(select id from instances where label='Team')),'remaining member valid';assert not exists(select 1 from public.activity_instances where id=(select id from instances where label='Individual')),'same-cohort peer no Personal access';end $$;
set local role anon;select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform * from public.activity_instances;raise exception 'anonymous read';exception when insufficient_privilege then null;end;end $$;
select pg_temp.client_activity_denied();
reset role;
do $$begin
 assert not exists(select 1 from activity_history b left join public.activity_instances i using(id) where i.id is null or b.data<>to_jsonb(i)),'all historical rows unchanged after removal/attacks';
 assert (select relrowsecurity from pg_class where oid='public.activity_instances'::regclass),'RLS enabled';
 assert not has_table_privilege('authenticated','public.activity_instances','INSERT,UPDATE,DELETE,TRUNCATE') and not has_any_column_privilege('authenticated','public.activity_instances','INSERT,UPDATE'),'no direct write grants';
 assert (select proconfig=array['search_path=""'] and prosecdef from pg_proc where oid='public.can_read_activity_instance(uuid)'::regprocedure),'safe caller boolean definer';
 assert not has_function_privilege('anon','public.can_read_activity_instance(uuid)','EXECUTE') and not has_function_privilege('service_role','public.can_read_activity_instance(uuid)','EXECUTE'),'restricted helper';
 assert not has_function_privilege('authenticated','public.validate_activity_instance_context()','EXECUTE'),'private invoker guard';
 assert not exists(select 1 from public.activity_participants) and not exists(select 1 from public.activity_inputs) and not exists(select 1 from public.activity_outputs),'no M7.2+ schema';
end $$;
rollback;
\echo M7.1 Activity schema/context/lifecycle/open-link/enrollment/privacy/removed/snapshot/history/direct-client security PASS
