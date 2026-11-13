\set ON_ERROR_STOP on
begin;
insert into public.organizations(id,name,slug) values
 ('10000000-0000-4000-8000-000000000001','Scope fixture','scope-fixture-a'),
 ('10000000-0000-4000-8000-000000000006','Scope fixture B','scope-fixture-b');
insert into public.programs(id,organization_id,name,code,program_type) values
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Fixture A','FIXTURE_A','professional_course'),
 ('10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Fixture B','FIXTURE_B','professional_course');
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000082','helper-b@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000000001','active');
select public.provision_user_profile('00000000-0000-4000-8000-000000000082','active');-- Parent rows for pre-existing M2 authorization fixtures only; rolled back.
insert into public.cohorts(id,program_id,curriculum_version_id,name,start_date,primary_master_id)
select ('10000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Scope fixture',current_date,'00000000-0000-4000-8000-000000000001'
from unnest(array[1,2,3,4,5,6,13,23,43]) n;
insert into public.role_assignments(user_id,role_id,organization_id,starts_at,assigned_by)
values('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000001',now()-interval '1 day','00000000-0000-4000-8000-000000000001');insert into public.role_assignments(user_id,role_id,program_id,starts_at,assigned_by)
values('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000001',now()-interval '1 day','00000000-0000-4000-8000-000000000001');insert into public.role_assignments(user_id,role_id,cohort_id,starts_at,assigned_by)
values('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000001',now()-interval '1 day','00000000-0000-4000-8000-000000000001');insert into public.role_assignments(user_id,role_id,team_id,starts_at,assigned_by)
values('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000001',now()-interval '1 day','00000000-0000-4000-8000-000000000001');insert into public.role_assignments(user_id,role_id,project_id,starts_at,assigned_by)
values('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000001',now()-interval '1 day','00000000-0000-4000-8000-000000000001');insert into public.role_assignments(user_id,role_id,cohort_id,starts_at,ends_at,status,assigned_by) values
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000103','10000000-0000-4000-8000-000000000002',now()-interval '2 days',now()-interval '1 day','active','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000103','10000000-0000-4000-8000-000000000003',now()-interval '1 day',null,'inactive','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000103','10000000-0000-4000-8000-000000000004',now()+interval '1 day',null,'active','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000082','00000000-0000-4000-8000-000000000104','10000000-0000-4000-8000-000000000005',now()-interval '1 day',null,'active','00000000-0000-4000-8000-000000000001');
insert into public.role_assignments(user_id,role_id,organization_id,cohort_id,assigned_by) values
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000101','10000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"user_metadata":{"role":"ADMIN","userId":"00000000-0000-4000-8000-000000000082"}}',true);
do $$ begin
 assert public.current_platform_user_id()='00000000-0000-4000-8000-000000000001', 'verified subject only';
 assert public.has_active_role('MASTER'), 'eligible presence';
 assert not public.has_active_role('STUDENT'), 'cannot impersonate B';
 assert not public.has_active_role('ADMIN'), 'multi-scope diagnostic denied';
 assert not public.has_active_role('MENTOR'), 'inactive future expired presence denied';
 assert not public.has_active_role(null), 'null role denied';
 assert not public.has_active_role('MASTER'' OR true --'), 'no dynamic SQL'; assert public.has_active_role_in_organization('MASTER','10000000-0000-4000-8000-000000000001'), 'organization match';
 assert not public.has_active_role_in_organization('MASTER','10000000-0000-4000-8000-000000000099'), 'organization mismatch';
 assert not public.has_active_role_in_organization('STUDENT','10000000-0000-4000-8000-000000000001'), 'organization unrelated role';
 assert not public.has_active_role_in_organization('MASTER',null), 'organization null denied'; assert public.has_active_role_in_program('MASTER','10000000-0000-4000-8000-000000000001'), 'program match';
 assert not public.has_active_role_in_program('MASTER','10000000-0000-4000-8000-000000000099'), 'program mismatch';
 assert not public.has_active_role_in_program('STUDENT','10000000-0000-4000-8000-000000000001'), 'program unrelated role';
 assert not public.has_active_role_in_program('MASTER',null), 'program null denied'; assert public.has_active_role_in_cohort('MASTER','10000000-0000-4000-8000-000000000001'), 'cohort match';
 assert not public.has_active_role_in_cohort('MASTER','10000000-0000-4000-8000-000000000099'), 'cohort mismatch';
 assert not public.has_active_role_in_cohort('STUDENT','10000000-0000-4000-8000-000000000001'), 'cohort unrelated role';
 assert not public.has_active_role_in_cohort('MASTER',null), 'cohort null denied'; assert public.has_active_role_in_team('MASTER','10000000-0000-4000-8000-000000000001'), 'team match';
 assert not public.has_active_role_in_team('MASTER','10000000-0000-4000-8000-000000000099'), 'team mismatch';
 assert not public.has_active_role_in_team('STUDENT','10000000-0000-4000-8000-000000000001'), 'team unrelated role';
 assert not public.has_active_role_in_team('MASTER',null), 'team null denied'; assert public.has_active_role_in_project('MASTER','10000000-0000-4000-8000-000000000001'), 'project match';
 assert not public.has_active_role_in_project('MASTER','10000000-0000-4000-8000-000000000099'), 'project mismatch';
 assert not public.has_active_role_in_project('STUDENT','10000000-0000-4000-8000-000000000001'), 'project unrelated role';
 assert not public.has_active_role_in_project('MASTER',null), 'project null denied'; assert not public.has_active_role_in_cohort('MENTOR','10000000-0000-4000-8000-000000000002'), 'expired denied';
 assert not public.has_active_role_in_cohort('MENTOR','10000000-0000-4000-8000-000000000003'), 'inactive denied';
 assert not public.has_active_role_in_cohort('MENTOR','10000000-0000-4000-8000-000000000004'), 'future denied';
 assert not public.has_active_role_in_cohort('STUDENT','10000000-0000-4000-8000-000000000005'), 'other subject denied';
 assert not public.has_active_role_in_organization('ADMIN','10000000-0000-4000-8000-000000000006'), 'multi-scope denied';
 begin perform public.current_platform_user_id('00000000-0000-4000-8000-000000000082'::uuid); raise exception 'identity override accepted'; exception when undefined_function then null; end;
end $$;
reset role;
-- Definer properties and grants are directly audited, including all five wrappers.
do $$ declare p record; n integer := 0; begin
 for p in select * from pg_proc where pronamespace='public'::regnamespace and
 (proname='current_platform_user_id' or proname='has_active_role' or proname like 'has_active_role_in_%') loop
  n:=n+1;
  assert p.prosecdef and p.provolatile='s', 'definer stable';
  assert p.proconfig = array['search_path=""'], 'fixed empty path';
  assert p.proowner=(select relowner from pg_class where oid='public.roles'::regclass), 'trusted migration owner';
  assert not has_function_privilege('anon',p.oid,'EXECUTE'), 'anonymous execution denied';
  assert not has_function_privilege('service_role',p.oid,'EXECUTE'), 'service role not product authority';
  assert has_function_privilege('authenticated',p.oid,'EXECUTE'), 'authenticated exposure only';
 end loop;
 assert n=7, 'exact helper set';
end $$;
-- Blocking each non-active profile also blocks definer reads despite RLS bypass.
do $$ declare s public.account_status; begin
 foreach s in array array['invited','suspended','archived']::public.account_status[] loop
  update public.users set account_status=s where id='00000000-0000-4000-8000-000000000001';
  assert public.current_platform_user_id() is null, 'non-active identity denied';
  assert not public.has_active_role('MASTER'), 'non-active role denied';
  assert not public.has_active_role_in_cohort('MASTER','10000000-0000-4000-8000-000000000001'), 'non-active scope denied';
 end loop;
end $$;
select set_config('request.jwt.claim.sub','',true);
do $$ begin assert public.current_platform_user_id() is null; assert not public.has_active_role('MASTER'); end $$;
set local role anon;
do $$ begin
 begin perform public.has_active_role('MASTER'); raise exception 'anon executed helper'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;


