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

create temporary table version_parent_before as select
 (select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x) artifacts,
 (select jsonb_agg(to_jsonb(x) order by id) from public.development_projects x) projects,
 (select jsonb_agg(to_jsonb(x) order by id) from public.workspaces x) workspaces,
 (select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x) objects,
 (select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x) activities;
create temporary table version_fixture(label text primary key,id uuid,data jsonb);grant select on version_fixture to authenticated,anon;
insert into public.artifact_versions(id,artifact_id,version_number,version_label,content_snapshot,change_summary,status,created_by,previous_version_id,approved_by,approved_at)
select '00000000-0000-4000-8000-000000821101',id,1,null,'{"nodes":[{"id":"canonical-reference"}],"layout":{"x":10}}',null,'APPROVED',(data->>'created_by')::uuid,null,'00000000-0000-4000-8000-000000006002',now() from artifact_fixture where label='Individual';
insert into public.artifact_versions(id,artifact_id,version_number,version_label,content_snapshot,status,created_by,previous_version_id,approved_by,approved_at)
select '00000000-0000-4000-8000-000000821102',id,2,'v2','{"nodes":[{"id":"canonical-reference"}],"layout":{"x":20}}','CURRENT',(data->>'created_by')::uuid,'00000000-0000-4000-8000-000000821101','00000000-0000-4000-8000-000000006002',now() from artifact_fixture where label='Individual';
insert into public.artifact_versions(id,artifact_id,version_number,version_label,content_snapshot,status,created_by)
select ('00000000-0000-4000-8000-'||case when label='Team' then '000000821201' when label='Case' then '000000821301' else '000000821401' end)::uuid,id,1,null,'{"private":"scoped Version fixture"}','DRAFT',(data->>'created_by')::uuid from artifact_fixture where label in ('Team','Case','Archived');
insert into public.artifact_versions(id,artifact_id,version_number,version_label,content_snapshot,status,created_by,previous_version_id)
select '00000000-0000-4000-8000-000000821202',id,2,'v2','["structured","snapshot"]','SUBMITTED',(data->>'created_by')::uuid,'00000000-0000-4000-8000-000000821201' from artifact_fixture where label='Team';
insert into public.artifact_versions(artifact_id,version_number,version_label,content_snapshot,status,created_by,approved_by,approved_at)
select f.id,10+v.n,'non-unique metadata','{}',v.state::public.artifact_version_status,(f.data->>'created_by')::uuid,
 case when v.state in ('APPROVED','CURRENT') then '00000000-0000-4000-8000-000000006002'::uuid else null end,
 case when v.state in ('APPROVED','CURRENT') then now() else null end
from artifact_fixture f cross join (values(1,'DRAFT'),(2,'SUBMITTED'),(3,'UNDER_REVIEW'),(4,'REVISION_REQUESTED'),(5,'APPROVED'),(6,'SUPERSEDED'),(7,'SUPERSEDED'),(8,'ARCHIVED'),(9,'DRAFT')) v(n,state) where f.label='Individual';
insert into version_fixture select 'Personal V1',id,to_jsonb(v) from public.artifact_versions v where id='00000000-0000-4000-8000-000000821101';
insert into version_fixture select 'Personal V2',id,to_jsonb(v) from public.artifact_versions v where id='00000000-0000-4000-8000-000000821102';
insert into version_fixture select 'Team V1',id,to_jsonb(v) from public.artifact_versions v where id='00000000-0000-4000-8000-000000821201';
insert into version_fixture select 'Team V2',id,to_jsonb(v) from public.artifact_versions v where id='00000000-0000-4000-8000-000000821202';
insert into version_fixture select 'Case',id,to_jsonb(v) from public.artifact_versions v where id='00000000-0000-4000-8000-000000821301';
insert into version_fixture select 'Archived parent',id,to_jsonb(v) from public.artifact_versions v where id='00000000-0000-4000-8000-000000821401';
-- All following trusted inserts are schema fixtures, not public link workflows.
create temporary table link_before as select
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v) versions,
 (select jsonb_agg(to_jsonb(p) order by development_object_id) from public.problem_details p) problems;
insert into public.artifact_object_links(id,artifact_id,artifact_version_id,development_object_id,role_in_artifact,sequence,metadata)
select '00000000-0000-4000-8000-000000822101',v.artifact_id,v.id,(select (payload->>'id')::uuid from logged_objects where label='Problem'),null,0,'{}' from public.artifact_versions v where id='00000000-0000-4000-8000-000000821101';
insert into public.artifact_object_links(id,artifact_id,artifact_version_id,development_object_id,role_in_artifact,sequence,metadata)
select '00000000-0000-4000-8000-000000822102',v.artifact_id,v.id,(select (payload->>'id')::uuid from logged_objects where label='Problem'),'arbitrary context',10,'{"role":"ADMIN","scope":"not authority"}' from public.artifact_versions v where id='00000000-0000-4000-8000-000000821102';
insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence)
select v.artifact_id,v.id,(select (payload->>'id')::uuid from logged_objects where label='Solution'),0 from public.artifact_versions v where id='00000000-0000-4000-8000-000000821101';
insert into public.artifact_object_links(id,artifact_id,artifact_version_id,development_object_id)
select '00000000-0000-4000-8000-000000822201',v.artifact_id,v.id,(select (payload->>'id')::uuid from logged_objects where label='Team') from public.artifact_versions v where id='00000000-0000-4000-8000-000000821201';
do $$begin
 assert (select count(*) from public.artifact_object_links where development_object_id=(select (payload->>'id')::uuid from logged_objects where label='Problem'))=2,'same canonical Problem reused across Versions';
 assert (select count(*) from public.artifact_object_links where artifact_version_id='00000000-0000-4000-8000-000000821101' and sequence=0)=2,'duplicate presentation sequence allowed';
 assert (select objects from link_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),'no cloning, content, type, metadata, identity or provenance mutation';
 assert (select artifacts from link_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a),'no Artifact status/pointer mutation';
 assert (select versions from link_before)=(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v),'no Version status/snapshot mutation';
 assert (select problems from link_before)=(select jsonb_agg(to_jsonb(p) order by development_object_id) from public.problem_details p),'typed Problem remains canonical';
 assert (select artifact_type='PROBLEM_BANK' from public.artifacts where id='00000000-0000-4000-8000-000000820101');
 assert (select object_type='PROBLEM' from public.development_objects where id=(select (payload->>'id')::uuid from logged_objects where label='Problem'));
 assert (select relrowsecurity from pg_class where oid='public.artifact_object_links'::regclass);
 assert not has_table_privilege('authenticated','public.artifact_object_links','INSERT,UPDATE,DELETE');
 assert not has_function_privilege('authenticated','public.validate_artifact_object_link_scope()','EXECUTE');
 assert not (select prosecdef from pg_proc where oid='public.validate_artifact_object_link_scope()'::regprocedure),'invoker structural check';
 assert (select proconfig @> array['search_path=""'] from pg_proc where oid='public.validate_artifact_object_link_scope()'::regprocedure);
 assert to_regclass('public.project_baselines') is null and to_regclass('public.project_baselines') is null,'no later workflow';
end $$;
create function pg_temp.bad_link(patch jsonb, expected text) returns void language plpgsql as $$
declare row public.artifact_object_links;
begin
 select * into row from jsonb_populate_record(null::public.artifact_object_links,
 jsonb_build_object('id',gen_random_uuid(),'artifact_id','00000000-0000-4000-8000-000000820101','artifact_version_id','00000000-0000-4000-8000-000000821101',
 'development_object_id',(select (payload->>'id')::uuid from logged_objects where label='Individual Idea'),'metadata','{}'::jsonb)||patch);
 begin insert into public.artifact_object_links select row.*;raise exception 'Invalid link accepted';
 exception when others then if sqlstate<>expected then raise;end if;end;
end $$;
select pg_temp.bad_link(jsonb_build_object('artifact_version_id','00000000-0000-4000-8000-000000821201'),'23503');
select pg_temp.bad_link(jsonb_build_object('development_object_id',(select (payload->>'id')::uuid from logged_objects where label='Problem')),'23505');
select pg_temp.bad_link('{"sequence":-1}','23514');
select pg_temp.bad_link('{"role_in_artifact":" "}','23514');
select pg_temp.bad_link('{"role_in_artifact":" padded "}','23514');
select pg_temp.bad_link('{"metadata":[]}','23514');
select pg_temp.bad_link('{"metadata":null}','23502');
select pg_temp.bad_link('{"artifact_version_id":null}','23502');
select pg_temp.bad_link('{"artifact_id":null}','23503');
select pg_temp.bad_link('{"development_object_id":null}','23503');
select pg_temp.bad_link('{"development_object_id":"00000000-0000-4000-8000-000000999999"}','23503');
select pg_temp.bad_link('{"artifact_version_id":"00000000-0000-4000-8000-000000999999"}','23503');
-- Personal -> Team and Team -> Personal; IDs and metadata cannot bridge scopes.
select pg_temp.bad_link(jsonb_build_object('development_object_id',(select (payload->>'id')::uuid from logged_objects where label='Team'),'metadata','{"workspace":"spoof","role":"ADMIN"}'::jsonb),'23514');
select pg_temp.bad_link(jsonb_build_object('artifact_id','00000000-0000-4000-8000-000000820102','artifact_version_id','00000000-0000-4000-8000-000000821201'),'23514');
-- Other Project in the SAME Personal Workspace is still denied.
insert into public.development_objects(id,project_id,workspace_id,object_type,title,created_by)
select '00000000-0000-4000-8000-000000823101',p.id,p.primary_workspace_id,'PROBLEM','Other Project','00000000-0000-4000-8000-000000006004' from public.development_projects p where id='00000000-0000-4000-8000-000000007201';
select pg_temp.bad_link('{"development_object_id":"00000000-0000-4000-8000-000000823101"}','23514');
-- Canonical Team B and another Student's Personal Object, not fake scope IDs.
insert into public.development_projects(id,name,project_type,owner_team_id,primary_workspace_id)
select '00000000-0000-4000-8000-000000823201','Team B isolated fixture','team',(payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid from acceptance_teams where label='B';
insert into public.development_projects(id,name,project_type,owner_user_id,primary_workspace_id)
select '00000000-0000-4000-8000-000000823202','A2 private fixture','individual','00000000-0000-4000-8000-000000006005',id from public.workspaces where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000006005';
insert into public.development_objects(id,project_id,workspace_id,object_type,title,created_by)
select case when p.id='00000000-0000-4000-8000-000000823201' then '00000000-0000-4000-8000-000000823301'::uuid else '00000000-0000-4000-8000-000000823302'::uuid end,p.id,p.primary_workspace_id,'PROBLEM','Foreign scope',coalesce(p.owner_user_id,'00000000-0000-4000-8000-000000006006') from public.development_projects p where id in ('00000000-0000-4000-8000-000000823201','00000000-0000-4000-8000-000000823202');
select pg_temp.bad_link('{"development_object_id":"00000000-0000-4000-8000-000000823301","artifact_id":"00000000-0000-4000-8000-000000820102","artifact_version_id":"00000000-0000-4000-8000-000000821201"}','23514');
select pg_temp.bad_link('{"development_object_id":"00000000-0000-4000-8000-000000823302"}','23514');
-- Same Project/different Workspace is already structurally impossible in M6:
-- prove the canonical Object cannot be moved to manufacture such a link.
do $$begin
 begin update public.development_objects set workspace_id=(select (payload->>'workspaceId')::uuid from acceptance_teams where label='B') where id=(select (payload->>'id')::uuid from logged_objects where label='Team');raise exception 'scope transfer accepted';exception when check_violation then null;end;
end $$;
create function pg_temp.read_link(wanted uuid) returns jsonb language sql as $$select coalesce(jsonb_agg(to_jsonb(l)),'[]') from public.artifact_object_links l where id=wanted$$;
create function pg_temp.deny_link_mutations() returns void language plpgsql as $$
declare col text;
begin
 begin insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id) values('00000000-0000-4000-8000-000000820101','00000000-0000-4000-8000-000000821101','00000000-0000-4000-8000-000000823301');raise exception 'client insert accepted';exception when insufficient_privilege then null;end;
 foreach col in array array['development_object_id','artifact_version_id','artifact_id','role_in_artifact','sequence','metadata'] loop
  begin execute format('update public.artifact_object_links set %I=%I where id=%L',col,col,'00000000-0000-4000-8000-000000822101');raise exception 'client update accepted';exception when insufficient_privilege then null;end;
 end loop;
 begin delete from public.artifact_object_links where id='00000000-0000-4000-8000-000000822101';raise exception 'client delete accepted';exception when insufficient_privilege then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert pg_temp.read_link('00000000-0000-4000-8000-000000822101')<>'[]'::jsonb,'Personal owner';assert pg_temp.read_link('00000000-0000-4000-8000-000000822201')<>'[]'::jsonb,'Team A actor';end $$;
select pg_temp.deny_link_mutations();
reset role;
-- Isolate BOTH sides of RLS: a visible Version cannot expose a hidden Object.
create policy m83_test_object_deny on public.development_objects as restrictive for select to authenticated using(id<>(select (payload->>'id')::uuid from logged_objects where label='Problem'));
set local role authenticated;
do $$begin assert exists(select 1 from public.artifact_versions where id='00000000-0000-4000-8000-000000821101');assert pg_temp.read_link('00000000-0000-4000-8000-000000822101')='[]'::jsonb,'visible parent hidden Object hides link';end $$;
reset role;
drop policy m83_test_object_deny on public.development_objects;
-- Conversely visible Object with denied parent must hide links.
create policy m83_test_version_deny on public.artifact_versions as restrictive for select to authenticated using(id<>'00000000-0000-4000-8000-000000821101');
set local role authenticated;
do $$begin assert exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from logged_objects where label='Problem'));assert pg_temp.read_link('00000000-0000-4000-8000-000000822101')='[]'::jsonb;end $$;
reset role;drop policy m83_test_version_deny on public.artifact_versions;
-- Same Cohort Team B, unrelated Master, Admin and Mentor do not bridge privacy.
set local role authenticated;
do $$declare u integer;begin
 foreach u in array array[6006,6007,6003,6001,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
 assert pg_temp.read_link('00000000-0000-4000-8000-000000822101')=pg_temp.read_link('00000000-0000-4000-8000-000000999999'),'real/unknown Personal indistinguishable';
 assert pg_temp.read_link('00000000-0000-4000-8000-000000822201')='[]'::jsonb,'foreign Team denied';
 assert not exists(select 1 from public.artifact_object_links),'no metadata enumeration';
 perform pg_temp.deny_link_mutations();
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert pg_temp.read_link('00000000-0000-4000-8000-000000822101')='[]'::jsonb,'Master Personal privacy';end $$;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert pg_temp.read_link('00000000-0000-4000-8000-000000822201')='[]'::jsonb,'removed Team member';assert pg_temp.read_link('00000000-0000-4000-8000-000000822101')<>'[]'::jsonb,'Personal intact';end $$;
select pg_temp.deny_link_mutations();
reset role;
set local role anon;
do $$begin begin perform * from public.artifact_object_links;raise exception 'anonymous read accepted';exception when insufficient_privilege then null;end;end $$;
select pg_temp.deny_link_mutations();
reset role;
do $$begin assert (select count(*) from public.artifact_object_links)=4,'historical references preserved';end $$;
\echo M8.3 canonical reuse/scope/dual-RLS/known-ID/CRUD/no-side-effects PASS
rollback;
