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
do $$begin
 assert (select previous_version_id is null from public.artifact_versions where id='00000000-0000-4000-8000-000000821101');
 assert (select previous_version_id='00000000-0000-4000-8000-000000821101' from public.artifact_versions where id='00000000-0000-4000-8000-000000821102');
 assert (select count(distinct status) from public.artifact_versions)=8,'exact eight statuses';
 assert (select count(*) from public.artifact_versions where version_number=1)=4,'per-Artifact not global numbers';
 assert not exists(select 1 from public.artifact_versions where created_at is null),'database timestamp default';
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x)=(select artifacts from version_parent_before),'no automatic pointer/status';
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.development_projects x)=(select projects from version_parent_before),'no Project mutation';
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.workspaces x)=(select workspaces from version_parent_before),'no Workspace mutation';
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x)=(select objects from version_parent_before),'no cloned/changed canonical Objects';
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x)=(select activities from version_parent_before),'M7 unchanged';
 assert not exists(select 1 from public.artifacts where current_version_id is not null),'null pointer valid';
 assert to_regclass('public.project_baselines') is null and to_regclass('public.project_baselines') is null and to_regclass('public.project_baselines') is null,'no M8.3+ workflow';
 assert (select relrowsecurity from pg_class where oid='public.artifact_versions'::regclass);
 assert not has_table_privilege('authenticated','public.artifact_versions','INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER');
 assert not has_table_privilege('anon','public.artifact_versions','SELECT,INSERT,UPDATE,DELETE');
 assert not exists(select 1 from pg_policies where schemaname='public' and tablename='artifact_versions' and (qual='true' or with_check='true'));
 assert (select not prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.preserve_artifact_version_history()'::regprocedure);
 assert not has_function_privilege('authenticated','public.preserve_artifact_version_history()','EXECUTE');
end $$;
create function pg_temp.bad_version(patch jsonb,expected text) returns void language plpgsql as $$declare state0 text;begin
 begin insert into public.artifact_versions select (jsonb_populate_record(null::public.artifact_versions,(select data from version_fixture where label='Personal V1')||jsonb_build_object('id',gen_random_uuid(),'version_number',90)||patch)).*;
 exception when others then state0:=sqlstate;end;
 assert state0=expected,'Expected '||expected||', got '||coalesce(state0,'success')||' for '||patch::text;
end $$;
select pg_temp.bad_version('{"version_number":1}','23505');
select pg_temp.bad_version('{"version_number":0}','23514');
select pg_temp.bad_version('{"version_number":-1}','23514');
select pg_temp.bad_version('{"version_number":1.5}','22P02');
select pg_temp.bad_version('{"version_number":null}','23502');
select pg_temp.bad_version('{"artifact_id":null}','23502');
select pg_temp.bad_version('{"content_snapshot":null}','23502');
select pg_temp.bad_version('{"created_by":null}','23502');
select pg_temp.bad_version('{"artifact_id":"00000000-0000-4000-8000-000000999999"}','23503');
select pg_temp.bad_version('{"previous_version_id":"00000000-0000-4000-8000-000000821201"}','23503');
select pg_temp.bad_version('{"previous_version_id":"00000000-0000-4000-8000-000000999999"}','23503');
select pg_temp.bad_version('{"id":"00000000-0000-4000-8000-000000821999","previous_version_id":"00000000-0000-4000-8000-000000821999"}','23514');
select pg_temp.bad_version('{"approved_by":null}','23514');
select pg_temp.bad_version('{"approved_at":null}','23514');
select pg_temp.bad_version('{"approved_by":null,"approved_at":null}','23514');
select pg_temp.bad_version('{"status":"CURRENT","approved_by":null,"approved_at":null}','23514');
select pg_temp.bad_version('{"approved_by":"00000000-0000-4000-8000-000000999999"}','23503');
select pg_temp.bad_version(jsonb_build_object('status',t),'22P02') from (values('ACTIVE'),('VERIFIED'),('UNVERIFIED'),('REJECTED'),('RESUBMITTED'),('custom')) v(t);
-- Narrow same-Artifact current pointer FK, without deciding Version status eligibility.
update public.artifacts set current_version_id='00000000-0000-4000-8000-000000821102' where id=(select id from artifact_fixture where label='Individual');
update public.artifacts set current_version_id='00000000-0000-4000-8000-000000821201' where id=(select id from artifact_fixture where label='Team');
do $$begin
 assert (select status='ACTIVE' from public.artifacts where id=(select id from artifact_fixture where label='Individual')),'Version/pointer do not alter Artifact lifecycle';
 begin update public.artifacts set current_version_id='00000000-0000-4000-8000-000000821201' where id=(select id from artifact_fixture where label='Individual');raise exception 'Cross Artifact pointer accepted';exception when foreign_key_violation then null;end;
 begin update public.artifacts set current_version_id='00000000-0000-4000-8000-000000999999' where id=(select id from artifact_fixture where label='Individual');raise exception 'Missing pointer accepted';exception when foreign_key_violation then null;end;
end $$;
-- Preserve historical body/approval/identity even through trusted database writes.
do $$declare v public.artifact_versions;begin
 for v in select * from public.artifact_versions where status in ('APPROVED','CURRENT','SUPERSEDED','ARCHIVED') loop
  begin update public.artifact_versions set content_snapshot='{"rewritten":true}' where id=v.id;raise exception 'Historical content rewritten';exception when check_violation then null;end;
  begin update public.artifact_versions set status='DRAFT' where id=v.id;raise exception 'History reopened';exception when check_violation then null;end;
  begin delete from public.artifact_versions where id=v.id;raise exception 'History deleted';exception when check_violation then null;end;
 end loop;
 begin update public.artifact_versions set version_number=100 where id='00000000-0000-4000-8000-000000821101';raise exception 'Number rewritten';exception when check_violation then null;end;
 begin update public.artifact_versions set artifact_id=(select id from artifact_fixture where label='Team') where id='00000000-0000-4000-8000-000000821101';raise exception 'Parent changed';exception when check_violation then null;end;
 begin update public.artifact_versions set previous_version_id=null where id='00000000-0000-4000-8000-000000821102';raise exception 'Lineage rewritten';exception when check_violation then null;end;
 begin update public.artifact_versions set created_by='00000000-0000-4000-8000-000000006005' where id='00000000-0000-4000-8000-000000821101';raise exception 'Creator rewritten';exception when check_violation then null;end;
 begin update public.artifact_versions set created_at=created_at+interval '1 day' where id='00000000-0000-4000-8000-000000821101';raise exception 'Timestamp rewritten';exception when check_violation then null;end;
 begin update public.artifact_versions set approved_by='00000000-0000-4000-8000-000000006005' where id='00000000-0000-4000-8000-000000821101';raise exception 'Approval rewritten';exception when check_violation then null;end;
end $$;
create function pg_temp.version_read(label0 text,allowed boolean) returns void language plpgsql as $$declare real0 jsonb;missing0 jsonb;begin
 select coalesce(jsonb_agg(to_jsonb(v)),'[]') into real0 from public.artifact_versions v where id=(select id from version_fixture where label=label0);
 select coalesce(jsonb_agg(to_jsonb(v)),'[]') into missing0 from public.artifact_versions v where id='00000000-0000-4000-8000-000000999999';
 if allowed then assert jsonb_array_length(real0)=1;else assert real0=missing0 and real0='[]'::jsonb,'exact real/unknown privacy parity';end if;
end $$;
create function pg_temp.version_mutation_denied() returns void language plpgsql as $$begin
 begin insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by) select (data->>'artifact_id')::uuid,99,'{}','DRAFT','00000000-0000-4000-8000-000000006005' from version_fixture where label='Personal V1';raise exception 'Client numbering/creator accepted';exception when insufficient_privilege then null;end;
 begin update public.artifact_versions set content_snapshot='{"spoof":true}',version_number=99,created_by=auth.uid(),created_at=now(),previous_version_id=null,approved_by=auth.uid(),approved_at=now(),approval_note='Forged approval';raise exception 'Client rewrite accepted';exception when insufficient_privilege then null;end;
 begin update public.artifact_versions set artifact_id=(select (data->>'artifact_id')::uuid from version_fixture where label='Team V1');raise exception 'Client parent reassignment accepted';exception when insufficient_privilege then null;end;
 begin delete from public.artifact_versions;raise exception 'Client delete accepted';exception when insufficient_privilege then null;end;
 begin update public.artifacts set current_version_id=(select id from version_fixture where label='Team V1');raise exception 'Client pointer accepted';exception when insufficient_privilege then null;end;
end $$;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006006' from logged_projects where label='Team';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.version_read('Personal V1',true);select pg_temp.version_read('Personal V2',true);select pg_temp.version_read('Team V1',true);select pg_temp.version_read('Team V2',true);select pg_temp.version_read('Archived parent',true);select pg_temp.version_mutation_denied();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.version_read('Personal V1',false);select pg_temp.version_read('Team V1',false);select pg_temp.version_mutation_denied();
do $$begin assert not exists(select 1 from public.artifact_versions),'same Cohort/known Artifact/Project membership cannot enumerate';end $$;
select set_config('request.jwt.claims','{"user_metadata":{"role":"MASTER","user_id":"00000000-0000-4000-8000-000000006004"}}',true);
select pg_temp.version_read('Personal V1',false);select pg_temp.version_read('Team V1',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.version_read('Personal V1',false);select pg_temp.version_read('Team V1',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select pg_temp.version_read('Personal V1',false);select pg_temp.version_read('Team V1',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.version_read('Case',true);select pg_temp.version_read('Personal V1',false);
reset role;
create temporary table version_history_before as select jsonb_agg(to_jsonb(v) order by id) data from public.artifact_versions v;
set local role authenticated;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.version_read('Team V1',false);select pg_temp.version_read('Team V2',false);select pg_temp.version_read('Personal V1',true);select pg_temp.version_mutation_denied();
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v)=(select data from version_history_before),'removal preserves snapshots/lineage/approval/history';
 assert (select count(*) from public.artifact_versions where status in ('ARCHIVED','SUPERSEDED'))=3,'historical rows retained';
end $$;
set local role anon;select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform 1 from public.artifact_versions where id='00000000-0000-4000-8000-000000821101';raise exception 'Anonymous read accepted';exception when insufficient_privilege then null;end;end $$;
select pg_temp.version_mutation_denied();
reset role;
select 'FICI_VERSION_STATUSES='||jsonb_agg(enumlabel order by enumlabel)::text from pg_enum where enumtypid='public.artifact_version_status'::regtype;
rollback;
\echo M8.2 Version numbering/lineage/history/approval/pointer/parent-RLS/privacy/no-workflow PASS
