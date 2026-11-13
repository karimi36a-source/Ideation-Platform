\set ON_ERROR_STOP on
begin;
create temporary table activity_snapshot as select * from public.activity_definitions;
select public.seed_professional_activity();select public.seed_professional_activity();
do $$ begin
 assert (select count(*) from public.activity_definitions)=1,'minimum seed';
 assert exists(select 1 from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id where a.name='SCAMPER Example Set' and a.method_type='scamper' and a.status='active' and s.session_number=2 and s.curriculum_version_id='00000000-0000-4000-8000-000000000602' and a.requires_review and not a.requires_approval and a.configuration='{}'::jsonb and a.ai_role_code is null and a.completion_rule is null),'seed parent and metadata';
 assert not exists((select * from public.activity_definitions except select * from activity_snapshot) union all (select * from activity_snapshot except select * from public.activity_definitions)),'idempotent all fields';
 begin update public.activity_definitions set name='Attack';raise exception 'approved rewrite';exception when check_violation then null;end;
 begin update public.activity_definitions set configuration='{"unexpected":true}';raise exception 'approved configuration rewrite';exception when check_violation then null;end;
 begin delete from public.activity_definitions;raise exception 'approved delete';exception when check_violation then null;end;
 begin insert into public.activity_definitions(session_definition_id,name,method_type,sequence) values('00000000-0000-4000-8000-000000000702','Attack','scamper',2);raise exception 'approved append';exception when check_violation then null;end;
end $$;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000000811','activity-admin@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000000811','active');select public.provision_user_profile('00000000-0000-4000-8000-000000000001','active');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
 ('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000811'),
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000811');
insert into public.curriculum_versions(id,program_id,version_label) values('00000000-0000-4000-8000-000000000812','00000000-0000-4000-8000-000000000601','Activity draft fixture');
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence) values('00000000-0000-4000-8000-000000000813','00000000-0000-4000-8000-000000000812',1,'Fixture','','Fixture',1);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$ begin
 assert (select count(*) from public.activity_definitions)=0,'Student read denied';
 begin update public.activity_definitions set name='Attack';raise exception 'Student direct mutation';exception when insufficient_privilege then null;end;
 begin perform public.manage_activity('00000000-0000-4000-8000-000000000813',null,'{"name":"Attack","method_type":"scamper","sequence":1}');raise exception 'Student command';exception when insufficient_privilege then null;end;
 begin perform public.seed_professional_activity();raise exception 'browser seed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000811',true);
do $$ declare a uuid; b uuid; r jsonb; begin
 begin perform public.manage_activity('00000000-0000-4000-8000-000000000702',null,'{"name":"Attack","method_type":"scamper","sequence":2}');raise exception 'Admin approved append';exception when insufficient_privilege then null;end;
 r:=public.manage_activity('00000000-0000-4000-8000-000000000813',null,'{"name":"First fixture","method_type":"scamper","sequence":1}');a:=(r->>'id')::uuid;
 assert r->>'session_definition_id'='00000000-0000-4000-8000-000000000813' and r->>'requires_review'='false' and r->>'requires_approval'='false' and r->'configuration'='{}'::jsonb and r->>'description' is null,'parent/defaults';
 r:=public.manage_activity('00000000-0000-4000-8000-000000000813',null,'{"name":"Second fixture","method_type":"reflection","sequence":2}');b:=(r->>'id')::uuid;
 assert (select array_agg(id order by sequence) from public.activity_definitions where session_definition_id='00000000-0000-4000-8000-000000000813')=array[a,b],'ordering';
 perform public.manage_activity('00000000-0000-4000-8000-000000000813',a,'{"name":"Edited","method_type":"scamper","sequence":1,"status":"inactive"}');
 begin perform public.manage_activity('00000000-0000-4000-8000-000000000813',null,'{"name":"Duplicate","method_type":"scamper","sequence":1}');raise exception 'duplicate sequence';exception when unique_violation then null;end;
 begin perform public.manage_activity('00000000-0000-4000-8000-000000000813',null,'{"name":"Invalid","method_type":"invented","sequence":3}');raise exception 'invalid method';exception when invalid_text_representation then null;end;
 begin perform public.manage_activity('00000000-0000-4000-8000-000000000813',a,'{"name":"Attack","method_type":"scamper","sequence":1,"user_id":"fake"}');raise exception 'identity input';exception when invalid_parameter_value then null;end;
 perform public.transition_curriculum('00000000-0000-4000-8000-000000000812','approved');
 begin perform public.manage_activity('00000000-0000-4000-8000-000000000813',a,'{"name":"Attack","method_type":"scamper","sequence":1}');raise exception 'approved edit';exception when insufficient_privilege then null;end;
end $$;
reset role;
insert into public.organizations(id,name,slug) values('00000000-0000-4000-8000-000000000814','Other fixture','activity-other');
insert into public.programs(id,organization_id,name,code,program_type) values('00000000-0000-4000-8000-000000000815','00000000-0000-4000-8000-000000000814','Fixture','ACTIVITY_FIXTURE','professional_course');
insert into public.curriculum_versions(id,program_id,version_label) values('00000000-0000-4000-8000-000000000816','00000000-0000-4000-8000-000000000815','Other draft');
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence) values('00000000-0000-4000-8000-000000000817','00000000-0000-4000-8000-000000000816',1,'Fixture','','Fixture',1);
set local role authenticated;
do $$ begin begin perform public.manage_activity('00000000-0000-4000-8000-000000000817',null,'{"name":"Attack","method_type":"scamper","sequence":1}');raise exception 'cross organization';exception when insufficient_privilege then null;end;end $$;
reset role;set local role anon;
do $$ begin begin perform * from public.activity_definitions;raise exception 'anonymous';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$ begin
 assert (select relrowsecurity from pg_class where oid='public.activity_definitions'::regclass),'RLS';
 assert not has_table_privilege('authenticated','public.activity_definitions','INSERT,UPDATE,DELETE'),'no direct mutation';
 assert exists(select 1 from pg_constraint where conrelid='public.activity_definitions'::regclass and confrelid='public.session_definitions'::regclass and contype='f' and confdeltype='r'),'restricted parent FK';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.manage_activity(uuid,uuid,jsonb)'::regprocedure),'safe definer';
 assert not has_function_privilege('service_role','public.manage_activity(uuid,uuid,jsonb)','EXECUTE'),'isolated Admin command';
end $$;
rollback;
\echo Activity seed, ordering, constraints, history, scoped Admin and direct RLS PASS
