\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||n)::uuid,'m163-'||n||'@example.test' from generate_series(160301,160309) g(n0) cross join lateral(select lpad(n0::text,12,'0') n) x;
select public.provision_user_profile(id,'active') from auth.users where email like 'm163-%@example.test';
insert into public.cohorts(id,program_id,curriculum_version_id,name,start_date,status,primary_master_id) values
('00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','M16.3 Cohort A','2026-11-11','active','00000000-0000-4000-8000-000000160301'),
('00000000-0000-4000-8000-000000160321','00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','M16.3 Cohort B','2026-11-11','active','00000000-0000-4000-8000-000000160304');
insert into public.role_assignments(id,user_id,role_id,cohort_id,assigned_by) values
('00000000-0000-4000-8000-000000160330','00000000-0000-4000-8000-000000160301','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000160301'),
('00000000-0000-4000-8000-000000160331','00000000-0000-4000-8000-000000160304','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000160321','00000000-0000-4000-8000-000000160301'),
('00000000-0000-4000-8000-000000160332','00000000-0000-4000-8000-000000160307','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000160301'),
('00000000-0000-4000-8000-000000160333','00000000-0000-4000-8000-000000160308','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000160301');
update public.cohorts set primary_master_assignment_id=case when name='M16.3 Cohort A' then '00000000-0000-4000-8000-000000160330'::uuid else '00000000-0000-4000-8000-000000160331'::uuid end where name like 'M16.3 Cohort %';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
('00000000-0000-4000-8000-000000160305','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000160301'),
('00000000-0000-4000-8000-000000160306','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000160301'),
('00000000-0000-4000-8000-000000160309','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000160301');
update public.role_assignments set status='inactive' where id='00000000-0000-4000-8000-000000160332';
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000160308';
insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by,starts_at,ends_at) values
('00000000-0000-4000-8000-000000160302','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000160301',now()-interval '2 days',now()-interval '1 day'),
('00000000-0000-4000-8000-000000160303','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000160301',now()+interval '1 day',null);
insert into public.workspaces(id,workspace_type,name,owner_user_id,cohort_id,created_by,updated_by) values('00000000-0000-4000-8000-000000160340','CASE_STUDY','M16.3 case','00000000-0000-4000-8000-000000160301','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000160301','00000000-0000-4000-8000-000000160301');
insert into public.development_projects(id,name,project_type,owner_user_id,primary_workspace_id) values('00000000-0000-4000-8000-000000160341','M16.3 case project','instructor_case_study','00000000-0000-4000-8000-000000160301','00000000-0000-4000-8000-000000160340');
insert into public.project_program_links(project_id,program_id,cohort_id) values('00000000-0000-4000-8000-000000160341','00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000160320');
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id) values('00000000-0000-4000-8000-000000160342','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000160341','00000000-0000-4000-8000-000000160340');
set constraints all immediate;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000160301',true);
do $$declare c jsonb;begin
 c:=public.authorize_master_live_room('00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000702','00000000-0000-4000-8000-000000160342');
 assert c->>'actorId'='00000000-0000-4000-8000-000000160301' and c->>'roomKey' ~ '^fici-[a-f0-9]{64}$';
 begin perform public.authorize_master_live_room('00000000-0000-4000-8000-000000160321','00000000-0000-4000-8000-000000000702');raise exception 'Foreign Cohort allowed';exception when insufficient_privilege then null;end;
 begin perform public.authorize_master_live_room('00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000160342');raise exception 'Wrong Activity Session allowed';exception when insufficient_privilege then null;end;
 begin perform public.authorize_master_live_room('00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000702','00000000-0000-4000-8000-999999999999');raise exception 'Guessed Activity allowed';exception when insufficient_privilege then null;end;
 begin perform public.master_live_room_mapping('REUSE_OR_CREATE','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000702',null,c->>'roomKey','00000000-0000-4000-8000-000000160301');raise exception 'Client registered room';exception when insufficient_privilege then null;end;
end$$;
do $$declare n integer;begin
 foreach n in array array[160302,160303,160304,160305,160307,160308,160309] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  begin perform public.authorize_master_live_room('00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000702');raise exception 'Unauthorized actor allowed %',n;exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000160306',true);
 assert public.authorize_master_live_room('00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000702')->>'actorId'='00000000-0000-4000-8000-000000160306';
end$$;
reset role;
do $$begin
 assert not has_function_privilege('authenticated','public.master_live_room_mapping(text,uuid,uuid,uuid,text,uuid)','EXECUTE');
 assert not has_function_privilege('anon','public.authorize_master_live_room(uuid,uuid,uuid)','EXECUTE');
 assert not has_function_privilege('authenticated','private.master_live_room_context(uuid,uuid,uuid,uuid)','EXECUTE');
 assert not exists(select 1 from public.live_session_rooms),'authorization alone creates no mapping';
end$$;
commit;
\echo M16.3 context/assigned-Master/scoped-Admin/Student-revoked-inactive-denial/direct-RPC-boundary PASS
