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

-- M8.5 TEST CASES

create temporary table new_versions(label text,payload jsonb);grant select,insert on new_versions to authenticated;
create temporary table fresh_artifact(payload jsonb);grant select,insert on fresh_artifact to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into fresh_artifact select public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','Sequential version fixture',null,true,true) from logged_projects where label='Individual';
reset role;
-- Trusted CURRENT predecessor fixture; no approval workflow introduced.
update public.artifact_versions set status='SUPERSEDED' where artifact_id=(select artifact_id from public.artifact_versions where id='00000000-0000-4000-8000-000000821301') and status='CURRENT';
update public.artifact_versions set status='CURRENT',approved_by='00000000-0000-4000-8000-000000006002',approved_at=clock_timestamp() where id='00000000-0000-4000-8000-000000821301';
update public.artifacts set current_version_id='00000000-0000-4000-8000-000000821301' where id='00000000-0000-4000-8000-000000820103';
insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id) select '00000000-0000-4000-8000-000000820102','00000000-0000-4000-8000-000000821201',(payload->>'id')::uuid from logged_objects where label='Team';
-- Initial V1 membership must NOT be inherited by generic V2 creation.
insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id)
select (f.payload->>'artifactId')::uuid,(f.payload->>'initialVersionId')::uuid,(o.payload->>'id')::uuid from fresh_artifact f cross join logged_objects o where o.label='Problem';
create temporary table version_before as select id,to_jsonb(v) data from public.artifact_versions v;
create temporary table append_before as select
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l) links,
 (select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i) activities,
 (select count(*) from public.activity_inputs) inputs,(select count(*) from public.activity_outputs) outputs;
set local role authenticated;
insert into new_versions select 'V2',public.create_artifact_version((payload->>'artifactId')::uuid,'{"structured":{"node":[1,2]},"role":"not authority"}','Actual mutation') from fresh_artifact;
insert into new_versions select 'V3',public.create_artifact_version((payload->>'artifactId')::uuid,'["valid","JSON"]',null,'{}','{}','{}') from fresh_artifact;
insert into new_versions select 'Team',public.create_artifact_version('00000000-0000-4000-8000-000000820102','{"canonical":"reference only"}','Team Draft');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into new_versions select 'Current predecessor',public.create_artifact_version('00000000-0000-4000-8000-000000820103','{"new":"snapshot"}','New Draft');
reset role;
do $$declare x record;begin
 assert (select (payload->>'version_number')::int from new_versions where label='V2')=2;
 assert (select payload->>'previous_version_id' from new_versions where label='V2')=(select payload->>'initialVersionId' from fresh_artifact);
 assert (select payload->'content_snapshot' from new_versions where label='V2')='{"structured":{"node":[1,2]},"role":"not authority"}'::jsonb;
 assert (select payload->>'change_summary' from new_versions where label='V2')='Actual mutation';
 assert (select (payload->>'version_number')::int from new_versions where label='V3')=3;
 assert (select payload->>'previous_version_id' from new_versions where label='V3')=(select payload->>'id' from new_versions where label='V2');
 assert (select payload->>'previous_version_id' from new_versions where label='Current predecessor')='00000000-0000-4000-8000-000000821301';
 assert (select current_version_id from public.artifacts where id='00000000-0000-4000-8000-000000820103')='00000000-0000-4000-8000-000000821301';
 for x in select payload from new_versions loop
 assert x.payload->>'status'='DRAFT' and x.payload->'version_label'='null'::jsonb and x.payload->'approved_by'='null'::jsonb and x.payload->'approved_at'='null'::jsonb and x.payload->'approval_note'='null'::jsonb;
 assert (x.payload->>'created_by')::uuid=case when x.payload->>'artifact_id'='00000000-0000-4000-8000-000000820103' then '00000000-0000-4000-8000-000000006002'::uuid else '00000000-0000-4000-8000-000000006004'::uuid end;
 end loop;
 assert not exists(select 1 from version_before b join public.artifact_versions v on v.id=b.id where to_jsonb(v)<>b.data),'prior Version byte-for-byte unchanged';
 assert (select artifacts from append_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a),'Artifact and current pointers unchanged';
 assert (select objects from append_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),'no cloning or canonical mutation';
 assert (select links from append_before)=(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l),'no link copying';
 assert not exists(select 1 from new_versions n join public.artifact_object_links l on l.artifact_version_id=(n.payload->>'id')::uuid);
 assert (select activities from append_before)=(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i);
 assert (select inputs from append_before)=(select count(*) from public.activity_inputs) and (select outputs from append_before)=(select count(*) from public.activity_outputs);
 assert (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.create_artifact_version(uuid,jsonb,text,uuid[],uuid[],uuid[])'::regprocedure);
 assert not has_function_privilege('anon','public.create_artifact_version(uuid,jsonb,text,uuid[],uuid[],uuid[])','EXECUTE');
 assert not has_function_privilege('service_role','public.create_artifact_version(uuid,jsonb,text,uuid[],uuid[],uuid[])','EXECUTE');
end $$;
create function pg_temp.deny_append(a uuid,expected text default '42501',d uuid[] default '{}',e uuid[] default '{}',ai uuid[] default '{}') returns void language plpgsql as $$
declare n bigint;begin
 select count(*) into n from public.artifact_versions;
 begin perform public.create_artifact_version(a,'{}','Denied',d,e,ai);raise exception 'Invalid append accepted';exception when others then if sqlstate<>expected then raise;end if;if expected='22023' then assert sqlerrm like '%deferred%','clear unsupported source error';end if;end;
 assert (select count(*) from public.artifact_versions)=n,'no failed Version remains';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.deny_append('00000000-0000-4000-8000-000000820101','22023',array['00000000-0000-4000-8000-000000999999']::uuid[]);
select pg_temp.deny_append('00000000-0000-4000-8000-000000820101','22023','{}',array['00000000-0000-4000-8000-000000999999']::uuid[]);
select pg_temp.deny_append('00000000-0000-4000-8000-000000820101','22023','{}','{}',array['00000000-0000-4000-8000-000000999999']::uuid[]);
select pg_temp.deny_append('00000000-0000-4000-8000-000000820104');
select pg_temp.deny_append('00000000-0000-4000-8000-000000999999');
reset role;
-- Deterministic failure AFTER insert proves transaction rollback (including lock).
create function pg_temp.fail_append() returns trigger language plpgsql as $$begin raise exception 'Injected Version failure' using errcode='23514';end$$;
create trigger m85_fail_append after insert on public.artifact_versions for each row execute function pg_temp.fail_append();
set local role authenticated;
select pg_temp.deny_append((select (payload->>'artifactId')::uuid from fresh_artifact),'23514');
reset role;drop trigger m85_fail_append on public.artifact_versions;
-- Version number is not consumed by a failed transaction.
set local role authenticated;
insert into new_versions select 'After rollback',public.create_artifact_version((payload->>'artifactId')::uuid,'{}','After failure') from fresh_artifact;
do $$begin assert (select (payload->>'version_number')::int from new_versions where label='After rollback')=4;end$$;
-- Direct browser mutation and approval/number/creator spoofing denied.
do $$begin
 begin insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by) values('00000000-0000-4000-8000-000000820101',999,'{}','APPROVED','00000000-0000-4000-8000-000000006001');raise exception 'browser insert accepted';exception when insufficient_privilege then null;end;
 begin update public.artifact_versions set content_snapshot='{"overwrite":true}',version_number=999,created_by='00000000-0000-4000-8000-000000006001',approved_by='00000000-0000-4000-8000-000000006001',approved_at=now() where id='00000000-0000-4000-8000-000000821101';raise exception 'browser update accepted';exception when insufficient_privilege then null;end;
 begin delete from public.artifact_versions where id='00000000-0000-4000-8000-000000821101';raise exception 'browser delete accepted';exception when insufficient_privilege then null;end;
end$$;
do $$declare u integer;begin
 foreach u in array array[6005,6006,6007,6001,6002,6003,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
 perform pg_temp.deny_append('00000000-0000-4000-8000-000000820101');
 perform pg_temp.deny_append('00000000-0000-4000-8000-000000999999');
 end loop;
 foreach u in array array[6006,6007,6003,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
 perform pg_temp.deny_append('00000000-0000-4000-8000-000000820102');
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.deny_append('00000000-0000-4000-8000-000000820102');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.deny_append('00000000-0000-4000-8000-000000820101','28000');
reset role;
set local role anon;
do $$begin begin perform public.create_artifact_version('00000000-0000-4000-8000-000000820101','{}',null);raise exception 'anon append accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert not exists(select 1 from version_before b join public.artifact_versions v on v.id=b.id where to_jsonb(v)<>b.data);
 assert (select artifacts from append_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select objects from append_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
 assert (select links from append_before)=(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l);
end$$;
\echo M8.5 append-only/numbering/lineage/current-pointer/sources/privacy/rollback PASS
rollback;
