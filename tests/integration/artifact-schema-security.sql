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

create temporary table artifact_fixture(label text primary key,id uuid,data jsonb);
grant select on artifact_fixture to authenticated,anon;
insert into public.artifacts(id,project_id,workspace_id,artifact_type,title,created_by,activity_instance_id,review_required,approval_required)
select ('00000000-0000-4000-8000-'||case when p.label='Individual' then '000000820101' when p.label='Team' then '000000820102' else '000000820103' end)::uuid,
 (p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','Private '||p.label,
 case when p.label='Case' then '00000000-0000-4000-8000-000000006002'::uuid else '00000000-0000-4000-8000-000000006004'::uuid end,
 i.id,true,true from logged_projects p join instances i on i.label=p.label;
insert into artifact_fixture select p.label,a.id,to_jsonb(a) from public.artifacts a join logged_projects p on (p.payload->>'id')::uuid=a.project_id;
insert into public.artifacts(id,project_id,workspace_id,artifact_type,title,created_by,status,archived_at)
select '00000000-0000-4000-8000-000000820104',project_id,workspace_id,artifact_type,'Archived history',created_by,'ARCHIVED',clock_timestamp() from public.artifacts where id=(select id from artifact_fixture where label='Individual');
insert into artifact_fixture select 'Archived',id,to_jsonb(a) from public.artifacts a where id='00000000-0000-4000-8000-000000820104';
-- Every approved type is accepted, independently of a Version lifecycle.
insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by)
select (f.data->>'project_id')::uuid,(f.data->>'workspace_id')::uuid,t,'Type fixture '||t::text,(f.data->>'created_by')::uuid
from artifact_fixture f cross join unnest(enum_range(null::public.artifact_type)) t where f.label='Individual';
do $$begin
 assert (select count(distinct artifact_type) from public.artifacts)=17,'exact approved vocabulary including M12.26 PATENT_READING_FRAMEWORK';
 assert not exists(select 1 from public.artifacts where status='ACTIVE' and archived_at is not null),'ACTIVE archive null';
 assert not exists(select 1 from public.artifacts where status='ARCHIVED' and archived_at is null),'ARCHIVED archive required';
 assert not exists(select 1 from public.artifacts where current_version_id is not null),'null current pointer valid';
 assert not exists(select 1 from public.artifacts where title like 'Type fixture %' and (status<>'ACTIVE' or review_required or approval_required)),'default status/flags';
 assert (select status='ACTIVE' and review_required and approval_required from public.artifacts where id=(select id from artifact_fixture where label='Individual')),'requirements not approval state';
 assert to_regclass('public.project_baselines') is null,'no premature Version table';
 assert not exists(select 1 from information_schema.columns where table_schema='public' and table_name='artifacts' and column_name in ('content','body','document_json','payload','text_snapshot','change_summary','approval_note','approved_by','approved_at')),'no Version content/state';
 assert (select relrowsecurity from pg_class where oid='public.artifacts'::regclass),'RLS enabled';
 assert not has_table_privilege('authenticated','public.artifacts','INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER');
 assert not has_table_privilege('anon','public.artifacts','SELECT,INSERT,UPDATE,DELETE');
 assert not exists(select 1 from pg_policies where schemaname='public' and tablename='artifacts' and (qual='true' or with_check='true')),'no broad policy';
 assert (select not prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.preserve_artifact_history()'::regprocedure);
 assert not has_function_privilege('authenticated','public.preserve_artifact_history()','EXECUTE');
end $$;
create function pg_temp.bad_artifact(patch jsonb,expected text) returns void language plpgsql as $$declare state0 text;begin
 begin
  insert into public.artifacts select (jsonb_populate_record(null::public.artifacts,(select data from artifact_fixture where label='Individual')||jsonb_build_object('id',gen_random_uuid(),'artifact_type','PITCH_DECK_RECORD')||patch)).*;
 exception when others then state0:=sqlstate;end;
 assert state0=expected,'Expected '||expected||', got '||coalesce(state0,'success')||' for '||patch::text;
end $$;
select pg_temp.bad_artifact('{"title":" "}','23514');
select pg_temp.bad_artifact('{"project_id":null}','23502');
select pg_temp.bad_artifact('{"workspace_id":null}','23502');
select pg_temp.bad_artifact('{"created_by":null}','23502');
select pg_temp.bad_artifact('{"artifact_type":null}','23502');
select pg_temp.bad_artifact('{"review_required":null}','23502');
select pg_temp.bad_artifact('{"approval_required":null}','23502');
select pg_temp.bad_artifact('{"created_by":"00000000-0000-4000-8000-000000999999"}','23503');
select pg_temp.bad_artifact('{"artifact_type":"CUSTOM"}','22P02');
select pg_temp.bad_artifact(jsonb_build_object('artifact_type',t),'22P02') from (values('BUSINESS_CASE'),('FUNDING_STRATEGY'),('arbitrary')) v(t);
select pg_temp.bad_artifact(jsonb_build_object('status',t),'22P02') from (values('DRAFT'),('SUBMITTED'),('UNDER_REVIEW'),('REVISION_REQUESTED'),('APPROVED'),('CURRENT'),('SUPERSEDED'),('VERIFIED'),('active')) v(t);
select pg_temp.bad_artifact('{"status":"ARCHIVED"}','23514');
select pg_temp.bad_artifact('{"archived_at":"2026-10-07T00:00:00Z"}','23514');
select pg_temp.bad_artifact(jsonb_build_object('workspace_id',payload->>'workspaceId'),'23503') from acceptance_teams where label='B';
select pg_temp.bad_artifact(jsonb_build_object('workspace_id',payload->>'primary_workspace_id'),'23503') from logged_projects where label='Team';
select pg_temp.bad_artifact(jsonb_build_object('workspace_id',id),'23503') from public.workspaces where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000006005';
select pg_temp.bad_artifact(jsonb_build_object('activity_instance_id',id),'23503') from instances where label='Team';
select pg_temp.bad_artifact('{"activity_instance_id":"00000000-0000-4000-8000-000000999999"}','23503');
-- Team A Project cannot bind Team B Workspace; a different Project cannot borrow provenance.
select pg_temp.bad_artifact(jsonb_build_object('project_id',payload->>'id','workspace_id',(select payload->>'workspaceId' from acceptance_teams where label='B'),'activity_instance_id',null),'23503') from logged_projects where label='Team';
select pg_temp.bad_artifact(jsonb_build_object('project_id',payload->>'id','workspace_id',payload->>'primary_workspace_id'),'23503') from logged_projects where label='Team';
-- Nullable Activity provenance is independently valid.
select pg_temp.bad_artifact('{"activity_instance_id":null,"title":null}','23502');
insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by)
select project_id,workspace_id,artifact_type,'No Activity provenance',created_by from public.artifacts where id=(select id from artifact_fixture where label='Individual');
-- Trusted preservation checks: no delete, restore, scope/creator/provenance rewrites.
do $$begin
 begin delete from public.artifacts where id=(select id from artifact_fixture where label='Archived');raise exception 'History deleted';exception when check_violation then null;end;
 begin update public.artifacts set status='ACTIVE',archived_at=null where id=(select id from artifact_fixture where label='Archived');raise exception 'Restore implemented';exception when check_violation then null;end;
 begin update public.artifacts set created_by='00000000-0000-4000-8000-000000006005' where id=(select id from artifact_fixture where label='Individual');raise exception 'Creator rewritten';exception when check_violation then null;end;
 begin update public.artifacts set activity_instance_id=null where id=(select id from artifact_fixture where label='Individual');raise exception 'Provenance rewritten';exception when check_violation then null;end;
 assert (select to_jsonb(a) from public.artifacts a where id=(select id from artifact_fixture where label='Archived'))=(select data from artifact_fixture where label='Archived'),'archived identity preserved';
end $$;
-- Test helper executes only under the actual caller's normal database role.
create function pg_temp.artifact_read(label0 text,allowed boolean) returns void language plpgsql as $$declare visible jsonb;missing jsonb;begin
 select coalesce(jsonb_agg(to_jsonb(a)),'[]') into visible from public.artifacts a where id=(select id from artifact_fixture where label=label0);
 select coalesce(jsonb_agg(to_jsonb(a)),'[]') into missing from public.artifacts a where id='00000000-0000-4000-8000-000000999999';
 if allowed then assert jsonb_array_length(visible)=1,'authorized current actor';else assert visible=missing and visible='[]'::jsonb,'real/unknown exact IDs expose no metadata';end if;
end $$;
create function pg_temp.client_artifact_mutation() returns void language plpgsql as $$begin
 begin insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by) select (data->>'project_id')::uuid,(data->>'workspace_id')::uuid,'PROBLEM_BANK','Spoof creator','00000000-0000-4000-8000-000000006005' from artifact_fixture where label='Individual';raise exception 'Direct insert accepted';exception when insufficient_privilege then null;end;
 begin update public.artifacts set created_by=auth.uid(),status='ACTIVE',archived_at=null;raise exception 'Direct update accepted';exception when insufficient_privilege then null;end;
 begin delete from public.artifacts;raise exception 'Direct delete accepted';exception when insufficient_privilege then null;end;
end $$;
-- Team A1 positive; same Cohort and even stale Project participation are not enough for B1.
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006006' from logged_projects where label='Team';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.artifact_read('Individual',true);select pg_temp.artifact_read('Team',true);select pg_temp.artifact_read('Archived',true);select pg_temp.client_artifact_mutation();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.artifact_read('Individual',false);select pg_temp.artifact_read('Team',false);select pg_temp.client_artifact_mutation();
do $$begin assert not exists(select 1 from public.artifacts where workspace_id=(select (data->>'workspace_id')::uuid from artifact_fixture where label='Team')),'filter cannot enumerate Team';assert not exists(select 1 from public.artifacts),'no broad enumeration';end $$;
select set_config('request.jwt.claims','{"user_metadata":{"role":"ADMIN","user_id":"00000000-0000-4000-8000-000000006004"}}',true);
select pg_temp.artifact_read('Individual',false);select pg_temp.artifact_read('Team',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select pg_temp.artifact_read('Individual',false);select pg_temp.artifact_read('Team',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.artifact_read('Individual',false);select pg_temp.artifact_read('Team',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
select pg_temp.artifact_read('Individual',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.artifact_read('Case',true);select pg_temp.artifact_read('Individual',false);
-- Removal uses the existing verified Master operation; Artifact/Activity history unchanged.
reset role;
create temporary table artifact_history_before as select jsonb_agg(to_jsonb(a) order by id) data from public.artifacts a;
create temporary table activity_history_before as select jsonb_agg(to_jsonb(a) order by id) data from public.activity_instances a;
set local role authenticated;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.artifact_read('Team',false);select pg_temp.artifact_read('Individual',true);select pg_temp.client_artifact_mutation();
do $$begin assert not exists(select 1 from public.activity_instances where id=(select id from instances where label='Team')),'M7 removal boundary unchanged';end $$;
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a)=(select data from artifact_history_before),'removal preserves Artifact history';
 assert (select jsonb_agg(to_jsonb(a) order by id) from public.activity_instances a)=(select data from activity_history_before),'M7 execution history preserved';
end $$;
set local role anon;select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform 1 from public.artifacts where id='00000000-0000-4000-8000-000000820102';raise exception 'Anonymous SELECT accepted';exception when insufficient_privilege then null;end;end $$;
select pg_temp.client_artifact_mutation();
reset role;
select 'FICI_ARTIFACT_TYPES='||jsonb_agg(enumlabel order by enumlabel)::text from pg_enum where enumtypid='public.artifact_type'::regtype;
rollback;
\echo M8.1 Artifact schema/scope/provenance/lifecycle/flags/null-pointer/privacy/RLS/history PASS
