\set ON_ERROR_STOP on
begin;
insert into public.organizations(id,name,slug) values
 ('10000000-0000-4000-8000-000000000001','Scope fixture','scope-fixture-a'),
 ('10000000-0000-4000-8000-000000000006','Scope fixture B','scope-fixture-b');
insert into public.programs(id,organization_id,name,code,program_type) values
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Fixture A','FIXTURE_A','professional_course'),
 ('10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Fixture B','FIXTURE_B','professional_course');
insert into auth.users(id,email) values
  ('00000000-0000-4000-8000-000000000002','binding-b@example.test'),
  ('00000000-0000-4000-8000-000000000003','blocked@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000000001','active');
select public.provision_user_profile('00000000-0000-4000-8000-000000000002','active');
select public.provision_user_profile('00000000-0000-4000-8000-000000000003','suspended');

-- Parent rows for pre-existing M2 authorization fixtures only; rolled back.
insert into public.cohorts(id,program_id,curriculum_version_id,name,start_date,primary_master_id)
select ('10000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Scope fixture',current_date,'00000000-0000-4000-8000-000000000001'
from unnest(array[1,2,3,4,5,6,13,23,43]) n;
insert into public.role_assignments(id,user_id,role_id,cohort_id,starts_at,ends_at,status,assigned_by) values
 ('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000003',now()-interval '1 day',null,'active','00000000-0000-4000-8000-000000000002'),
 ('00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000003',now()-interval '1 day',null,'inactive','00000000-0000-4000-8000-000000000002'),
 ('00000000-0000-4000-8000-000000000203','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000013',now()+interval '1 day',null,'active','00000000-0000-4000-8000-000000000002'),
 ('00000000-0000-4000-8000-000000000204','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000023',now()-interval '2 days',now()-interval '1 day','active','00000000-0000-4000-8000-000000000002'),
 ('00000000-0000-4000-8000-000000000206','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000003',now()-interval '1 day',null,'active','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000207','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000104','10000000-0000-4000-8000-000000000003',now()-interval '1 day',null,'active','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000208','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000003',now()-interval '1 day',now()+interval '2 days','active','00000000-0000-4000-8000-000000000002'),
 ('00000000-0000-4000-8000-000000000211','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000043',now()-interval '1 day',null,'active','00000000-0000-4000-8000-000000000002');
insert into public.role_assignments(id,user_id,role_id,organization_id,program_id,cohort_id,team_id,project_id,starts_at,ends_at,assigned_by) values
 ('00000000-0000-4000-8000-000000000205','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000102',
  '10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000005',now()-interval '1 day',now()+interval '1 day','00000000-0000-4000-8000-000000000002');

do $$ declare a public.role_assignments; begin
  select * into a from public.role_assignments where id='00000000-0000-4000-8000-000000000201';
  begin
    insert into public.role_assignments(user_id,role_id,cohort_id,starts_at,ends_at,assigned_by)
      values(a.user_id,a.role_id,a.cohort_id,a.starts_at,a.ends_at,'00000000-0000-4000-8000-000000000001');
    raise exception 'exact active retry with nullable fields was accepted';
  exception when unique_violation then null; end;
  insert into public.role_assignments(user_id,role_id,cohort_id,starts_at,ends_at,status,assigned_by)
    values(a.user_id,a.role_id,a.cohort_id,a.starts_at,a.ends_at,'inactive',a.assigned_by);
  assert (select count(*) from public.role_assignments where id=a.id)=1, 'retry preserves original identity';
  begin
    insert into public.role_assignments(user_id,role_id,assigned_by) values(a.user_id,a.role_id,a.assigned_by);
    raise exception 'unscoped assignment accepted';
  exception when check_violation then null; end;
  begin
    insert into public.role_assignments(user_id,role_id,cohort_id,starts_at,ends_at,assigned_by)
      values(a.user_id,a.role_id,a.cohort_id,now(),now(),a.assigned_by);
    raise exception 'empty validity window accepted';
  exception when check_violation then null; end;
  begin
    insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by)
      values('00000000-0000-4000-8000-000000000099',a.role_id,a.cohort_id,a.assigned_by);
    raise exception 'missing user profile accepted';
  exception when foreign_key_violation then null; end;
  begin
    insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by)
      values(a.user_id,'00000000-0000-4000-8000-000000000099',a.cohort_id,a.assigned_by);
    raise exception 'missing role accepted';
  exception when foreign_key_violation then null; end;
  begin
    insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by)
      values(a.user_id,a.role_id,a.cohort_id,'00000000-0000-4000-8000-000000000099');
    raise exception 'missing assigner profile accepted';
  exception when foreign_key_violation then null; end;
  assert (select count(*) from pg_constraint where conrelid='public.role_assignments'::regclass and contype='f')=6, 'only existing-domain FKs';
  assert not (select prosecdef from pg_proc where oid='public.get_active_role_assignments()'::regprocedure), 'read RPC must not bypass RLS';
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"user_metadata":{"role":"ADMIN","userId":"00000000-0000-4000-8000-000000000002"}}',true);
do $$ declare a public.role_assignments; begin
  assert (select count(*) from public.get_active_role_assignments())=4, 'active own assignments only';
  assert (select count(*) from public.role_assignments)=4, 'direct table query also respects status/time/identity';
  assert not exists(select 1 from public.get_active_role_assignments() where id in (
    '00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000203',
    '00000000-0000-4000-8000-000000000204','00000000-0000-4000-8000-000000000206')), 'inactive/future/expired/other-user bindings ignored';
  select * into a from public.get_active_role_assignments() where id='00000000-0000-4000-8000-000000000205';
  assert a.organization_id='10000000-0000-4000-8000-000000000001' and a.program_id='10000000-0000-4000-8000-000000000002'
    and a.cohort_id='10000000-0000-4000-8000-000000000003' and a.team_id='10000000-0000-4000-8000-000000000004'
    and a.project_id='10000000-0000-4000-8000-000000000005', 'all five scope columns preserved';
  begin insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by) values(a.user_id,a.role_id,a.cohort_id,a.user_id); raise exception 'client self-assigned role';
  exception when insufficient_privilege then null; end;
  begin update public.role_assignments set status='active'; raise exception 'client activated role';
  exception when insufficient_privilege then null; end;
  begin delete from public.role_assignments; raise exception 'client deleted attribution';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $$ begin assert (select count(*) from public.get_active_role_assignments())=1, 'user B resolves only B bindings'; end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
do $$ begin assert (select count(*) from public.get_active_role_assignments())=0, 'suspended profile has no active binding resolution'; end $$;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
do $$ begin assert (select count(*) from public.get_active_role_assignments())=0, 'missing verified subject denies resolution'; end $$;
reset role;

-- Deactivation preserves the binding and its attribution, while revoking reads.
update public.role_assignments set status='inactive' where id='00000000-0000-4000-8000-000000000201';
do $$ begin
  assert exists(select 1 from public.role_assignments where id='00000000-0000-4000-8000-000000000201' and status='inactive'), 'inactive history retained';
  assert (select updated_at>created_at from public.role_assignments where id='00000000-0000-4000-8000-000000000201'), 'update timestamp maintained';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$ begin assert (select count(*) from public.get_active_role_assignments())=3, 'deactivation takes effect on next read'; end $$;
reset role;
set local role anon;
do $$ begin
  begin perform public.get_active_role_assignments(); raise exception 'anonymous read RPC accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
\echo Scoped assignment validity, scope preservation, retry and RLS assertions passed


