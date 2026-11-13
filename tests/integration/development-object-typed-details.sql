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

insert into public.workspaces(id,workspace_type,name,owner_user_id,cohort_id,status,created_by,updated_by) values
 ('00000000-0000-4000-8000-000000007710','MASTER','Master provenance rejection','00000000-0000-4000-8000-000000006002',(select id from acceptance_cohorts where label='Test'),'active','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006001'),
 ('00000000-0000-4000-8000-000000007711','SHARED','Shared foundation rejection','00000000-0000-4000-8000-000000006004',null,'active','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006001'),
 ('00000000-0000-4000-8000-000000007712','PERSONAL','Inactive provenance rejection','00000000-0000-4000-8000-000000006004',null,'inactive','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006001');
create temporary table typed_objects(label text primary key,payload jsonb);grant select,insert on typed_objects to authenticated;
create temporary table typed_sources as select owner_user_id,id from public.workspaces where workspace_type='PERSONAL' and status='active';grant select on typed_sources to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into typed_objects values
 ('Individual Problem',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from typed_sources where owner_user_id=auth.uid()),'PROBLEM','Problem','Content','User')),
 ('Individual Idea',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from typed_sources where owner_user_id=auth.uid()),'IDEA','Idea','Content','User')),
 ('Team Problem',public.create_development_object('00000000-0000-4000-8000-000000007202',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),'PROBLEM','Problem','Content','User')),
 ('Team Idea',public.create_development_object('00000000-0000-4000-8000-000000007202',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),'IDEA','Idea','Content','User')),
 ('Solution',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from typed_sources where owner_user_id=auth.uid()),'SOLUTION','Solution','Content','User'));
select public.write_problem_details((payload->>'id')::uuid,'{"problem_category":"technical","priority":"High","perspective":"User"}',true) from typed_objects where label in ('Individual Problem','Team Problem');
select public.write_idea_details((payload->>'id')::uuid,jsonb_build_object('technique','SCAMPER','acceptance_state','private','original_private_workspace_id',(select id from typed_sources where owner_user_id=auth.uid())),true) from typed_objects where label in ('Individual Idea','Team Idea');
select public.write_problem_details((payload->>'id')::uuid,'{"priority":"Low"}',false) from typed_objects where label='Individual Problem';
do $$declare oid uuid;k text;wid uuid;bad jsonb;begin
 select (payload->>'id')::uuid into oid from typed_objects where label='Team Idea';
 foreach k in array array['private','shared','candidate','accepted','rejected','archived'] loop
 perform public.write_idea_details(oid,jsonb_build_object('acceptance_state',k),false);
 assert exists(select 1 from public.idea_details where development_object_id=oid and acceptance_state::text=k),'six acceptance values';end loop;
 assert exists(select 1 from public.development_objects where id=oid and archived_at is null),'classification archived is not object archive';
 foreach wid in array array[
 (select id from typed_sources where owner_user_id='00000000-0000-4000-8000-000000006005'),
 (select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),
 '00000000-0000-4000-8000-000000007101'::uuid,
 '00000000-0000-4000-8000-000000007710'::uuid,'00000000-0000-4000-8000-000000007711'::uuid,'00000000-0000-4000-8000-000000007712'::uuid,'00000000-0000-4000-8000-000000009999'::uuid] loop
 begin perform public.write_idea_details(oid,jsonb_build_object('original_private_workspace_id',wid),false);raise exception 'bad provenance accepted';exception when insufficient_privilege then null;end;end loop;
 begin perform public.write_idea_details(oid,'{"acceptance_state":"APPROVED"}',false);raise exception 'bad state';exception when invalid_parameter_value then null;end;
 begin perform public.write_idea_details(oid,'{"acceptance_state":null}',false);raise exception 'null state';exception when invalid_parameter_value then null;end;
 begin perform public.write_idea_details(oid,'{"acceptance_state":"private"}',true);raise exception 'duplicate Idea';exception when unique_violation then null;end;
 begin perform public.write_problem_details((select (payload->>'id')::uuid from typed_objects where label='Team Problem'),'{}',true);raise exception 'duplicate Problem';exception when unique_violation then null;end;
 begin perform public.write_problem_details(oid,'{}',true);raise exception 'Problem on Idea';exception when invalid_parameter_value then null;end;
 begin perform public.write_problem_details((select (payload->>'id')::uuid from typed_objects where label='Solution'),'{}',true);raise exception 'Problem on Solution';exception when invalid_parameter_value then null;end;
 begin perform public.write_idea_details((select (payload->>'id')::uuid from typed_objects where label='Individual Problem'),'{"acceptance_state":"private"}',true);raise exception 'Idea on Problem';exception when invalid_parameter_value then null;end;
 foreach bad in array array['{"development_object_id":"fake"}'::jsonb,'{"project_id":"fake"}'::jsonb,'{"workspace_id":"fake"}'::jsonb,'{"created_by":"fake"}'::jsonb] loop
 begin perform public.write_problem_details((select (payload->>'id')::uuid from typed_objects where label='Team Problem'),bad,false);raise exception 'parent rebinding';exception when invalid_parameter_value then null;end;end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare oid uuid;begin
 select (payload->>'id')::uuid into oid from typed_objects where label='Team Idea';
 assert exists(select 1 from public.idea_details where development_object_id=oid),'Team authorized extension read';
 assert not exists(select 1 from public.workspaces where id=(select original_private_workspace_id from public.idea_details where development_object_id=oid)),'source reference does not grant Personal access';
 begin perform public.write_idea_details(oid,jsonb_build_object('original_private_workspace_id',(select id from typed_sources where owner_user_id=auth.uid())),false);raise exception 'editor replaces original creator source';exception when insufficient_privilege then null;end;
 perform public.write_idea_details(oid,'{"technique":"Description"}',false);
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into typed_objects values('Case Problem',public.create_development_object('00000000-0000-4000-8000-000000007203','00000000-0000-4000-8000-000000007101','PROBLEM','Case','Content',null)),('Case Idea',public.create_development_object('00000000-0000-4000-8000-000000007203','00000000-0000-4000-8000-000000007101','IDEA','Case','Content',null));
select public.write_problem_details((payload->>'id')::uuid,'{}',true) from typed_objects where label='Case Problem';
select public.write_idea_details((payload->>'id')::uuid,'{"acceptance_state":"candidate"}',true) from typed_objects where label='Case Idea';
do $$declare who text;oid uuid;begin
 foreach who in array array['6001','6003','6006','6007','6008'] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
 assert not exists(select 1 from public.problem_details) and not exists(select 1 from public.idea_details),'unrelated/Admin/Mentor without Project membership denied';
 select (payload->>'id')::uuid into oid from typed_objects where label='Team Idea';
 assert not exists(select 1 from public.idea_details where development_object_id=oid),'Team B exact Idea ID denied';
 assert not exists(select 1 from public.problem_details where development_object_id=(select (payload->>'id')::uuid from typed_objects where label='Team Problem')),'Team B exact Problem ID denied';
 begin perform public.write_idea_details(oid,'{"technique":"Attack"}',false);raise exception 'unauthorized Idea write';exception when insufficient_privilege then null;end;
 begin perform public.write_problem_details((select (payload->>'id')::uuid from typed_objects where label='Team Problem'),'{"priority":"Attack"}',false);raise exception 'unauthorized Problem write';exception when insufficient_privilege then null;end;
 begin insert into public.problem_details(development_object_id) values(oid);raise exception 'direct insert';exception when insufficient_privilege then null;end;
 begin update public.idea_details set acceptance_state='shared';raise exception 'direct update';exception when insufficient_privilege then null;end;
 begin delete from public.problem_details;raise exception 'direct delete';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert (select count(*) from public.problem_details)=1 and (select count(*) from public.idea_details)=1,'removed member only retains own Individual extensions';
 begin perform public.write_idea_details((select (payload->>'id')::uuid from typed_objects where label='Team Idea'),'{"technique":"Stale"}',false);raise exception 'stale Project membership';exception when insufficient_privilege then null;end;
end $$;
select public.archive_development_object((payload->>'id')::uuid) from typed_objects where label in ('Individual Problem','Individual Idea');
do $$begin
 assert (select count(*) from public.problem_details)=1 and (select count(*) from public.idea_details)=1,'archived parent preserves readable extension';
 begin perform public.write_problem_details((select (payload->>'id')::uuid from typed_objects where label='Individual Problem'),'{"priority":"Archive edit"}',false);raise exception 'archived write';exception when invalid_parameter_value then null;end;
end $$;
reset role;
do $$declare oid uuid;begin
 select (payload->>'id')::uuid into oid from typed_objects where label='Solution';
 begin insert into public.problem_details(development_object_id) values(oid);raise exception 'raw Problem on Solution';exception when check_violation then null;end;
 begin insert into public.idea_details(development_object_id,acceptance_state) values(oid,'private');raise exception 'raw Idea on Solution';exception when check_violation then null;end;
 begin update public.development_objects set object_type='SOLUTION' where id=(select (payload->>'id')::uuid from typed_objects where label='Team Idea');raise exception 'parent type drift';exception when check_violation then null;end;
 begin update public.idea_details set development_object_id=oid;raise exception 'extension identity drift';exception when check_violation then null;end;
 begin update public.workspaces set owner_user_id='00000000-0000-4000-8000-000000006005' where id=(select id from typed_sources where owner_user_id='00000000-0000-4000-8000-000000006004');raise exception 'source ownership drift';exception when check_violation then null;end;
 begin delete from public.problem_details;raise exception 'history delete';exception when check_violation then null;end;
 assert (select count(*) from public.problem_details)=3 and (select count(*) from public.idea_details)=3,'typed rows preserved';
 assert (select count(*) from public.development_objects)=7,'no new Problem/Idea identities';
 assert not exists(select 1 from public.shares) and not exists(select 1 from public.decisions),'states have no sharing/Decision side effects';
end $$;
-- Atomic extension write failure does not leave a partial field update.
create function public.fixture_detail_failure() returns trigger language plpgsql set search_path='' as $$begin raise exception 'Fixture failure' using errcode='23514';end $$;
create trigger fixture_idea_failure after update on public.idea_details for each row execute function public.fixture_detail_failure();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare before jsonb;oid uuid;begin
 select (payload->>'id')::uuid into oid from typed_objects where label='Case Idea';
 select to_jsonb(d) into before from public.idea_details d where development_object_id=oid;
 begin perform public.write_idea_details(oid,'{"acceptance_state":"accepted","technique":"Failure"}',false);raise exception 'no failure';exception when check_violation then null;end;
 assert (select to_jsonb(d) from public.idea_details d where development_object_id=oid)=before,'atomic rollback preserves exact extension';
end $$;
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform * from public.idea_details;raise exception 'anon read';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$declare f record;begin
 assert (select bool_and(relrowsecurity) from pg_class where oid in ('public.idea_details'::regclass,'public.problem_details'::regclass)),'typed RLS enabled';
 assert not has_table_privilege('authenticated','public.idea_details','INSERT,UPDATE,DELETE') and not has_table_privilege('authenticated','public.problem_details','INSERT,UPDATE,DELETE'),'no direct mutation grants';
 for f in select oid,proconfig from pg_proc where pronamespace='public'::regnamespace and proname in ('write_problem_details','write_idea_details') loop assert f.proconfig=array['search_path=""'],'safe fixed path';assert not has_function_privilege('anon',f.oid,'EXECUTE'),'no anonymous RPC';end loop;
end $$;
rollback;
\echo M6.7 typed extensions/type integrity/provenance/parent RLS/archive/history/atomic writes PASS
