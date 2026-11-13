\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000001101','enrollment-admin@example.test'),
 ('00000000-0000-4000-8000-000000001102','enrollment-master@example.test'),
 ('00000000-0000-4000-8000-000000001103','enrollment-other-master@example.test'),
 ('00000000-0000-4000-8000-000000001104','enrollment-a@example.test'),
 ('00000000-0000-4000-8000-000000001105','enrollment-b@example.test'),
 ('00000000-0000-4000-8000-000000001106','enrollment-invited@example.test'),
 ('00000000-0000-4000-8000-000000001108','enrollment-nonprimary@example.test');
select public.provision_user_profile(id,'active') from auth.users where id in ('00000000-0000-4000-8000-000000001101','00000000-0000-4000-8000-000000001102','00000000-0000-4000-8000-000000001103','00000000-0000-4000-8000-000000001104','00000000-0000-4000-8000-000000001105','00000000-0000-4000-8000-000000001108');
select public.provision_user_profile('00000000-0000-4000-8000-000000001106','invited');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000001101','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000001101');
create temporary table enrollment_ids(label text primary key,id uuid);grant select,insert on enrollment_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001101',true);
insert into enrollment_ids select 'cohortA',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Enrollment A','2026-10-01',null,'00000000-0000-4000-8000-000000001102','planned','{}')->>'id')::uuid;
insert into enrollment_ids select 'cohortB',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Enrollment B','2026-10-01',null,'00000000-0000-4000-8000-000000001103','planned','{}')->>'id')::uuid;
do $$ declare cid uuid; r jsonb; begin
 select id into cid from enrollment_ids where label='cohortA';
 r:=public.enroll_user(cid,'00000000-0000-4000-8000-000000001104','participant','active');insert into enrollment_ids values('activeA',(r->>'id')::uuid);
 assert r->>'joined_at' is not null and r->>'completed_at' is null,'active timestamps';
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001104','participant','active');raise exception 'duplicate active';exception when unique_violation then null;end;
 r:=public.enroll_user(cid,'00000000-0000-4000-8000-000000001105','participant','invited');insert into enrollment_ids values('inviteB',(r->>'id')::uuid);
 assert r->>'joined_at' is null and r->>'completed_at' is null,'invited timestamps';
 r:=public.enroll_user(cid,'00000000-0000-4000-8000-000000001102','instructor','active');insert into enrollment_ids values('instructor',(r->>'id')::uuid);
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001104','instructor','active');raise exception 'non-Master instructor';exception when invalid_parameter_value then null;end;
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001106','participant','active');raise exception 'inactive profile active enrollment';exception when invalid_parameter_value then null;end;
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001199','participant','active');raise exception 'missing user';exception when invalid_parameter_value then null;end;
end $$;
reset role;
insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by) select '00000000-0000-4000-8000-000000001108','00000000-0000-4000-8000-000000000102',id,'00000000-0000-4000-8000-000000001101' from enrollment_ids where label='cohortA';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001104',true);
do $$ declare cid uuid; begin
 select id into cid from enrollment_ids where label='cohortA';
 assert public.has_active_enrollment(cid) and public.has_enrollment_read_access(cid),'active course context';
 assert (select count(*) from public.cohorts)=1,'learner cohort isolation';assert (select count(*) from public.enrollments)=1,'own enrollment only';
 assert not public.can_manage_enrollment(cid,'participant'),'metadata not administration';
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001104','participant','active');raise exception 'self enroll RPC';exception when insufficient_privilege then null;end;
 begin perform public.remove_enrollment((select id from enrollment_ids where label='activeA'));raise exception 'self remove';exception when insufficient_privilege then null;end;
 begin perform public.transition_enrollment((select id from enrollment_ids where label='activeA'),'completed');raise exception 'self completion';exception when insufficient_privilege then null;end;
 begin perform public.has_enrollment_read_access(cid,'00000000-0000-4000-8000-000000001105'::uuid);raise exception 'caller identity helper';exception when undefined_function then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001105',true);
do $$ begin assert not public.has_enrollment_read_access((select id from enrollment_ids where label='cohortA')),'pending invitation no access';assert (select count(*) from public.cohorts)=0,'pending cohort hidden';assert (select count(*) from public.enrollments)=1,'own pending history';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001103',true);
do $$ begin begin perform public.enroll_user((select id from enrollment_ids where label='cohortA'),'00000000-0000-4000-8000-000000001105','participant','active');raise exception 'unrelated Master';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001108',true);
do $$ begin begin perform public.remove_enrollment((select id from enrollment_ids where label='activeA'));raise exception 'assigned nonprimary Master';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001102',true);
do $$ declare cid uuid; r jsonb; begin
 select id into cid from enrollment_ids where label='cohortA';
 assert public.can_manage_enrollment(cid,'participant') and not public.can_manage_enrollment(cid,'instructor'),'Primary Master participant only';
 begin perform public.remove_enrollment((select id from enrollment_ids where label='instructor'));raise exception 'Master instructor removal';exception when insufficient_privilege then null;end;
 begin perform public.enroll_user(cid,'00000000-0000-4000-8000-000000001102','instructor','invited');raise exception 'Master instructor creation';exception when insufficient_privilege then null;end;
 begin perform public.transition_enrollment((select id from enrollment_ids where label='inviteB'),'active');raise exception 'Master trusted activation';exception when insufficient_privilege then null;end;
 r:=public.remove_enrollment((select id from enrollment_ids where label='activeA'));assert r->>'status'='removed' and r->>'joined_at' is not null and r->>'completed_at' is null,'Primary removal retains history';
 r:=public.enroll_user(cid,'00000000-0000-4000-8000-000000001104','participant','active');insert into enrollment_ids values('reenrolledA',(r->>'id')::uuid);
 assert (r->>'id')::uuid<>(select id from enrollment_ids where label='activeA'),'re-enrollment new row';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001101',true);
do $$ declare r jsonb; completed timestamptz; begin
 r:=public.transition_enrollment((select id from enrollment_ids where label='inviteB'),'active');assert r->>'joined_at' is not null and r->>'completed_at' is null,'explicit activation';
 r:=public.transition_enrollment((select id from enrollment_ids where label='reenrolledA'),'completed');assert r->>'completed_at' is not null,'completion timestamp';
 begin perform public.transition_enrollment((select id from enrollment_ids where label='activeA'),'active');raise exception 'overwrite removed history';exception when check_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001104',true);
do $$ begin assert not public.has_active_enrollment((select id from enrollment_ids where label='cohortA')) and public.has_enrollment_read_access((select id from enrollment_ids where label='cohortA')),'completed read only';assert (select count(*) from public.enrollments)=2,'own historical rows';assert not public.can_manage_enrollment((select id from enrollment_ids where label='cohortA'),'participant'),'completed no privilege';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001101',true);
do $$ declare r jsonb; completed timestamptz; begin
 select completed_at into completed from public.enrollments where id=(select id from enrollment_ids where label='reenrolledA');
 r:=public.remove_enrollment((select id from enrollment_ids where label='reenrolledA'));assert (r->>'completed_at')::timestamptz=completed,'removal preserves old completion';
 r:=public.transition_enrollment((select id from enrollment_ids where label='inviteB'),'withdrawn');assert r->>'completed_at' is null and r->>'joined_at' is not null,'voluntary withdrawal retains participation';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001104',true);
do $$ begin assert not public.has_enrollment_read_access((select id from enrollment_ids where label='cohortA')),'removed no access';assert (select count(*) from public.enrollments)=2,'removed own history remains';assert (select count(*) from public.cohorts)=0,'removed cohort hidden';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001105',true);
do $$ begin assert not public.has_enrollment_read_access((select id from enrollment_ids where label='cohortA')),'withdrawn no access';end $$;
reset role;
-- Prove RLS itself denies client writes even if table grants are temporarily added.
grant insert,update,delete on public.enrollments to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001104',true);
do $$ declare n integer; begin
 update public.enrollments set status='active';get diagnostics n=row_count;assert n=0,'direct self activation denied by RLS';
 delete from public.enrollments;get diagnostics n=row_count;assert n=0,'direct history deletion denied by RLS';
 begin insert into public.enrollments(cohort_id,user_id,enrollment_role,status) values((select id from enrollment_ids where label='cohortA'),'00000000-0000-4000-8000-000000001104','instructor','active');raise exception 'direct self elevation';exception when insufficient_privilege then null;end;
end $$;
reset role;revoke insert,update,delete on public.enrollments from authenticated;
do $$ begin
 assert (select count(*) from public.enrollments where user_id='00000000-0000-4000-8000-000000001104')=2,'all A history preserved';
 assert exists(select 1 from auth.users where id='00000000-0000-4000-8000-000000001104') and exists(select 1 from public.users where id='00000000-0000-4000-8000-000000001104'),'account untouched';
 begin delete from public.enrollments;raise exception 'owner destructive delete';exception when check_violation then null;end;
 begin update public.enrollments set user_id='00000000-0000-4000-8000-000000001105' where id=(select id from enrollment_ids where label='activeA');raise exception 'history identity';exception when check_violation then null;end;
 begin update public.enrollments set joined_at=now()-interval '1 day' where id=(select id from enrollment_ids where label='activeA');raise exception 'rewrite historical join';exception when check_violation then null;end;
 begin insert into public.enrollments(cohort_id,user_id,enrollment_role,status) values((select id from enrollment_ids where label='cohortA'),'00000000-0000-4000-8000-000000001199','participant','active');raise exception 'user FK';exception when foreign_key_violation then null;end;
 begin insert into public.enrollments(cohort_id,user_id,enrollment_role,status) values('00000000-0000-4000-8000-000000001199','00000000-0000-4000-8000-000000001104','participant','active');raise exception 'cohort FK';exception when foreign_key_violation then null;end;
 assert (select relrowsecurity from pg_class where oid='public.enrollments'::regclass),'enrollment RLS';
 assert (select count(*) from pg_constraint where conrelid='public.enrollments'::regclass and contype='f' and confdeltype='r')=2,'restricted FKs';
 assert not has_table_privilege('authenticated','public.enrollments','INSERT,UPDATE,DELETE'),'no generic writes';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.has_enrollment_read_access(uuid)'::regprocedure),'safe identity-bound definer';
 assert not has_function_privilege('service_role','public.enroll_user(uuid,uuid,public.enrollment_role,public.enrollment_status)','EXECUTE'),'service key not enrollment authority';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001101',true);
do $$ declare cid uuid; r jsonb; completed_id uuid; begin
 select id into cid from enrollment_ids where label='cohortA';
 r:=public.enroll_user(cid,'00000000-0000-4000-8000-000000001104','participant','active');completed_id:=(r->>'id')::uuid;
 perform public.transition_enrollment(completed_id,'completed');
 r:=public.enroll_user(cid,'00000000-0000-4000-8000-000000001104','participant','active');
 assert exists(select 1 from public.enrollments where id=completed_id and status='completed' and completed_at is not null),'completed history survives re-enrollment';
 perform public.remove_enrollment((r->>'id')::uuid);
 r:=public.enroll_user(cid,'00000000-0000-4000-8000-000000001105','participant','active');
 assert exists(select 1 from public.enrollments where id=(select id from enrollment_ids where label='inviteB') and status='withdrawn'),'withdrawn history survives re-enrollment';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001104',true);
do $$ begin assert not public.has_active_enrollment((select id from enrollment_ids where label='cohortA')) and public.has_enrollment_read_access((select id from enrollment_ids where label='cohortA')),'older completed row gives history only, never active access';end $$;
reset role;
set local role anon;
do $$ begin begin perform * from public.enrollments;raise exception 'anonymous records';exception when insufficient_privilege then null;end;begin perform public.has_enrollment_read_access('00000000-0000-4000-8000-000000001199'::uuid);raise exception 'anonymous helper';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
\echo Enrollment lifecycle, Primary Master limits, own history, duplicate prevention and direct RLS PASS
