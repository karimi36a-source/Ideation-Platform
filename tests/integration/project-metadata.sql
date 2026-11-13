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

insert into public.project_memberships(project_id,user_id) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006008');
create temporary table metadata_objects(label text primary key,payload jsonb);grant select,insert on metadata_objects to authenticated;
create temporary table completion_project(id uuid);grant select,insert on completion_project to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into completion_project values((public.create_development_project('Completion fixture','individual',(select id from public.workspaces where workspace_type='PERSONAL'))->>'id')::uuid);
insert into metadata_objects values('Problem',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from public.workspaces where workspace_type='PERSONAL'),'PROBLEM','Problem','Content','User')),
 ('Solution',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from public.workspaces where workspace_type='PERSONAL'),'SOLUTION','Solution','Content','User'));
select public.relate_development_objects((select (payload->>'id')::uuid from metadata_objects where label='Solution'),(select (payload->>'id')::uuid from metadata_objects where label='Problem'),'SOLVES');
select public.link_project_to_program('00000000-0000-4000-8000-000000007201','00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));
reset role;
create temporary table metadata_scope_snapshot as select id,to_jsonb(p)-'name'-'description'-'status'-'current_stage'-'updated_at' data from public.development_projects p;
create temporary table metadata_object_snapshot as select id,to_jsonb(o) data from public.development_objects o;
create temporary table metadata_edge_snapshot as select id,to_jsonb(e) data from public.development_object_relationships e;
create temporary table metadata_member_snapshot as select id,to_jsonb(m) data from public.project_memberships m;
create temporary table metadata_link_snapshot as select id,to_jsonb(l) data from public.project_program_links l;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare p jsonb;before jsonb;bad jsonb;begin
 p:=public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"name":"  Renamed Project  ","description":"Updated description","current_stage":"  Feasibility investigation  "}');
 assert p->>'name'='Renamed Project' and p->>'description'='Updated description' and p->>'current_stage'='Feasibility investigation','authorized metadata trim';
 assert p->>'id'='00000000-0000-4000-8000-000000007201','same Project ID';
 before:=p;
 p:=public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"status":"active"}');assert p=before,'same status no-op keeps timestamp';
 p:=public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"status":"paused"}');assert p->>'status'='paused','active paused';
 assert not public.can_read_development_project('00000000-0000-4000-8000-000000007201'),'paused metadata path does not widen ordinary Project visibility';
 assert not exists(select 1 from public.development_objects) and not exists(select 1 from public.development_object_relationships),'paused content/edges denied';
 p:=public.get_development_project_metadata_for_edit('00000000-0000-4000-8000-000000007201');assert p->>'status'='paused','authorized paused metadata lookup';
 before:=p;p:=public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"status":"paused"}');assert p=before,'paused no-op';
 p:=public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"name":"Paused rename","current_stage":"Prototype validation"}');assert p->>'status'='paused','paused metadata editable';
 p:=public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"status":"active"}');assert p->>'status'='active','paused active';
 p:=public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"description":null,"current_stage":null}');assert p->'description'='null'::jsonb and p->'current_stage'='null'::jsonb,'nullable fields';
 foreach bad in array array['{"owner_user_id":"fake"}'::jsonb,'{"owner_team_id":"fake"}'::jsonb,'{"primary_workspace_id":"fake"}'::jsonb,'{"project_type":"team"}'::jsonb,'{"confidentiality_level":"Restricted"}'::jsonb,'{"created_by":"fake"}'::jsonb,'{"created_at":"fake"}'::jsonb,'{"archived_at":null}'::jsonb,'{"metadata":{"owner_user_id":"fake"}}'::jsonb,'{"current_stage":" "}'::jsonb,'{"name":" "}'::jsonb,jsonb_build_object('name',chr(9)||chr(10)),jsonb_build_object('current_stage',chr(9)||chr(10)),'{"status":"archived"}'::jsonb,'{}'::jsonb] loop
 begin perform public.update_project_metadata('00000000-0000-4000-8000-000000007201',bad);raise exception 'invalid patch';exception when invalid_parameter_value then null;end;end loop;
 assert (select to_jsonb(p0) from public.development_projects p0 where id='00000000-0000-4000-8000-000000007201')=p,'invalid patch no partial drift';
end $$;
select public.update_project_metadata('00000000-0000-4000-8000-000000007202','{"name":"Team edit","current_stage":"Engineering assessment"}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.update_project_metadata('00000000-0000-4000-8000-000000007202','{"description":"Team Lead has existing member edit capability"}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.update_project_metadata('00000000-0000-4000-8000-000000007203','{"name":"Case edit","current_stage":"Demonstration refinement"}');
do $$declare who text;target uuid;begin
 foreach who in array array['6001','6003','6006','6007','6008'] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
 foreach target in array array['00000000-0000-4000-8000-000000007201'::uuid,'00000000-0000-4000-8000-000000007202'::uuid,'00000000-0000-4000-8000-000000007203'::uuid,'00000000-0000-4000-8000-000000009999'::uuid] loop
 begin perform public.update_project_metadata(target,'{"name":"Attack"}');raise exception 'unauthorized metadata';exception when insufficient_privilege then null;end;
 begin perform public.get_development_project_metadata_for_edit(target);raise exception 'metadata enumeration';exception when insufficient_privilege then null;end;end loop;
 begin update public.development_projects set current_stage='Attack',status='archived';raise exception 'direct client update';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.update_project_metadata('00000000-0000-4000-8000-000000007202','{"current_stage":"Stale membership"}');raise exception 'removed Team/stale Project membership';exception when insufficient_privilege then null;end;end $$;
-- Completed projects are terminal, from either eligible status.
select public.update_project_metadata((select id from completion_project),'{"status":"completed"}');
select public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"status":"paused"}');
select public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"status":"completed"}');
do $$declare bad jsonb;begin
 foreach bad in array array['{"status":"active"}'::jsonb,'{"status":"paused"}'::jsonb,'{"status":"archived"}'::jsonb,'{"name":"Reopen"}'::jsonb,'{"current_stage":"Reopen"}'::jsonb] loop
 begin perform public.update_project_metadata('00000000-0000-4000-8000-000000007201',bad);raise exception 'completed mutation';exception when insufficient_privilege then null;end;end loop;
end $$;
reset role;
-- Trusted fixture only, not an M6.9 archive operation.
update public.development_projects set status='archived' where id=(select id from completion_project);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare bad jsonb;begin
 foreach bad in array array['{"status":"active"}'::jsonb,'{"status":"paused"}'::jsonb,'{"status":"completed"}'::jsonb,'{"name":"Archive rename"}'::jsonb] loop
 begin perform public.update_project_metadata((select id from completion_project),bad);raise exception 'archive restore/edit';exception when insufficient_privilege then null;end;end loop;
end $$;
reset role;
update public.development_projects set status='active',archived_at=clock_timestamp() where id=(select id from completion_project);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.update_project_metadata((select id from completion_project),'{"name":"Hidden archive flag"}');raise exception 'archived timestamp bypass';exception when insufficient_privilege then null;end;end $$;
reset role;
-- Forced post-update failure must roll back every metadata/status/stage field.
create function public.fixture_metadata_failure() returns trigger language plpgsql set search_path='' as $$begin raise exception 'Fixture failure' using errcode='23514';end $$;
create trigger fixture_metadata_failure after update on public.development_projects for each row execute function public.fixture_metadata_failure();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare before jsonb;begin
 before:=public.get_development_project_metadata_for_edit('00000000-0000-4000-8000-000000007203');
 begin perform public.update_project_metadata('00000000-0000-4000-8000-000000007203','{"name":"Failure","description":"Failure","current_stage":"Failure","status":"completed"}');raise exception 'no forced failure';exception when check_violation then null;end;
 assert public.get_development_project_metadata_for_edit('00000000-0000-4000-8000-000000007203')=before,'atomic rollback exact canonical row';
end $$;
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform public.update_project_metadata('00000000-0000-4000-8000-000000007201','{"name":"Anonymous"}');raise exception 'anonymous edit';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$declare f record;begin
 assert not exists(select 1 from metadata_object_snapshot b join public.development_objects o using(id) where b.data<>to_jsonb(o)),'Objects preserved across stage changes';
 assert not exists(select 1 from metadata_edge_snapshot b join public.development_object_relationships e using(id) where b.data<>to_jsonb(e)),'Relationships preserved';
 assert not exists(select 1 from metadata_member_snapshot b join public.project_memberships m using(id) where b.data<>to_jsonb(m)),'Project memberships preserved';
 assert not exists(select 1 from metadata_link_snapshot b join public.project_program_links l using(id) where b.data<>to_jsonb(l)),'Program links preserved';
 assert not exists(select 1 from metadata_scope_snapshot b join public.development_projects p using(id) where b.data<>to_jsonb(p)-'name'-'description'-'status'-'current_stage'-'updated_at' and p.id<>(select id from completion_project)),'identity/ownership/Workspace/confidentiality preserved';
 assert (select count(*) from public.development_projects)=4 and (select count(*) from public.development_objects)=2 and (select count(*) from public.development_object_relationships)=1,'no Project/Object/Relationship clones';
 assert not has_function_privilege('authenticated','public.require_development_project_write(uuid,boolean)','EXECUTE'),'private shared validator';
 for f in select oid,proconfig from pg_proc where pronamespace='public'::regnamespace and proname in ('get_development_project_metadata_for_edit','update_project_metadata','require_development_project_write') loop assert f.proconfig=array['search_path=""'],'fixed safe path';assert not has_function_privilege('anon',f.oid,'EXECUTE'),'no anonymous RPC';end loop;
 assert to_regclass('public.project_baselines') is null,'no premature formal version tables';
end $$;
rollback;
\echo M6.9 metadata/stage/status/paused isolation/identity preservation/RLS/atomicity PASS
\echo M6.9 metadata logging integration owned and tested by M6.10
