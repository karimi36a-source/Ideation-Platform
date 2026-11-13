\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000160201','m162@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000160201','active');
insert into public.cohorts(id,program_id,curriculum_version_id,name,start_date,status,primary_master_id)
values('00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','M16.2 fixture','2026-11-11','active','00000000-0000-4000-8000-000000160201');
insert into public.role_assignments(id,user_id,role_id,cohort_id,assigned_by) values('00000000-0000-4000-8000-000000160205','00000000-0000-4000-8000-000000160201','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000160201');
update public.cohorts set primary_master_assignment_id='00000000-0000-4000-8000-000000160205' where id='00000000-0000-4000-8000-000000160202';
set constraints all immediate;
create temporary table room_results(label text primary key,data jsonb);grant select,insert on room_results to service_role;
set local role service_role;
do $$begin assert public.manage_live_room_mapping('FIND_ACTIVE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY',null,'00000000-0000-4000-8000-000000160201') is null;end$$;
insert into room_results select 'first',public.manage_live_room_mapping('REUSE_OR_CREATE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY','m162-first','00000000-0000-4000-8000-000000160201');
do $$begin assert public.manage_live_room_mapping('FIND_ACTIVE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY',null,'00000000-0000-4000-8000-000000160201')=(select data from room_results where label='first');end$$;
insert into room_results select 'reuse',public.manage_live_room_mapping('REUSE_OR_CREATE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY','m162-ignored','00000000-0000-4000-8000-000000160201');
do $$begin assert (select data from room_results where label='first')=(select data from room_results where label='reuse'),'reuse exact identity/reference/timestamps';end$$;
insert into room_results select 'replace',public.manage_live_room_mapping('REPLACE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY','m162-second','00000000-0000-4000-8000-000000160201',(select (data->>'id')::uuid from room_results where label='first'));
insert into room_results select 'retry',public.manage_live_room_mapping('REPLACE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY','m162-second','00000000-0000-4000-8000-000000160201',(select (data->>'id')::uuid from room_results where label='first'));
do $$begin
 assert (select data from room_results where label='replace')=(select data from room_results where label='retry'),'replacement retry stable';
 begin perform public.manage_live_room_mapping('REPLACE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY','m162-stale','00000000-0000-4000-8000-000000160201',(select (data->>'id')::uuid from room_results where label='first'));raise exception 'Stale replacement succeeded';exception when serialization_failure then null;end;
 -- A failing insert must roll back the preceding expiration.
 begin perform public.manage_live_room_mapping('REPLACE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY','m162-first','00000000-0000-4000-8000-000000160201',(select (data->>'id')::uuid from room_results where label='replace'));raise exception 'Historical ref reused';exception when unique_violation then null;end;
end$$;
reset role;
do $$begin
 assert (select count(*)=2 from public.live_session_rooms),'no partial rows';
 assert exists(select 1 from public.live_session_rooms where provider_room_ref='m162-first' and status='EXPIRED' and ended_at is not null),'history retained';
 assert exists(select 1 from public.live_session_rooms where provider_room_ref='m162-second' and status='ACTIVE' and ended_at is null),'failed replacement rolled back';
 begin insert into public.live_session_rooms(cohort_id,session_definition_id,provider,provider_room_ref,created_by) values('00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY','m162-duplicate','00000000-0000-4000-8000-000000160201');raise exception 'Duplicate active succeeded';exception when unique_violation then null;end;
 begin update public.live_session_rooms set provider_room_ref='overwrite' where provider_room_ref='m162-first';raise exception 'History overwritten';exception when check_violation then null;end;
 begin update public.live_session_rooms set status='ACTIVE',ended_at=null where provider_room_ref='m162-first';raise exception 'History resurrected';exception when check_violation then null;end;
 begin delete from public.live_session_rooms;raise exception 'History deleted';exception when check_violation then null;end;
end$$;
set local role service_role;
insert into room_results select 'expire',public.manage_live_room_mapping('EXPIRE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY',null,'00000000-0000-4000-8000-000000160201',(select (data->>'id')::uuid from room_results where label='replace'));
do $$begin
 assert (select data from room_results where label='expire')=public.manage_live_room_mapping('EXPIRE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY',null,'00000000-0000-4000-8000-000000160201',(select (data->>'id')::uuid from room_results where label='replace')),'expire retry stable';
end$$;
insert into room_results select 'third',public.manage_live_room_mapping('REUSE_OR_CREATE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY','m162-third','00000000-0000-4000-8000-000000160201');
reset role;
-- Existing session from another curriculum must not bind to this Cohort.
insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000160203','00000000-0000-4000-8000-000000000601','M162 foreign','draft');
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence) values('00000000-0000-4000-8000-000000160204','00000000-0000-4000-8000-000000160203',1,'Foreign','','Test',1);
set local role service_role;
do $$begin
 begin perform public.manage_live_room_mapping('REUSE_OR_CREATE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000160204','DAILY','m162-foreign','00000000-0000-4000-8000-000000160201');raise exception 'Foreign curriculum accepted';exception when check_violation then null;end;
 begin perform public.manage_live_room_mapping('REUSE_OR_CREATE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','OTHER','bad','00000000-0000-4000-8000-000000160201');raise exception 'Unknown provider accepted';exception when invalid_parameter_value then null;end;
end$$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000160201',true);
do $$begin
 begin perform * from public.live_session_rooms;raise exception 'Client read mapping';exception when insufficient_privilege then null;end;
 begin perform public.manage_live_room_mapping('REUSE_OR_CREATE','00000000-0000-4000-8000-000000160202','00000000-0000-4000-8000-000000000701','DAILY','forged','00000000-0000-4000-8000-000000160201');raise exception 'Client called internal RPC';exception when insufficient_privilege then null;end;
 begin update public.live_session_rooms set provider_room_ref='forged';raise exception 'Client mutation';exception when insufficient_privilege then null;end;
 begin insert into public.live_session_rooms default values;raise exception 'Client insert';exception when insufficient_privilege then null;end;
 begin delete from public.live_session_rooms;raise exception 'Client delete';exception when insufficient_privilege then null;end;
end$$;
reset role;
do $$declare r text;begin
 foreach r in array array['anon','authenticated'] loop
  assert not has_function_privilege(r,'public.manage_live_room_mapping(text,uuid,uuid,text,text,uuid,uuid)','EXECUTE');
  assert not has_table_privilege(r,'public.live_session_rooms','SELECT,INSERT,UPDATE,DELETE');
 end loop;
 assert (select count(*)=3 from public.live_session_rooms);
 assert (select count(*)=1 from public.live_session_rooms where status='ACTIVE');
 assert (select count(*)=2 from public.live_session_rooms where status='EXPIRED');
 assert not exists(select 1 from information_schema.columns where table_schema='public' and table_name='live_session_rooms' and column_name ~ '(token|key|secret)');
end$$;
rollback;
\echo M16.2 create/reuse/expire/replace/history/scope/direct-client-denial PASS
