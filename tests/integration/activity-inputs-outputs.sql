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
-- A separate Team B canonical Project/Object fixture, never an M7 entity.
insert into public.development_projects(id,name,project_type,owner_team_id,primary_workspace_id)
 select '00000000-0000-4000-8000-000000007302','Team B Object fixture','team',(payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid from acceptance_teams where label='B';
insert into public.development_objects(id,project_id,workspace_id,object_type,title,created_by)
 select '00000000-0000-4000-8000-000000007303','00000000-0000-4000-8000-000000007302',(payload->>'workspaceId')::uuid,'PROBLEM','Private B Object','00000000-0000-4000-8000-000000006006' from acceptance_teams where label='B';
-- M7.8 disallows two links for the same Object with contradictory required flags.
-- Keep M7.3's true/false shape/privacy coverage using distinct canonical sources.
create temporary table optional_input_objects as select i.label,('00000000-0000-4000-8000-'||lpad((780600+row_number() over(order by i.label))::text,12,'0'))::uuid id from instances i;
insert into public.development_objects(id,project_id,workspace_id,object_type,title,created_by)
select x.id,a.project_id,a.workspace_id,'PROBLEM','Optional source fixture',a.started_by from optional_input_objects x join instances i using(label) join public.activity_instances a on a.id=i.id;
create temporary table object_history as select id,to_jsonb(o) data from public.development_objects o;
create temporary table activity_history as select id,to_jsonb(a) data from public.activity_instances a;
create temporary table log_count as select count(*) n from public.change_log;
-- Store references only. Test both required values without changing access semantics.
insert into public.activity_inputs(activity_instance_id,input_type,development_object_id,required)
 select i.id,'development_object',case when v.required then (o.payload->>'id')::uuid else x.id end,v.required from instances i join logged_objects o on o.label=case i.label when 'Individual' then 'Problem' else i.label end join optional_input_objects x on x.label=i.label cross join (values(true),(false)) v(required);
insert into public.activity_outputs(activity_instance_id,output_type,development_object_id)
 select i.id,'development_object',(o.payload->>'id')::uuid from instances i join logged_objects o on o.label=case i.label when 'Individual' then 'Problem' else i.label end;
create temporary table io_baseline as select to_jsonb(i) data from public.activity_inputs i where activity_instance_id=(select id from instances where label='Team') and required;
create temporary table known_links as select 'input' kind,id,activity_instance_id,development_object_id from public.activity_inputs union all select 'output',id,activity_instance_id,development_object_id from public.activity_outputs;
grant select on known_links to authenticated,anon;
create function pg_temp.bad_link(kind text,patch jsonb,expected text default '23514') returns void language plpgsql as $$declare s text;begin
 begin
 if kind='input' then insert into public.activity_inputs select (jsonb_populate_record(null::public.activity_inputs,(select data from io_baseline)||patch||jsonb_build_object('id',gen_random_uuid()))).*;
 else insert into public.activity_outputs select (jsonb_populate_record(null::public.activity_outputs,(select data from io_baseline)||jsonb_build_object('output_type','development_object')||patch||jsonb_build_object('id',gen_random_uuid()))).*;end if;
 exception when others then get stacked diagnostics s=returned_sqlstate;end;
 assert s=expected,'bad '||kind||' expected '||expected||', got '||coalesce(s,'success');
end $$;
select pg_temp.bad_link(k,'{"activity_instance_id":"00000000-0000-4000-8000-000000009999"}','23503') from (values('input'),('output')) v(k);
select pg_temp.bad_link(k,'{"development_object_id":"00000000-0000-4000-8000-000000009999"}','23503') from (values('input'),('output')) v(k);
select pg_temp.bad_link(k,'{"development_object_id":null}') from (values('input'),('output')) v(k);
select pg_temp.bad_link(k,'{"artifact_id":"00000000-0000-4000-8000-000000009999"}') from (values('input'),('output')) v(k);
select pg_temp.bad_link(k,'{"evidence_id":"00000000-0000-4000-8000-000000009999"}') from (values('input'),('output')) v(k);
select pg_temp.bad_link('input','{"artifact_version_id":"00000000-0000-4000-8000-000000009999"}');
select pg_temp.bad_link('output','{"decision_id":"00000000-0000-4000-8000-000000009999"}');
select pg_temp.bad_link('input','{"input_type":"artifact"}');
select pg_temp.bad_link('output','{"output_type":"approved"}');
select pg_temp.bad_link('input','{"required":null}','23502');
-- Team A cannot reference Team B or Personal; Personal cannot reference Team A.
select pg_temp.bad_link(k,'{"development_object_id":"00000000-0000-4000-8000-000000007303"}') from (values('input'),('output')) v(k);
select pg_temp.bad_link(k,jsonb_build_object('development_object_id',(select payload->>'id' from logged_objects where label='Problem'))) from (values('input'),('output')) v(k);
select pg_temp.bad_link(k,jsonb_build_object('activity_instance_id',(select id from instances where label='Individual'))) from (values('input'),('output')) v(k);
-- Canonical Object constraints forbid manufacturing another Workspace inside a Project.
do $$begin
 begin insert into public.development_objects(project_id,workspace_id,object_type,title,created_by)
 select (p.payload->>'id')::uuid,(t.payload->>'workspaceId')::uuid,'PROBLEM','Wrong Workspace','00000000-0000-4000-8000-000000006004' from logged_projects p cross join acceptance_teams t where p.label='Individual' and t.label='A';
 raise exception 'Cross Workspace Object manufactured';exception when foreign_key_violation then null;end;
end $$;
create function pg_temp.client_link_denied() returns void language plpgsql as $$begin
 begin insert into public.activity_inputs(activity_instance_id,input_type,development_object_id,required) select activity_instance_id,'development_object',development_object_id,true from known_links limit 1;raise exception 'input insert';exception when insufficient_privilege then null;end;
 begin insert into public.activity_outputs(activity_instance_id,output_type,development_object_id) select activity_instance_id,'development_object',development_object_id from known_links limit 1;raise exception 'output insert';exception when insufficient_privilege then null;end;
 begin update public.activity_inputs set activity_instance_id=(select id from instances where label='Case'),development_object_id='00000000-0000-4000-8000-000000007303',input_type='artifact',artifact_id=gen_random_uuid(),required=false;raise exception 'input rebinding';exception when insufficient_privilege then null;end;
 begin update public.activity_outputs set activity_instance_id=(select id from instances where label='Case'),development_object_id='00000000-0000-4000-8000-000000007303',output_type='approved',decision_id=gen_random_uuid();raise exception 'output rebinding';exception when insufficient_privilege then null;end;
 begin delete from public.activity_inputs;raise exception 'input delete';exception when insufficient_privilege then null;end;
 begin delete from public.activity_outputs;raise exception 'output delete';exception when insufficient_privilege then null;end;
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert (select count(*) from public.activity_inputs)=4,'owner sees Personal and Team inputs for both required values';
 assert (select count(*) from public.activity_outputs)=2,'owner sees canonical outputs';
 assert not exists(select 1 from public.activity_inputs i left join public.development_objects o on o.id=i.development_object_id where o.id is null),'inputs require canonical Object access';
 assert not exists(select 1 from public.activity_outputs i left join public.development_objects o on o.id=i.development_object_id where o.id is null),'outputs require canonical Object access';
end $$;
select pg_temp.client_link_denied();
do $$declare u uuid;begin foreach u in array array['00000000-0000-4000-8000-000000006001'::uuid,'00000000-0000-4000-8000-000000006003'::uuid,'00000000-0000-4000-8000-000000006005'::uuid,'00000000-0000-4000-8000-000000006006'::uuid,'00000000-0000-4000-8000-000000006007'::uuid,'00000000-0000-4000-8000-000000006008'::uuid] loop
 perform set_config('request.jwt.claim.sub',u::text,true);
 assert not exists(select 1 from public.activity_inputs where id in(select id from known_links where kind='input')),'exact input IDs denied';
 assert not exists(select 1 from public.activity_outputs where id in(select id from known_links where kind='output')),'exact output IDs denied';
 assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from logged_objects where label='Problem')),'exact Personal Object denied';
 perform pg_temp.client_link_denied();
 end loop;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert (select count(*) from public.activity_inputs)=2 and (select count(*) from public.activity_outputs)=1,'Case owner current scope only';end $$;
select pg_temp.client_link_denied();
-- Team removal revokes known link and Object IDs immediately; Personal is untouched.
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.activity_inputs where activity_instance_id=(select id from instances where label='Team')),'removed Team input denied';
 assert not exists(select 1 from public.activity_outputs where activity_instance_id=(select id from instances where label='Team')),'removed Team output denied';
 assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from logged_objects where label='Team')),'removed exact Object denied';
 assert (select count(*) from public.activity_inputs)=2 and (select count(*) from public.activity_outputs)=1,'Personal unaffected';
end $$;
select pg_temp.client_link_denied();
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert (select count(*) from public.activity_inputs)=2 and (select count(*) from public.activity_outputs)=1,'remaining Team member sees preserved references only';end $$;
set local role anon;select set_config('request.jwt.claim.sub','',true);
do $$begin
 begin perform * from public.activity_inputs;raise exception 'anonymous input';exception when insufficient_privilege then null;end;
 begin perform * from public.activity_outputs;raise exception 'anonymous output';exception when insufficient_privilege then null;end;
end $$;
select pg_temp.client_link_denied();
reset role;
do $$declare t text;begin
 assert (select count(*) from public.activity_inputs)=6 and (select count(*) from public.activity_outputs)=3,'links persisted, no clone';
 assert not exists(select 1 from object_history h left join public.development_objects o using(id) where o.id is null or h.data<>to_jsonb(o)) and (select count(*) from object_history)=(select count(*) from public.development_objects),'canonical Objects unchanged';
 assert not exists(select 1 from activity_history h left join public.activity_instances a using(id) where a.id is null or h.data<>to_jsonb(a)),'links do not complete or approve Activities';
 assert (select count(*) from public.change_log)=(select n from log_count),'only explicit Team removal logs; link creation creates no mutation events';
 foreach t in array array['activity_inputs','activity_outputs'] loop
 assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass),'RLS';
 assert not has_table_privilege('authenticated','public.'||t,'INSERT,UPDATE,DELETE,TRUNCATE') and not has_any_column_privilege('authenticated','public.'||t,'INSERT,UPDATE'),'no mutation grants';
 assert not exists(select 1 from information_schema.columns where table_schema='public' and table_name=t and column_name in ('title','content','metadata','configuration_snapshot','approved','verification_status')),'no copied payload/approval';
 assert (select count(*) from pg_constraint where conrelid=('public.'||t)::regclass and contype='f')=(case when t='activity_inputs' then 5 else 4 end),'Activity/Object plus approved M8 Artifact and M12 Evidence FKs';
 assert exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey) where c.conrelid=('public.'||t)::regclass and c.contype='f' and c.confrelid='public.evidence'::regclass and a.attname='evidence_id'),'canonical Evidence FK is required';
 end loop;
 assert not has_function_privilege('authenticated','public.validate_activity_object_link()','EXECUTE'),'private guard';
 assert (select not prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.validate_activity_object_link()'::regprocedure),'invoker fixed search path';
 assert to_regclass('public.project_baselines') is null and not exists(select 1 from public.evidence) and not exists(select 1 from public.decisions),'no implicit Evidence or Decision records; unrelated future schema absent';
end $$;
rollback;
\echo M7.3 canonical input/output shape/scope/privacy/removal/direct-client security PASS
