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
-- No business operation auto-populates participants.
do $$begin assert not exists(select 1 from public.activity_participants),'no automatic participants, including Master/Mentor/Lead';end $$;
create temporary table participants(label text primary key,id uuid);grant select on participants to authenticated,anon;
insert into public.activity_participants(activity_instance_id,user_id,joined_at)
 select i.id,'00000000-0000-4000-8000-000000006004',now() from instances i where label in ('Individual','Team');
insert into participants select i.label,p.id from public.activity_participants p join instances i on i.id=p.activity_instance_id;
create temporary table participant_baseline as select to_jsonb(p) data from public.activity_participants p where id=(select id from participants where label='Team');
create function pg_temp.bad_participant(patch jsonb,expected text default '23514') returns void language plpgsql as $$declare s text;begin
 begin insert into public.activity_participants select (jsonb_populate_record(null::public.activity_participants,(select data from participant_baseline)||patch||jsonb_build_object('id',gen_random_uuid()))).*;
 exception when others then get stacked diagnostics s=returned_sqlstate;end;
 assert s=expected,'participant rejection expected '||expected||', got '||coalesce(s,'success');
end $$;
select pg_temp.bad_participant('{}','23505');
select pg_temp.bad_participant('{"activity_instance_id":"00000000-0000-4000-8000-000000009999"}','23503');
select pg_temp.bad_participant('{"user_id":"00000000-0000-4000-8000-000000009999"}','23503');
select pg_temp.bad_participant('{"joined_at":null}','23502');
select pg_temp.bad_participant('{"completed_at":"2000-01-01T00:00:00Z"}');
select pg_temp.bad_participant('{"participant_role":"admin"}');
-- Trusted lifecycle fixture: retain ended period, create a NEW row on re-entry.
update public.activity_participants set completed_at=joined_at where id=(select id from participants where label='Team');
insert into public.activity_participants(activity_instance_id,user_id,joined_at) select id,'00000000-0000-4000-8000-000000006004',now() from instances where label='Team';
do $$begin
 assert (select count(*) from public.activity_participants where activity_instance_id=(select id from instances where label='Team'))=2,'ended plus new period';
 assert (select count(*) from public.activity_participants where activity_instance_id=(select id from instances where label='Team') and completed_at is null)=1,'one open period';
 begin update public.activity_participants set completed_at=null where id=(select id from participants where label='Team');raise exception 'history reactivation';exception when check_violation then null;end;
 begin update public.activity_participants set user_id='00000000-0000-4000-8000-000000006005' where completed_at is null;raise exception 'identity mutation';exception when check_violation then null;end;
 begin update public.activity_participants set joined_at=joined_at-interval '1 day' where completed_at is null;raise exception 'join rewrite';exception when check_violation then null;end;
 begin update public.activity_participants set activity_instance_id=(select id from instances where label='Case') where completed_at is null;raise exception 'scope rewrite';exception when check_violation then null;end;
 begin delete from public.activity_participants;raise exception 'history deletion';exception when check_violation then null;end;
end $$;
-- Even a trusted stale/ineligible participation fixture cannot establish authority.
insert into public.activity_participants(activity_instance_id,user_id,joined_at) select id,'00000000-0000-4000-8000-000000006006',now() from instances where label='Team';
insert into public.activity_participants(activity_instance_id,user_id,joined_at) select id,'00000000-0000-4000-8000-000000006005',now() from instances where label='Individual';
create temporary table participant_history as select id,to_jsonb(p) data from public.activity_participants p;
create function pg_temp.client_participant_denied() returns void language plpgsql as $$begin
 begin insert into public.activity_participants(activity_instance_id,user_id,joined_at) select id,auth.uid(),now() from instances where label='Team';raise exception 'client self insert';exception when insufficient_privilege then null;end;
 begin insert into public.activity_participants(activity_instance_id,user_id,participant_role,joined_at) select id,'00000000-0000-4000-8000-000000006005','admin',now() from instances where label='Individual';raise exception 'client add/spoof';exception when insufficient_privilege then null;end;
 begin update public.activity_participants set user_id=auth.uid(),activity_instance_id=(select id from instances where label='Case'),completed_at=null,participant_role='admin';raise exception 'client rebinding/reactivation';exception when insufficient_privilege then null;end;
 begin delete from public.activity_participants;raise exception 'client delete';exception when insufficient_privilege then null;end;
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert (select count(*) from public.activity_participants where activity_instance_id=(select id from instances where label='Team'))=3,'authorized Team list includes history';assert exists(select 1 from public.activity_participants where id=(select id from participants where label='Individual')),'Personal owner';end $$;
select pg_temp.client_participant_denied();
-- B1 owns a forged participant row, but not Team A scope.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin assert not exists(select 1 from public.activity_participants),'Team B cannot enumerate or use own forged participant';end $$;
select pg_temp.client_participant_denied();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not exists(select 1 from public.activity_participants where activity_instance_id=(select id from instances where label='Individual')),'same Cohort/own forged participant no Personal access';end $$;
select pg_temp.client_participant_denied();
-- Operational Admin, Master, unrelated Master and Mentor have no automatic Project/Personal access.
do $$declare u uuid;begin foreach u in array array['00000000-0000-4000-8000-000000006001'::uuid,'00000000-0000-4000-8000-000000006002'::uuid,'00000000-0000-4000-8000-000000006003'::uuid,'00000000-0000-4000-8000-000000006008'::uuid] loop
 perform set_config('request.jwt.claim.sub',u::text,true);
 assert not exists(select 1 from public.activity_participants),'instructional role not participation/access';
 perform pg_temp.client_participant_denied();
 end loop;end $$;
reset role;
-- Active enrollment and open participation remain required despite stored rows.
savepoint completed_context;
update public.project_program_links set completed_at=clock_timestamp() where project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.activity_participants where id=(select id from participants where label='Individual')),'completed Project context denied';end $$;
reset role;rollback to completed_context;
savepoint completed_enrollment;
update public.enrollments set status='completed' where user_id='00000000-0000-4000-8000-000000006004';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.activity_participants),'completed enrollment plus participant cannot authorize';end $$;
reset role;rollback to completed_enrollment;
-- Team removal revalidates parent scope immediately, preserving participation.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.activity_participants where activity_instance_id=(select id from instances where label='Team')),'removed exact-ID/list denied';assert exists(select 1 from public.activity_participants where id=(select id from participants where label='Individual')),'Personal unaffected';end $$;
select pg_temp.client_participant_denied();
reset role;
-- Remaining A2 has explicit Project participation, can see preserved Team history.
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert exists(select 1 from public.activity_participants where id=(select id from participants where label='Team')),'remaining authorized member sees ended history';end $$;
set local role anon;select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform * from public.activity_participants;raise exception 'anonymous read';exception when insufficient_privilege then null;end;end $$;
select pg_temp.client_participant_denied();
reset role;
do $$begin
 assert not exists(select 1 from participant_history h left join public.activity_participants p using(id) where p.id is null or h.data<>to_jsonb(p)),'removal preserves every participant row';
 assert not exists(select 1 from public.activity_participants where user_id in ('00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006008')),'Master/Mentor never auto-added';
 assert (select relrowsecurity from pg_class where oid='public.activity_participants'::regclass),'RLS enabled';
 assert not has_table_privilege('authenticated','public.activity_participants','INSERT,UPDATE,DELETE,TRUNCATE') and not has_any_column_privilege('authenticated','public.activity_participants','INSERT,UPDATE'),'no client write grants';
 assert not has_function_privilege('authenticated','public.preserve_activity_participant_history()','EXECUTE'),'private history guard';
 assert (select not prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.preserve_activity_participant_history()'::regprocedure),'invoker fixed empty search path';
 assert not exists(select 1 from public.activity_inputs) and not exists(select 1 from public.activity_outputs),'no M7.3+';
end $$;
rollback;
\echo M7.2 participant history/parent privacy/removal/direct-client security PASS


