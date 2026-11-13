\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000001601','access-admin@example.test'),('00000000-0000-4000-8000-000000001602','access-master@example.test'),('00000000-0000-4000-8000-000000001603','access-unrelated@example.test'),('00000000-0000-4000-8000-000000001604','access-student@example.test');
select public.provision_user_profile(id,'active') from auth.users where email like 'access-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000001601','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000001601');
create temporary table access_cohorts(id uuid);grant select,insert on access_cohorts to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001601',true);
insert into access_cohorts select (public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Access fixture','2026-10-01',null,'00000000-0000-4000-8000-000000001602','planned','{}')->>'id')::uuid;
-- Real scoped Master provisions separate Workspaces for two assigned Cohorts.
insert into access_cohorts select (public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Second authorized fixture','2026-10-01',null,'00000000-0000-4000-8000-000000001602','planned','{}')->>'id')::uuid;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001602',true);
do $$ declare c uuid; w jsonb; retry jsonb; begin
 for c in select id from access_cohorts loop
  w:=public.create_master_workspace(c);retry:=public.create_master_workspace(c);
  assert w=retry,'Master retry unchanged';
  assert w->>'owner_user_id'='00000000-0000-4000-8000-000000001602' and (w->>'cohort_id')::uuid=c and w->>'workspace_type'='MASTER','exact owner and cohort';
 end loop;
 assert (select count(*) from public.workspaces where workspace_type='MASTER')=2,'same Master distinct cohort Workspaces';
end $$;
-- These rollback-only fixtures are inspected separately before the existing RLS matrix.
reset role;
delete from public.workspaces where workspace_type='MASTER' and owner_user_id='00000000-0000-4000-8000-000000001602';
-- Keep just one cohort in the following metadata fixture matrix; both real cohorts persist until rollback.
delete from access_cohorts where id=(select id from access_cohorts order by id limit 1);
insert into public.workspaces(workspace_type,name,owner_user_id,cohort_id,created_by,updated_by)
 select kind::public.workspace_type,'Private metadata','00000000-0000-4000-8000-000000001602',id,'00000000-0000-4000-8000-000000001601','00000000-0000-4000-8000-000000001601' from access_cohorts cross join (values('MASTER'),('CASE_STUDY'),('TEAM'),('SHARED'),('PERSONAL')) types(kind);
insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values('MASTER','Unscoped','00000000-0000-4000-8000-000000001602','00000000-0000-4000-8000-000000001601','00000000-0000-4000-8000-000000001601');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001602',true);
do $$ begin assert (select count(*) from public.workspaces)=3,'own Personal + scoped Master/Case Study only';end $$;
reset role;
update public.workspaces set status='inactive';
set local role authenticated;
do $$ begin assert (select count(*) from public.workspaces)=0,'inactive Personal/Master/Case Study have no normal access';end $$;
reset role;
update public.workspaces set status='archived';
set local role authenticated;
do $$ begin assert (select count(*) from public.workspaces)=0,'archived Personal/Master/Case Study have no normal access';end $$;
reset role;
update public.workspaces set status='active';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001601',true);
do $$ begin assert (select count(*) from public.workspaces)=0,'Admin no private-content bypass';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001603',true);
do $$ begin assert (select count(*) from public.workspaces)=0,'unrelated denied';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001604',true);
do $$ begin assert (select count(*) from public.workspaces)=0,'Student denied';begin perform public.create_master_workspace((select id from access_cohorts));raise exception 'Student provisions Master';exception when insufficient_privilege then null;end;end $$;
reset role;
update public.role_assignments set status='inactive' where cohort_id=(select id from access_cohorts);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001602',true);
do $$ begin assert (select count(*) from public.workspaces)=1,'revoked Master scope leaves only own Personal';begin perform public.create_master_workspace((select id from access_cohorts));raise exception 'inactive Master provisions';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$ declare mode integer; c uuid; begin
 select id into c from access_cohorts;
 for mode in 1..2 loop
  if mode=1 then update public.role_assignments set status='active',starts_at=now()+interval '1 day',ends_at=null where cohort_id=c;
  else update public.role_assignments set status='active',starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where cohort_id=c;end if;
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001602',true);
  begin perform public.create_master_workspace(c);raise exception 'invalid temporal Master provisioning';exception when insufficient_privilege then null;end;
 end loop;
end $$;
update public.workspaces set status='archived'  where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000001602';
set local role authenticated;
do $$ begin assert (select count(*) from public.workspaces)=0,'archived scope denied';end $$;
reset role;
set constraints primary_master_relationship immediate;
rollback;
\echo M4.6 Master provisioning/retries/distinct cohort scopes and Workspace access RLS: exact Master scope plus owner, Personal privacy, lifecycle and deferred types PASS
