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
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006004','participant','active' from acceptance_cohorts where label='Unrelated';
create temporary table operated_objects(label text primary key,payload jsonb);grant select,insert,update on operated_objects to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into operated_objects values('Individual',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from public.workspaces where workspace_type='PERSONAL'),'PROBLEM','Problem','Content','User','{}'));
insert into operated_objects values('Team',public.create_development_object('00000000-0000-4000-8000-000000007202',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),'IDEA','Idea','Team Content','User','{}'));
update operated_objects set payload=public.update_development_object((payload->>'id')::uuid,'{"title":"Updated problem","content":"Updated content","metadata":{"tag":"Safety"}}') where label='Individual';
do $$begin
 assert (select payload->>'created_by' from operated_objects where label='Individual')='00000000-0000-4000-8000-000000006004','verified creator';
 assert (select payload->>'current_version_number' from operated_objects where label='Individual')='1','no invented version increment';
 assert exists(select 1 from public.development_objects where title='Updated problem' and content='Updated content' and metadata='{"tag":"Safety"}'),'canonical update';
end $$;
-- A second authorized Program/Cohort context references the same persistent Project.
select public.link_project_to_program('00000000-0000-4000-8000-000000007201','00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));
reset role;
create temporary table continuity_objects as select id,to_jsonb(o) data from public.development_objects o;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.link_project_to_program('00000000-0000-4000-8000-000000007201','00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Unrelated'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into operated_objects values('Case',public.create_development_object('00000000-0000-4000-8000-000000007203','00000000-0000-4000-8000-000000007101','SOLUTION','Solution','Case Content',null,'{}'));
-- Both real private object IDs and nonexistent IDs produce generic access denial.
do $$declare who text;oid uuid;bad jsonb;begin
 foreach who in array array['6001','6003','6006','6007','6008'] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
 select (payload->>'id')::uuid into oid from operated_objects where label='Team';
 begin perform public.update_development_object(oid,'{"content":"Attack"}');raise exception 'unauthorized exact Team update';exception when insufficient_privilege then null;end;
 begin perform public.archive_development_object(oid);raise exception 'unauthorized archive';exception when insufficient_privilege then null;end;
 begin perform public.create_development_object('00000000-0000-4000-8000-000000007202',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),'PROBLEM','Attack','Attack','User','{}');raise exception 'unauthorized create';exception when insufficient_privilege then null;end;
 begin perform public.update_development_object((select (payload->>'id')::uuid from operated_objects where label='Individual'),'{"content":"Attack"}');raise exception 'private Individual update';exception when insufficient_privilege then null;end;
 begin perform public.update_development_object((select (payload->>'id')::uuid from operated_objects where label='Case'),'{"content":"Attack"}');raise exception 'private Case update';exception when insufficient_privilege then null;end;
 begin perform public.update_development_object('00000000-0000-4000-8000-000000009999','{"content":"Attack"}');raise exception 'missing object';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 select (payload->>'id')::uuid into oid from operated_objects where label='Individual';
 foreach bad in array array['{"created_by":"fake"}'::jsonb,'{"project_id":"fake"}'::jsonb,'{"workspace_id":"fake"}'::jsonb,'{"object_type":"IDEA"}'::jsonb,'{"archived_at":null}'::jsonb,'{"current_version_number":2}'::jsonb,'{"title":" "}'::jsonb,'{"metadata":null}'::jsonb,'{"content":null}'::jsonb,'{}'::jsonb] loop
 begin perform public.update_development_object(oid,bad);raise exception 'forged update accepted';exception when invalid_parameter_value then null;end;
 end loop;
 begin perform public.create_development_object('00000000-0000-4000-8000-000000007201','00000000-0000-4000-8000-000000007101','PROBLEM','Bad binding','x','User');raise exception 'wrong scope';exception when insufficient_privilege then null;end;
 begin perform public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from public.workspaces where workspace_type='PERSONAL'),'INVALID','Bad type','x','User');raise exception 'invalid kind';exception when invalid_text_representation then null;end;
 begin update public.development_objects set created_by=auth.uid();raise exception 'direct update';exception when insufficient_privilege then null;end;
 begin delete from public.development_objects;raise exception 'direct delete';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.update_development_object((select (payload->>'id')::uuid from operated_objects where label='Team'),'{"content":"Stale"}');raise exception 'stale Project Membership';exception when insufficient_privilege then null;end;
 begin perform public.archive_development_object((select (payload->>'id')::uuid from operated_objects where label='Team'));raise exception 'removed archive';exception when insufficient_privilege then null;end;
end $$;
insert into operated_objects values('Archived',public.archive_development_object((select (payload->>'id')::uuid from operated_objects where label='Individual')));
do $$declare first jsonb;retry jsonb;begin
 select payload into first from operated_objects where label='Archived';
 retry:=public.archive_development_object((first->>'id')::uuid);
 assert first=retry,'archive retry exact idempotency';
 assert first->>'archived_at' is not null,'archive timestamp set';
 assert first-'archived_at'=(select payload-'archived_at' from operated_objects where label='Individual'),'archive preserves identity/content/metadata/timestamps';
 assert exists(select 1 from public.development_objects where id=(first->>'id')::uuid and archived_at is not null),'authorized archive-aware history read';
 assert not exists(select 1 from public.development_objects where id=(first->>'id')::uuid and archived_at is null),'normal active query excludes archive';
 begin perform public.update_development_object((first->>'id')::uuid,'{"title":"Archive edit"}');raise exception 'archived update';exception when invalid_parameter_value then null;end;
end $$;
reset role;
-- Failure after write proves transaction rollback; no counter/history drift.
create function public.fixture_object_write_failure() returns trigger language plpgsql set search_path='' as $$begin raise exception 'Fixture failure' using errcode='23514';end $$;
create trigger fixture_object_update_failure after update on public.development_objects for each row execute function public.fixture_object_write_failure();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare before jsonb;begin
 select payload into before from operated_objects where label='Case';
 begin perform public.update_development_object((before->>'id')::uuid,'{"content":"Rollback"}');raise exception 'no failure';exception when check_violation then null;end;
 assert (select to_jsonb(o) from public.development_objects o where id=(before->>'id')::uuid)=before,'update rollback preserves exact row/counter';
 begin perform public.archive_development_object((before->>'id')::uuid);raise exception 'no archive failure';exception when check_violation then null;end;
 assert (select to_jsonb(o) from public.development_objects o where id=(before->>'id')::uuid)=before,'archive rollback';
end $$;
reset role;
drop trigger fixture_object_update_failure on public.development_objects;
create trigger fixture_object_insert_failure after insert on public.development_objects for each row execute function public.fixture_object_write_failure();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.create_development_object('00000000-0000-4000-8000-000000007203','00000000-0000-4000-8000-000000007101','RISK','Fail','Fail',null);raise exception 'no create failure';exception when check_violation then null;end;end $$;
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform public.archive_development_object('00000000-0000-4000-8000-000000009999');raise exception 'anon operation';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$declare f record;begin
 assert (select count(*) from public.development_objects)=3,'no clones/partial inserts';
 assert not exists(select 1 from continuity_objects b join public.development_objects o using(id) where b.data-'archived_at'<>to_jsonb(o)-'archived_at'),'same object/project/workspace identity across later contexts';
 assert (select count(*) from public.project_program_links where project_id='00000000-0000-4000-8000-000000007201')=2,'two participation contexts reference same Project';
 assert exists(select 1 from public.project_memberships where user_id='00000000-0000-4000-8000-000000006004' and status='active'),'stale Project membership fixture retained';
 assert not has_function_privilege('authenticated','public.require_development_object_write(uuid,uuid)','EXECUTE'),'private lock validator';
 for f in select oid,proconfig from pg_proc where pronamespace='public'::regnamespace and proname in ('require_development_object_write','create_development_object','update_development_object','archive_development_object') loop
 assert f.proconfig=array['search_path=""'],'fixed safe path';assert not has_function_privilege('anon',f.oid,'EXECUTE'),'no anon execute';end loop;
end $$;
rollback;
\echo M6.6 canonical create/update/archive/identity/continuity/negative attacks/atomic rollback PASS
