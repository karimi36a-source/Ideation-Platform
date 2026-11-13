\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000001001','cohort-admin@example.test'),
 ('00000000-0000-4000-8000-000000001002','cohort-master@example.test'),
 ('00000000-0000-4000-8000-000000001003','cohort-new-master@example.test'),
 ('00000000-0000-4000-8000-000000001004','cohort-blocked@example.test');
select public.provision_user_profile(id,'active') from auth.users where id in ('00000000-0000-4000-8000-000000001001','00000000-0000-4000-8000-000000001002','00000000-0000-4000-8000-000000001003','00000000-0000-4000-8000-000000000001');
select public.provision_user_profile('00000000-0000-4000-8000-000000001004','suspended');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
 ('00000000-0000-4000-8000-000000001001','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000001001'),
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000001001');
create temporary table cohort_ids(label text primary key,id uuid);
grant select,insert on cohort_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001001',true);
do $$ declare r jsonb; n integer; begin
 r:=public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Professional Course fixture','2026-10-01',null,'00000000-0000-4000-8000-000000001002','planned','{}');
 insert into cohort_ids values('a',(r->>'id')::uuid);
 assert r->>'status'='planned' and r->>'curriculum_version_id'='00000000-0000-4000-8000-000000000602' and r->>'primary_master_assignment_id' is not null,'Admin creation';
 r:=public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Unrelated fixture','2026-10-01','2026-10-02','00000000-0000-4000-8000-000000001003','active','{}');insert into cohort_ids values('b',(r->>'id')::uuid);
 select count(*) into n from public.cohorts;
 begin perform public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Invalid dates','2026-10-02','2026-10-01','00000000-0000-4000-8000-000000001002','planned','{}');raise exception 'bad dates';exception when check_violation then null;end;
 begin perform public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Missing user','2026-10-01',null,'00000000-0000-4000-8000-000000001099','planned','{}');raise exception 'invalid Master';exception when invalid_parameter_value then null;end;
 begin perform public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Blocked user','2026-10-01',null,'00000000-0000-4000-8000-000000001004','planned','{}');raise exception 'suspended Master';exception when invalid_parameter_value then null;end;
 assert (select count(*) from public.cohorts)=n,'failed create leaves no cohort';
end $$;
reset role;
set constraints primary_master_relationship immediate;
do $$ begin
 assert (select count(*) from public.role_assignments a join public.cohorts c on c.primary_master_assignment_id=a.id where a.user_id=c.primary_master_id and a.cohort_id=c.id and a.status='active' and a.assigned_by='00000000-0000-4000-8000-000000001001' and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null)=2,'atomic exact MASTER grants';
end $$;
-- Existing unrelated grant for the old Master must survive reassignment.
insert into public.role_assignments(id,user_id,role_id,cohort_id,starts_at,assigned_by)
select '00000000-0000-4000-8000-000000001090','00000000-0000-4000-8000-000000001002','00000000-0000-4000-8000-000000000102',id,now()-interval '1 day','00000000-0000-4000-8000-000000001001' from cohort_ids where label='b';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001002',true);
do $$ declare cid uuid; begin
 select id into cid from cohort_ids where label='a';
 assert public.has_active_role_in_cohort('MASTER',cid),'assigned Master';assert (select count(*) from public.cohorts)=2,'explicit grants read only';
 begin perform public.update_cohort(cid,'Attack','2026-10-01',null,'00000000-0000-4000-8000-000000001002','active','{}');raise exception 'Master mutation';exception when insufficient_privilege then null;end;
 begin update public.cohorts set name='Attack';raise exception 'direct mutation';exception when insufficient_privilege then null;end;
end $$;
-- New Master initially holds B only: A must be invisible.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001003',true);
do $$ begin
 assert (select count(*) from public.cohorts)=1,'unrelated Master scope';assert not exists(select 1 from public.cohorts where id=(select id from cohort_ids where label='a')),'cohort A hidden';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$ begin
 assert (select count(*) from public.cohorts)=0,'Student isolation';
 begin perform public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Attack','2026-10-01',null,'00000000-0000-4000-8000-000000000001','planned','{}');raise exception 'Student creation';exception when insufficient_privilege then null;end;
 begin perform public.update_cohort((select id from cohort_ids where label='a'),'Attack','2026-10-01',null,'00000000-0000-4000-8000-000000000001','active','{}');raise exception 'Student assignment';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001001',true);
do $$ declare cid uuid; old_assignment uuid; r jsonb; begin
 select id into cid from cohort_ids where label='a';select primary_master_assignment_id into old_assignment from public.cohorts where id=cid;
 -- Constraint failure after assignment changes must roll the entire RPC back.
 begin perform public.update_cohort(cid,'Bad','2026-10-02','2026-10-01','00000000-0000-4000-8000-000000001003','active','{}');raise exception 'invalid reassignment dates';exception when check_violation then null;end;
 assert (select primary_master_id from public.cohorts where id=cid)='00000000-0000-4000-8000-000000001002','atomic failed reassignment';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001002',true);
 assert public.has_active_role_in_cohort('MASTER',cid),'failed reassignment preserves old access';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001003',true);
 assert not public.has_active_role_in_cohort('MASTER',cid),'failed reassignment adds no new scope';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001001',true);
 r:=public.update_cohort(cid,'Updated','2026-10-01',null,'00000000-0000-4000-8000-000000001003','active','{}');
 assert r->>'primary_master_id'='00000000-0000-4000-8000-000000001003' and (r->>'primary_master_assignment_id')::uuid<>old_assignment,'new tracked Master';
 r:=public.update_cohort(cid,'Updated','2026-10-01',null,'00000000-0000-4000-8000-000000001003','completed','{}');
 assert r->>'status'='completed','same Master retry updates metadata';
end $$;
reset role;
do $$ declare cid uuid; begin
 select id into cid from cohort_ids where label='a';
 assert (select count(*) from public.role_assignments where cohort_id=cid and user_id='00000000-0000-4000-8000-000000001002' and status='inactive')=1,'old relationship deactivated';
 assert (select count(*) from public.role_assignments where cohort_id=cid and user_id='00000000-0000-4000-8000-000000001003' and status='active')=1,'retry preserves one grant';
 assert (select status from public.role_assignments where id='00000000-0000-4000-8000-000000001090')='active','unrelated grant preserved';
 begin update public.cohorts set primary_master_assignment_id=null where id=cid;raise exception 'missing tracked relationship';exception when check_violation then null;end;
 begin delete from public.cohorts where id=cid;raise exception 'destructive history';exception when check_violation then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001002',true);
do $$ begin assert not public.has_active_role_in_cohort('MASTER',(select id from cohort_ids where label='a')),'old scope revoked';assert (select count(*) from public.cohorts)=1,'old retains unrelated scope';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001003',true);
do $$ begin assert public.has_active_role_in_cohort('MASTER',(select id from cohort_ids where label='a')),'new scope available';assert (select count(*) from public.cohorts)=2,'new sees A and B';end $$;
reset role;
-- Validity restrictions apply to the real cohort RLS boundary too.
update public.role_assignments set status='inactive' where id=(select primary_master_assignment_id from public.cohorts where id=(select id from cohort_ids where label='a'));
set local role authenticated;
do $$ begin assert not exists(select 1 from public.cohorts where id=(select id from cohort_ids where label='a')),'inactive Master RLS';end $$;
reset role;
update public.role_assignments set status='active',starts_at=now()+interval '1 day' where id=(select primary_master_assignment_id from public.cohorts where id=(select id from cohort_ids where label='a'));
set local role authenticated;
do $$ begin assert not exists(select 1 from public.cohorts where id=(select id from cohort_ids where label='a')),'future Master RLS';end $$;
reset role;
update public.role_assignments set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where id=(select primary_master_assignment_id from public.cohorts where id=(select id from cohort_ids where label='a'));
set local role authenticated;
do $$ begin assert not exists(select 1 from public.cohorts where id=(select id from cohort_ids where label='a')),'expired Master RLS';end $$;
reset role;
update public.role_assignments set starts_at=now(),ends_at=null where id=(select primary_master_assignment_id from public.cohorts where id=(select id from cohort_ids where label='a'));
insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000001010','00000000-0000-4000-8000-000000000601','Cohort v2 fixture','approved');
insert into public.programs(id,organization_id,name,code,program_type) values('00000000-0000-4000-8000-000000001011','00000000-0000-4000-8000-000000000501','Other program fixture','COHORT_OTHER','professional_course');
insert into public.curriculum_versions(id,program_id,version_label) values('00000000-0000-4000-8000-000000001012','00000000-0000-4000-8000-000000000601','Draft fixture');
insert into public.organizations(id,name,slug) values('00000000-0000-4000-8000-000000001018','Other cohort organization','cohort-other');
insert into public.programs(id,organization_id,name,code,program_type) values('00000000-0000-4000-8000-000000001019','00000000-0000-4000-8000-000000001018','Other org program','COHORT_EXTERNAL','professional_course');
insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000001020','00000000-0000-4000-8000-000000001019','Other org approved','approved');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001001',true);
do $$ begin
 begin perform public.create_cohort('00000000-0000-4000-8000-000000001019','00000000-0000-4000-8000-000000001020','Cross org','2026-10-01',null,'00000000-0000-4000-8000-000000001003','planned','{}');raise exception 'Admin outside organization';exception when insufficient_privilege then null;end;
 begin perform public.create_cohort('00000000-0000-4000-8000-000000001011','00000000-0000-4000-8000-000000000602','Wrong pairing','2026-10-01',null,'00000000-0000-4000-8000-000000001003','planned','{}');raise exception 'pairing';exception when foreign_key_violation then null;end;
 begin perform public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000001012','Draft','2026-10-01',null,'00000000-0000-4000-8000-000000001003','planned','{}');raise exception 'draft';exception when check_violation then null;end;
 perform public.set_current_curriculum('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000001010');
 perform public.transition_curriculum('00000000-0000-4000-8000-000000000602','retired');
 assert not exists(select 1 from public.cohorts where curriculum_version_id<>'00000000-0000-4000-8000-000000000602'),'fixed history after current changes and retirement';
 begin perform public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Retired','2026-10-01',null,'00000000-0000-4000-8000-000000001003','planned','{}');raise exception 'retired';exception when check_violation then null;end;
 perform public.update_cohort((select id from cohort_ids where label='a'),'Archived history','2026-10-01',null,'00000000-0000-4000-8000-000000001003','archived','{}');
end $$;
reset role;
do $$ begin begin update public.cohorts set curriculum_version_id='00000000-0000-4000-8000-000000001010';raise exception 'rewrite cohort curriculum';exception when check_violation then null;end;end $$;
set local role anon;
do $$ begin begin perform * from public.cohorts;raise exception 'anonymous';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$ begin
 assert (select relrowsecurity from pg_class where oid='public.cohorts'::regclass),'cohort RLS';
 assert not has_table_privilege('authenticated','public.cohorts','INSERT,UPDATE,DELETE'),'no direct writes';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.create_cohort(uuid,uuid,text,date,date,uuid,public.cohort_status,jsonb)'::regprocedure),'safe create';
 assert not has_function_privilege('service_role','public.update_cohort(uuid,text,date,date,uuid,public.cohort_status,jsonb)','EXECUTE'),'service key not Admin';
end $$;
-- Explicit M3.8 operation restores revoked relationship grants, without rewriting history.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001001',true);
update public.role_assignments set status='inactive' where id=(select primary_master_assignment_id from public.cohorts where id=(select id from cohort_ids where label='a'));
set local role authenticated;
do $$ declare c jsonb; retry jsonb; begin
 c:=public.assign_master_to_cohort((select id from cohort_ids where label='a'),'00000000-0000-4000-8000-000000001003');
 retry:=public.assign_master_to_cohort((select id from cohort_ids where label='a'),'00000000-0000-4000-8000-000000001003');
 assert c=retry,'same valid Master retry is a complete no-op';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001003',true);
 assert public.has_active_role_in_cohort('MASTER',(select id from cohort_ids where label='a')),'restored exact cohort grant';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
 begin perform public.assign_master_to_cohort((select id from cohort_ids where label='a'),'00000000-0000-4000-8000-000000000001');raise exception 'Student assignment';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Future and expired grants cannot authorize, and explicit Admin assignment repairs them.
do $$ declare mode integer; cid uuid; prior uuid; r jsonb; begin
 select id into cid from cohort_ids where label='a';
 for mode in 1..2 loop
  select primary_master_assignment_id into prior from public.cohorts where id=cid;
  if mode=1 then update public.role_assignments set starts_at=now()+interval '1 day' where id=prior;
  else update public.role_assignments set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where id=prior;end if;
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001003',true);
  assert not public.has_active_role_in_cohort('MASTER',cid),'invalid temporal grant denied';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001001',true);
  r:=public.assign_master_to_cohort(cid,'00000000-0000-4000-8000-000000001003');
  assert (r->>'primary_master_assignment_id')::uuid<>prior,'new grant replaces invalid history';
  assert (select status from public.role_assignments where id=prior)='inactive','invalid history retained';
 end loop;
 assert (select status from public.role_assignments where id='00000000-0000-4000-8000-000000001090')='active','unrelated grant untouched';
end $$;
do $$ begin
 assert not has_function_privilege('anon','public.assign_master_to_cohort(uuid,uuid)','EXECUTE'),'anonymous denial';
 assert not has_function_privilege('service_role','public.assign_master_to_cohort(uuid,uuid)','EXECUTE'),'browser cannot use privileged service path';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.assign_master_to_cohort(uuid,uuid)'::regprocedure),'fixed safe definer';
end $$;
rollback;
\echo Cohort atomic creation/reassignment, immutable curriculum, Master isolation and RLS PASS
