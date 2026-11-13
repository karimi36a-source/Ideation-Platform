\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000000092','rls-b@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000000001','active');
set local role service_role;
select public.provision_user_profile('00000000-0000-4000-8000-000000000092','active');
do $$ begin
 begin update public.users set account_status='active'; raise exception 'service generic profile write'; exception when insufficient_privilege then null; end;
 begin 
insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by) values ('00000000-0000-4000-8000-000000000092','00000000-0000-4000-8000-000000000101','10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001'); raise exception 'service generic assignment'; exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Parent rows for pre-existing M2 authorization fixtures only; rolled back.
insert into public.cohorts(id,program_id,curriculum_version_id,name,start_date,primary_master_id)
select ('10000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Scope fixture',current_date,'00000000-0000-4000-8000-000000000001'
from unnest(array[1,2,3,4,5,6,13,23,43]) n;
-- Trusted owner fixtures are not a product role-management endpoint.
insert into public.role_assignments(id,user_id,role_id,cohort_id,assigned_by) values
 ('00000000-0000-4000-8000-000000000291','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000104','10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000092'),
 ('00000000-0000-4000-8000-000000000292','00000000-0000-4000-8000-000000000092','00000000-0000-4000-8000-000000000104','10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
do $$ begin
 assert (select count(*) from pg_class where oid in ('public.users'::regclass,'public.roles'::regclass,'public.role_assignments'::regclass) and relrowsecurity)=3, 'all sensitive tables enabled';
 assert (select account_status='active' from public.users where id='00000000-0000-4000-8000-000000000092'), 'trusted service RPC provisioned';
end $$;
set local role anon;
do $$ begin
 begin perform * from public.users; raise exception 'anon profiles'; exception when insufficient_privilege then null; end;
 begin perform * from public.roles; raise exception 'anon roles'; exception when insufficient_privilege then null; end;
 begin perform * from public.role_assignments; raise exception 'anon assignments'; exception when insufficient_privilege then null; end;
 begin perform public.provision_user_profile('00000000-0000-4000-8000-000000000092','active'); raise exception 'anon provisioned'; exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"user_metadata":{"role":"ADMIN"}}',true);
do $$ declare changed integer; begin
 assert public.has_active_role('STUDENT'), 'real student fixture';
 update public.users set display_name='Allowed',timezone='UTC',locale='en',profile_image=null where id='00000000-0000-4000-8000-000000000001';
 get diagnostics changed=row_count; assert changed=1, 'own permitted update';
 update public.users set display_name='Attack' where id='00000000-0000-4000-8000-000000000092';
 get diagnostics changed=row_count; assert changed=0, 'cross-user update denied';
 begin update public.users set account_status='active'; raise exception 'protected status writable'; exception when insufficient_privilege then null; end;
 begin update public.users set email='attack@example.test'; raise exception 'identity email writable'; exception when insufficient_privilege then null; end;
 begin update public.roles set name='Attack'; raise exception 'student role mutation'; exception when insufficient_privilege then null; end;
 begin insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by) values ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000101','10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001'); raise exception 'self escalation'; exception when insufficient_privilege then null; end;
 begin update public.role_assignments set status='inactive' where id='00000000-0000-4000-8000-000000000292'; raise exception 'cross-user assignment write'; exception when insufficient_privilege then null; end;
 begin update public.role_assignments set cohort_id='10000000-0000-4000-8000-000000000099'; raise exception 'scope write'; exception when insufficient_privilege then null; end;
 begin update public.role_assignments set assigned_by='00000000-0000-4000-8000-000000000001'; raise exception 'assigner write'; exception when insufficient_privilege then null; end;
 begin delete from public.role_assignments; raise exception 'client assignment deletion'; exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Transaction-only accidental grants and permissive policies prove RLS guards,
-- independently of the production privilege layer. All are rolled back.
grant select,insert,update,delete on public.roles,public.role_assignments to authenticated;
create policy test_roles_allow on public.roles for all to authenticated using(true) with check(true);
create policy test_assignments_allow on public.role_assignments for all to authenticated using(true) with check(true);
create policy test_profiles_allow on public.users for all to authenticated using(true) with check(true);
set local role authenticated;
do $$ declare changed integer; begin
 assert (select count(*) from public.roles)=0, 'restrictive catalog denial';
 assert (select count(*) from public.users)=1, 'restrictive own read';
 update public.roles set name='Attack'; get diagnostics changed=row_count; assert changed=0, 'role RLS mutation deny';
 delete from public.roles; get diagnostics changed=row_count; assert changed=0, 'role RLS delete deny';
 update public.role_assignments set cohort_id='10000000-0000-4000-8000-000000000099',assigned_by='00000000-0000-4000-8000-000000000001';
 get diagnostics changed=row_count; assert changed=0, 'assignment RLS scope/assigner denial';
 delete from public.role_assignments; get diagnostics changed=row_count; assert changed=0, 'assignment RLS delete denial';
 begin insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by) values ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000101','10000000-0000-4000-8000-000000000099','00000000-0000-4000-8000-000000000001'); raise exception 'RLS self escalation'; exception when insufficient_privilege then null; end;
 begin insert into public.roles(id,code,name,description) values ('00000000-0000-4000-8000-000000000299','ADMIN','Attack','Attack'); raise exception 'RLS role insert'; exception when insufficient_privilege then null; end;
 update public.users set display_name='Attack' where id='00000000-0000-4000-8000-000000000092';
 get diagnostics changed=row_count; assert changed=0, 'profile guard despite permissive policy';
 update public.users set display_name='Still allowed' where id='00000000-0000-4000-8000-000000000001';
 get diagnostics changed=row_count; assert changed=1, 'valid operation survives restrictive guard';
end $$;
reset role;
rollback;
\echo Base RLS direct attack and trusted provisioning assertions passed

