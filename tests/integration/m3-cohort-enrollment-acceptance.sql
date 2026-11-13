\set ON_ERROR_STOP on
begin;
-- Deterministic identities are authorization fixtures only. Everything rolls back.
insert into auth.users(id,email) values
('00000000-0000-4000-8000-000000001301','m310-admin@example.test'),
('00000000-0000-4000-8000-000000001302','m310-master@example.test'),
('00000000-0000-4000-8000-000000001303','m310-unrelated-master@example.test'),
('00000000-0000-4000-8000-000000001304','m310-a1@example.test'),
('00000000-0000-4000-8000-000000001305','m310-a2@example.test'),
('00000000-0000-4000-8000-000000001306','m310-b1@example.test'),
('00000000-0000-4000-8000-000000001307','m310-b2@example.test');
select public.provision_user_profile(id,'active') from auth.users where email like 'm310-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
 ('00000000-0000-4000-8000-000000001301','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000001301');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by)
 select id,'00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000001301' from public.users where email in ('m310-a1@example.test','m310-a2@example.test','m310-b1@example.test','m310-b2@example.test');
create temporary table m310_ids(label text primary key,id uuid);
grant select,insert on m310_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001301',true);
insert into m310_ids select 'cohort',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Professional Course — Test Cohort','2026-10-01',null,'00000000-0000-4000-8000-000000001302','planned','{}')->>'id')::uuid;
insert into m310_ids select 'unrelated',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Unrelated Test Cohort','2026-10-01',null,'00000000-0000-4000-8000-000000001303','planned','{}')->>'id')::uuid;
do $$ declare n integer; cid uuid; uid uuid; r jsonb; begin
 select id into cid from m310_ids where label='cohort';
 assert exists(select 1 from public.cohorts where id=cid and program_id='00000000-0000-4000-8000-000000000601' and curriculum_version_id='00000000-0000-4000-8000-000000000602'),'M3.10 01-02 Admin cohort and fixed curriculum';
 for n in 1304..1307 loop
  uid:=('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
  r:=public.enroll_user(cid,uid,'participant','active');
  insert into m310_ids values('admin-'||n,(r->>'id')::uuid);
 end loop;
 assert (select count(*) from public.enrollments where cohort_id=cid and status='active')=4,'M3.10 05 Admin enrolls four';
 for n in 1304..1307 loop perform public.remove_enrollment((select id from m310_ids where label='admin-'||n));end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001302',true);
do $$ declare n integer; cid uuid; uid uuid; r jsonb; begin
 select id into cid from m310_ids where label='cohort';
 assert exists(select 1 from public.cohorts where id=cid),'M3.10 03 assigned Master reads';
 assert not exists(select 1 from public.cohorts where id=(select id from m310_ids where label='unrelated')),'Master unrelated scope denied';
 for n in 1304..1307 loop
  uid:=('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
  r:=public.enroll_user(cid,uid,'participant','active');insert into m310_ids values('master-'||n,(r->>'id')::uuid);
 end loop;
 assert (select count(*) from public.enrollments where cohort_id=cid and status='active')=4,'M3.10 06 Master adds four students';
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001304','participant','active');raise exception 'duplicate accepted';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001303',true);
do $$ declare cid uuid; begin
 select id into cid from m310_ids where label='cohort';assert not exists(select 1 from public.cohorts where id=cid),'M3.10 04 unrelated Master cannot read';
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001304','participant','active');raise exception 'unrelated enrollment';exception when insufficient_privilege then null;end;
 begin perform public.assign_master_to_cohort(cid,'00000000-0000-4000-8000-000000001303');raise exception 'unrelated administration';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001304',true);
do $$ begin
 begin perform public.enroll_user((select id from m310_ids where label='cohort'),'00000000-0000-4000-8000-000000001304','participant','active');raise exception 'Student self enrollment';exception when insufficient_privilege then null;end;
 assert not public.can_manage_enrollment((select id from m310_ids where label='cohort'),'participant'),'Student not instructor';
end $$;
reset role;
-- Temporary grants ensure these checks exercise RLS, not merely missing privileges.
grant insert,update,delete on public.enrollments to authenticated;
set local role authenticated;
do $$ declare n integer; begin
 begin insert into public.enrollments(cohort_id,user_id,enrollment_role,status) values((select id from m310_ids where label='unrelated'),'00000000-0000-4000-8000-000000001304','participant','active');raise exception 'direct self enrollment';exception when insufficient_privilege then null;end;
 update public.enrollments set status='active' where user_id='00000000-0000-4000-8000-000000001304';get diagnostics n=row_count;assert n=0,'M3.10 09/14 direct RLS update denied';
 delete from public.enrollments;get diagnostics n=row_count;assert n=0,'RLS history deletion denied';
end $$;
reset role;
revoke insert,update,delete on public.enrollments from authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001301',true);
select public.remove_enrollment((select id from m310_ids where label='master-1304'));
select public.transition_enrollment((select id from m310_ids where label='master-1305'),'withdrawn');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001304',true);
do $$ begin
 assert not public.has_active_enrollment((select id from m310_ids where label='cohort')) and not public.has_enrollment_read_access((select id from m310_ids where label='cohort')),'M3.10 11 removed access revoked';
 assert (select count(*) from public.enrollments)=2,'history preserved';
 assert not exists(select 1 from public.cohorts where id=(select id from m310_ids where label='cohort')),'removed cohort hidden';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001305',true);
do $$ begin assert not public.has_active_enrollment((select id from m310_ids where label='cohort')) and not public.has_enrollment_read_access((select id from m310_ids where label='cohort')),'M3.10 12 withdrawn not active';end $$;
reset role;
update public.role_assignments set status='inactive' where id=(select primary_master_assignment_id from public.cohorts where id=(select id from m310_ids where label='cohort'));
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001302',true);
do $$ begin
 assert not public.can_manage_enrollment((select id from m310_ids where label='cohort'),'participant'),'M3.10 15 primary pointer is not authorization';
 assert not exists(select 1 from public.cohorts where id=(select id from m310_ids where label='cohort')),'invalid scoped Master RLS denied';
 begin perform public.enroll_user((select id from m310_ids where label='cohort'),'00000000-0000-4000-8000-000000001304','participant','active');raise exception 'primary-only bypass';exception when insufficient_privilege then null;end;
end $$;
reset role;
insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000001320','00000000-0000-4000-8000-000000000601','M3.10 isolated v2 fixture','approved');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001301',true);
select public.set_current_curriculum('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000001320');
do $$ begin assert not exists(select 1 from public.cohorts where curriculum_version_id<>'00000000-0000-4000-8000-000000000602'),'M3.10 13 curriculum history unchanged';end $$;
-- Final M3 hardening negatives use real RPC identities, not UI absence.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001304',true);
do $$ declare cid uuid; begin
 select id into cid from m310_ids where label='cohort';
 begin perform public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Student attack','2026-10-01',null,'00000000-0000-4000-8000-000000001304','planned','{}');raise exception 'Student create';exception when insufficient_privilege then null;end;
 begin perform public.transition_curriculum('00000000-0000-4000-8000-000000000602','retired');raise exception 'Student curriculum';exception when insufficient_privilege then null;end;
 begin perform public.set_current_curriculum('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000001320');raise exception 'Student current pointer';exception when insufficient_privilege then null;end;
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001306','participant','active');raise exception 'Student enroll another';exception when insufficient_privilege then null;end;
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001304','instructor','active');raise exception 'fake instructor role';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001303',true);
do $$ begin
 begin perform public.update_cohort((select id from m310_ids where label='cohort'),'Cross cohort attack','2026-10-01',null,'00000000-0000-4000-8000-000000001303','planned','{}');raise exception 'Master updates unrelated';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 begin delete from public.curriculum_versions where id='00000000-0000-4000-8000-000000000602';raise exception 'Historical curriculum deletion';exception when check_violation or foreign_key_violation then null;end;
end $$;
set constraints primary_master_relationship immediate;
rollback;
\echo M3.10 acceptance 01-15 PASS: Admin and Primary Master four-student enrollment, isolation, lifecycle, history, direct RLS and valid scoped identity
