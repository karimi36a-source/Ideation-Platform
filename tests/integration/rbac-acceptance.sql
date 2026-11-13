-- Named placeholders are expanded only from validated repository fixture UUIDs.
\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('{{admin}}','m2-admin@example.test'),('{{master}}','m2-master@example.test'),
 ('{{mentor}}','m2-mentor@example.test'),('{{studentA}}','m2-student-a@example.test'),('{{studentB}}','m2-student-b@example.test');
select public.provision_user_profile(id,'active') from auth.users where id in
 ('{{admin}}','{{master}}','{{mentor}}','{{studentA}}','{{studentB}}');
-- Concrete parent rows preserve the existing isolated M2 scope fixture IDs.
insert into public.cohorts(id,program_id,curriculum_version_id,name,start_date,primary_master_id) values
 ('{{cohortA}}','00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Cohort A fixture',current_date,'{{master}}'),
 ('{{cohortB}}','00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Cohort B fixture',current_date,'{{master}}');
insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by) values
 ('{{admin}}','00000000-0000-4000-8000-000000000101','{{cohortA}}','{{admin}}'),
 ('{{master}}','00000000-0000-4000-8000-000000000102','{{cohortA}}','{{admin}}'),
 ('{{studentA}}','00000000-0000-4000-8000-000000000104','{{cohortA}}','{{admin}}'),
 ('{{studentB}}','00000000-0000-4000-8000-000000000104','{{cohortB}}','{{admin}}');
insert into public.role_assignments(user_id,role_id,team_id,assigned_by) values
 ('{{mentor}}','00000000-0000-4000-8000-000000000103','{{teamA}}','{{admin}}');
-- Test-only resource fixture; no M3/M5/M6 product tables or shipped policies.
create schema m2_acceptance_fixture;
create table m2_acceptance_fixture.restricted_resource(id uuid primary key, kind text, private_detail text);
insert into m2_acceptance_fixture.restricted_resource values
 ('{{cohortA}}','cohort','cohort A confidential'),('{{cohortB}}','cohort','cohort B confidential'),
 ('{{teamA}}','team','team A confidential'),('{{teamB}}','team','team B confidential'),
 ('{{projectA}}','project','project A confidential'),('{{projectB}}','project','project B confidential');
alter table m2_acceptance_fixture.restricted_resource enable row level security;
grant usage on schema m2_acceptance_fixture to authenticated;
grant select on m2_acceptance_fixture.restricted_resource to authenticated;
create policy fixture_scope_read on m2_acceptance_fixture.restricted_resource for select to authenticated using (
 (kind='cohort' and public.has_active_role_in_cohort('MASTER',id)) or
 (kind='team' and public.has_active_role_in_team('MENTOR',id)) or
 (kind='project' and public.has_active_role_in_project('MENTOR',id))
);
set local role authenticated;
select set_config('request.jwt.claim.sub','{{studentA}}',true);
select set_config('request.jwt.claims','{"user_metadata":{"role":"ADMIN","userId":"{{studentB}}"}}',true);
do $$ declare changed integer; begin
 assert public.current_platform_user_id()='{{studentA}}', 'spoofed user ID ignored';
 assert not public.has_active_role('ADMIN'), 'spoofed Admin role ignored';
 assert not public.has_active_role_in_cohort('STUDENT','{{cohortB}}'), 'Student B assignment cannot be impersonated';
 assert (select count(*) from public.get_active_role_assignments())=1, 'own bindings only';
 assert not exists(select 1 from public.get_active_role_assignments() where user_id<>'{{studentA}}'), 'RPC identity boundary';
 begin update public.roles set name='Attack'; raise exception 'AT-RBAC-001 direct role mutation accepted'; exception when insufficient_privilege then null; end;
 begin insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by) values ('{{studentA}}','00000000-0000-4000-8000-000000000101','{{cohortA}}','{{studentA}}'); raise exception 'AT-RBAC-001 direct self escalation accepted'; exception when insufficient_privilege then null; end;
 begin perform public.provision_user_profile('{{studentA}}','active'); raise exception 'browser reached privileged server RPC'; exception when insufficient_privilege then null; end;
 begin perform public.seed_system_roles(); raise exception 'browser reached trusted seed'; exception when insufficient_privilege then null; end;
 begin insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by) values ('{{studentB}}','00000000-0000-4000-8000-000000000101','{{cohortB}}','{{studentA}}'); raise exception 'student assigned another user'; exception when insufficient_privilege then null; end;
 begin update public.role_assignments set cohort_id='{{cohortB}}' where user_id='{{studentA}}'; raise exception 'student changed own scope'; exception when insufficient_privilege then null; end;
 begin perform public.has_active_role_in_cohort('MASTER','{{cohortA}}'::uuid,'{{master}}'::uuid); raise exception 'helper accepted caller identity'; exception when undefined_function then null; end;
 assert (select count(*) from m2_acceptance_fixture.restricted_resource)=0, 'student cannot read restricted content';
end $$;
\echo AT-RBAC-001 and direct escalation/spoofing/privileged-path denial PASS
select set_config('request.jwt.claim.sub','{{master}}',true);
do $$ begin
 assert public.has_active_role_in_cohort('MASTER','{{cohortA}}'), 'Master positive scope';
 assert not public.has_active_role_in_cohort('MASTER','{{cohortB}}'), 'AT-RBAC-002 helper denial';
 assert (select count(*) from m2_acceptance_fixture.restricted_resource)=1, 'Master sees only own cohort fixture';
 assert (select private_detail from m2_acceptance_fixture.restricted_resource where id='{{cohortA}}')='cohort A confidential', 'positive resource control';
 assert (select private_detail from m2_acceptance_fixture.restricted_resource where id='{{cohortB}}') is null, 'AT-RBAC-002 RLS protects private details';
 assert (select private_detail from m2_acceptance_fixture.restricted_resource where id='99999999-0000-4000-8000-000000000001') is null, 'missing and restricted both absent';
end $$;
\echo AT-RBAC-002 helper and direct resource RLS PASS
select set_config('request.jwt.claim.sub','{{mentor}}',true);
do $$ begin
 assert public.has_active_role_in_team('MENTOR','{{teamA}}'), 'Mentor positive scope';
 assert not public.has_active_role_in_team('MENTOR','{{teamB}}'), 'AT-RBAC-003 Team B denial';
 assert not public.has_active_role_in_project('MENTOR','{{projectA}}') and not public.has_active_role_in_project('MENTOR','{{projectB}}'), 'AT-RBAC-003 unrelated projects denial';
 assert (select count(*) from m2_acceptance_fixture.restricted_resource)=1, 'Mentor sees only Team A fixture';
 assert not exists(select 1 from m2_acceptance_fixture.restricted_resource where id in ('{{teamB}}','{{projectA}}','{{projectB}}')), 'AT-RBAC-003 direct resource RLS';
end $$;
\echo AT-RBAC-003 helper and direct resource RLS PASS
reset role;
-- Each invalidity state is tested separately with no other eligible Master binding.
update public.role_assignments set status='inactive' where user_id='{{master}}';
set local role authenticated;
select set_config('request.jwt.claim.sub','{{master}}',true);
do $$ begin assert not public.has_active_role_in_cohort('MASTER','{{cohortA}}'); assert (select count(*) from public.get_active_role_assignments())=0; assert (select count(*) from m2_acceptance_fixture.restricted_resource)=0; end $$;
reset role;
update public.role_assignments set status='active',starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where user_id='{{master}}';
set local role authenticated;
do $$ begin assert not public.has_active_role_in_cohort('MASTER','{{cohortA}}'); assert (select count(*) from public.get_active_role_assignments())=0; assert (select count(*) from m2_acceptance_fixture.restricted_resource)=0; end $$;
reset role;
update public.role_assignments set starts_at=now()+interval '1 day',ends_at=null where user_id='{{master}}';
set local role authenticated;
do $$ begin assert not public.has_active_role_in_cohort('MASTER','{{cohortA}}'); assert (select count(*) from public.get_active_role_assignments())=0; assert (select count(*) from m2_acceptance_fixture.restricted_resource)=0; end $$;
reset role;
\echo inactive expired future helper/RPC/resource RLS denial PASS
set local role authenticated;
select set_config('request.jwt.claim.sub','{{admin}}',true);
do $$ begin assert public.has_active_role_in_cohort('ADMIN','{{cohortA}}'), 'Admin operational role resolves'; assert (select count(*) from m2_acceptance_fixture.restricted_resource)=0, 'Admin has no implied educational grant'; end $$;
reset role;
rollback;


