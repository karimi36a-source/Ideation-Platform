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
-- Enrollment-only Student: no Team or Project participation.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006009','enrollment-only@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006009','active');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006009','participant','active' from acceptance_cohorts where label='Test';
-- A stale explicit membership in a Team A Project cannot authorize Team B.
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006006' from logged_projects where label='Team';
create temporary table security_ids(table_name text,resource_id uuid);
insert into security_ids select 'development_projects',(payload->>'id')::uuid from logged_projects;
insert into security_ids select 'development_objects',(payload->>'id')::uuid from logged_objects;
insert into security_ids select 'development_object_relationships',(payload->>'id')::uuid from logged_edges;
insert into security_ids select 'problem_details',development_object_id from public.problem_details;
insert into security_ids select 'idea_details',development_object_id from public.idea_details;
insert into security_ids select 'change_log',id from public.change_log;
insert into security_ids select 'project_program_links',id from public.project_program_links;
insert into security_ids select 'project_memberships',id from public.project_memberships;
grant select on security_ids to authenticated,anon;
-- These invoker-only test utilities exercise real auth/RLS, never elevated access.
create function pg_temp.assert_private_rows() returns void language plpgsql as $$
declare t text;k text;n integer;begin
 foreach t in array array['development_projects','project_memberships','project_program_links','development_objects','development_object_relationships','problem_details','idea_details','change_log'] loop
 k:=case when t in ('problem_details','idea_details') then 'development_object_id' else 'id' end;
 begin
 execute format('select count(*) from public.%I where %I in(select resource_id from security_ids where table_name=$1)',t,k) into n using t;
 assert n=0,'exact-ID privacy: '||t;
 exception when insufficient_privilege then null;end;
 end loop;
end $$;
create function pg_temp.assert_no_direct_crud() returns void language plpgsql as $$
declare t text;k text;operation text;begin
 foreach t in array array['development_projects','project_memberships','project_program_links','development_objects','development_object_relationships','problem_details','idea_details','change_log'] loop
 k:=case when t in ('problem_details','idea_details') then 'development_object_id' else 'id' end;
 foreach operation in array array[format('insert into public.%I default values',t),format('update public.%I set %I=%I',t,k,k),format('delete from public.%I',t)] loop
 begin execute operation;raise exception 'direct client CRUD allowed: %',t;exception when insufficient_privilege then null;end;
 end loop;
 end loop;
end $$;
set local role authenticated;
-- Positive owner + current Project AND Team participant; typed/edge/log rows readable.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert (select count(*) from public.development_projects where id in(select (payload->>'id')::uuid from logged_projects))=2,'owner and Team participant';
 assert (select count(*) from public.problem_details)=2 and (select count(*) from public.idea_details)=2,'typed parent RLS';
 assert (select count(*) from public.development_object_relationships)=2,'both endpoint access';
 assert exists(select 1 from public.change_log),'legitimate history';
 assert (select count(*) from public.project_program_links)=2,'links follow privacy';
end $$;
select pg_temp.assert_no_direct_crud();
-- Assigned Master retains Case Study owner read and operational Team authority,
-- not an unapproved automatic private Team-content grant.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert public.can_manage_team((select (payload->>'teamId')::uuid from acceptance_teams where label='A')),'scoped instructional authority';
 assert exists(select 1 from public.development_projects where id=(select (payload->>'id')::uuid from logged_projects where label='Case')),'Case Study Master';
 assert not exists(select 1 from public.development_projects where id=(select (payload->>'id')::uuid from logged_projects where label='Team')),'no automatic private content grant';
end $$;
-- Team B, unrelated Master, unrelated-context Mentor, enrollment-only and Admin alone.
do $$declare n integer;begin
 foreach n in array array[6001,6003,6006,6007,6008,6009] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 perform pg_temp.assert_private_rows();perform pg_temp.assert_no_direct_crud();
 end loop;
end $$;
-- Another Student in Team A cannot see Individual content, even if trusted explicit
-- Project participation was provisioned: Personal Workspace policy remains final.
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Individual';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not exists(select 1 from public.development_projects where id=(select (payload->>'id')::uuid from logged_projects where label='Individual')),'Individual privacy';assert not exists(select 1 from public.development_objects where project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual')),'Personal exact objects';assert not exists(select 1 from public.change_log where project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual')),'Personal logs';end $$;
-- Explicit contextual Mentor participation gives existing read-only policy, never writes.
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006008' from logged_projects where label='Team';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
do $$begin assert exists(select 1 from public.development_projects where id=(select (payload->>'id')::uuid from logged_projects where label='Team')),'explicit scoped Mentor reads';begin perform public.update_development_object((select (payload->>'id')::uuid from logged_objects where label='Team'),'{"title":"Mentor write"}');raise exception 'Mentor write';exception when insufficient_privilege then null;end;end $$;
-- Workspace lifecycle independently gates Object/typed/edge reads despite Project access data.
reset role;savepoint workspace_gate;
update public.workspaces set status='inactive' where id=(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.development_objects where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team')),'inactive Workspace denies Objects';end $$;
reset role;rollback to workspace_gate;
-- Regression: archived_at blocks even an inconsistent status=active row.
savepoint archive_flag;
update public.development_projects set archived_at=statement_timestamp() where id in(select (payload->>'id')::uuid from logged_projects);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.assert_private_rows();
reset role;rollback to archive_flag;
-- Removal immediately denies stale PM across Project/Object/detail/edge/log/link layers.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare project0 uuid;object0 uuid;begin
 select (payload->>'id')::uuid into project0 from logged_projects where label='Team';select (payload->>'id')::uuid into object0 from logged_objects where label='Team';
 assert public.has_active_project_membership(project0) and not public.can_read_development_project(project0),'stale Project Membership does not bypass removal';
 assert not exists(select 1 from public.development_objects where project_id=project0),'removed Object IDs';
 assert not exists(select 1 from public.problem_details where development_object_id=object0),'removed typed ID';
 assert not exists(select 1 from public.idea_details where development_object_id=(select (payload->>'id')::uuid from logged_objects where label='Team Idea')),'removed Idea';
 assert not exists(select 1 from public.development_object_relationships where project_id=project0),'removed edge';
 assert not exists(select 1 from public.project_program_links where project_id=project0),'removed link';
 assert not exists(select 1 from public.change_log where project_id=project0),'removed logs';
 begin perform public.update_development_object(object0,'{"title":"No"}');raise exception 'removed write';exception when insufficient_privilege then null;end;
 begin perform public.relate_development_objects(object0,(select (payload->>'id')::uuid from logged_objects where label='Team Idea'),'SUPPORTS');raise exception 'removed edge write';exception when insufficient_privilege then null;end;
 begin perform public.link_project_to_program(project0,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));raise exception 'removed link write';exception when insufficient_privilege then null;end;
end $$;
-- Known inaccessible and nonexistent identities produce identical generic RPC failures.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$declare known_state text;unknown_state text;known_msg text;unknown_msg text;begin
 begin perform public.update_development_object((select (payload->>'id')::uuid from logged_objects where label='Team'),'{"title":"No"}');exception when others then get stacked diagnostics known_state=returned_sqlstate,known_msg=message_text;end;
 begin perform public.update_development_object('00000000-0000-4000-8000-000000009999','{"title":"No"}');exception when others then get stacked diagnostics unknown_state=returned_sqlstate,unknown_msg=message_text;end;
 assert known_state='42501' and known_state=unknown_state and known_msg=unknown_msg,'no Object existence metadata';
 assert not public.can_read_development_project((select (payload->>'id')::uuid from logged_projects where label='Team')) and not public.can_read_development_project('00000000-0000-4000-8000-000000009999'),'Project lookup equal safe denial';
end $$;
set local role anon;select set_config('request.jwt.claim.sub','',true);
select pg_temp.assert_private_rows();select pg_temp.assert_no_direct_crud();
reset role;
-- Consolidated catalog contract: SELECT only where approved, no mutation grants,
-- no unbound definer or anonymously callable M6 helper/RPC.
do $$declare t text;f record;is_rpc boolean;begin
 foreach t in array array['development_projects','project_memberships','project_program_links','development_objects','development_object_relationships','problem_details','idea_details','change_log'] loop
 assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass),'RLS enabled '||t;
 assert not has_table_privilege('authenticated','public.'||t,'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'),'no write grants '||t;
 assert not has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE'),'no anon grants '||t;
 assert not has_any_column_privilege('authenticated','public.'||t,'INSERT,UPDATE'),'no column bypass '||t;
 assert not exists(select 1 from pg_policy where polrelid=('public.'||t)::regclass and polpermissive and polcmd in ('a','w','d','*')),'no permissive mutation policy '||t;
 end loop;
 for f in select x.oid,x.proname,x.proconfig,x.prosecdef,x.proowner,x.proargnames from pg_proc x where x.pronamespace='public'::regnamespace and
 (x.proname in ('can_read_development_project','has_active_project_membership','can_read_project_program_link','require_development_project_write','require_development_object_write','create_development_project','get_development_project_metadata_for_edit','update_project_metadata','archive_development_project','link_project_to_program','create_development_object','update_development_object','archive_development_object','write_problem_details','write_idea_details','relate_development_objects','unlink_development_objects','append_project_change')) loop
 assert f.prosecdef and f.proconfig=array['search_path=""'],'audited fixed-path definer '||f.proname;
 assert not has_function_privilege('anon',f.oid,'EXECUTE') and not has_function_privilege('service_role',f.oid,'EXECUTE'),'no unintended execution '||f.proname;
 assert not exists(select 1 from pg_roles where oid=f.proowner and rolname in ('anon','authenticated','service_role')),'trusted function owner';
 assert not (coalesce(f.proargnames,array[]::text[]) && array['actor','actor_id','changed_by','created_by','user_id']),'no supplied actor';
 if f.proname in ('require_development_project_write','require_development_object_write','append_project_change') then assert not has_function_privilege('authenticated',f.oid,'EXECUTE'),'private internals';end if;
 end loop;
end $$;
rollback;
\echo M6.12 consolidated eight-table RLS/exact-ID/removed/spoof/grant/lifecycle regression PASS
