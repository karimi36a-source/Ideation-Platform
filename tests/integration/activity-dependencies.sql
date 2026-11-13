\set ON_ERROR_STOP on
begin;
-- Definition-layer regression, independent of runtime evaluation fixtures.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000000911','dependency-admin@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000000911','active');
select public.provision_user_profile('00000000-0000-4000-8000-000000000001','active');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
('00000000-0000-4000-8000-000000000911','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000911');
insert into public.curriculum_versions(id,program_id,version_label) values('00000000-0000-4000-8000-000000000912','00000000-0000-4000-8000-000000000601','Dependency draft fixture');
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence) values('00000000-0000-4000-8000-000000000913','00000000-0000-4000-8000-000000000912',1,'Dependency test','Test only','Test only',1);
insert into public.activity_definitions(id,session_definition_id,name,method_type,sequence) values
('00000000-0000-4000-8000-000000000914','00000000-0000-4000-8000-000000000913','First','custom',1),
('00000000-0000-4000-8000-000000000915','00000000-0000-4000-8000-000000000913','Second','custom',2);
do $$begin
 assert (select count(*) from public.activity_dependencies)=0,'no invented seed';
 begin insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory) values('00000000-0000-4000-8000-000000000914','00000000-0000-4000-8000-000000000914','completion',true);raise exception 'self accepted';exception when check_violation then null;end;
 begin insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory) values('00000000-0000-4000-8000-000000000914','00000000-0000-4000-8000-000000009999','completion',true);raise exception 'invalid parent';exception when foreign_key_violation then null;end;
 begin insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory) values('00000000-0000-4000-8000-000000000914','00000000-0000-4000-8000-000000000801','completion',true);raise exception 'cross version';exception when check_violation then null;end;
end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$begin
 assert not exists(select 1 from public.activity_dependencies);
 begin perform public.manage_activity_dependency('00000000-0000-4000-8000-000000000914',null,'00000000-0000-4000-8000-000000000915','completion',null,true);raise exception 'Student command';exception when insufficient_privilege then null;end;
 begin insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory) values('00000000-0000-4000-8000-000000000914','00000000-0000-4000-8000-000000000915','completion',true);raise exception 'direct insert';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000911',true);
select public.manage_activity_dependency('00000000-0000-4000-8000-000000000914',null,'00000000-0000-4000-8000-000000000915','completion',null,true);
do $$begin
 assert (select count(*) from public.activity_dependencies)=1,'valid creation';
 begin perform public.manage_activity_dependency('00000000-0000-4000-8000-000000000914',null,'00000000-0000-4000-8000-000000000915','completion',null,true);raise exception 'duplicate null artifact';exception when unique_violation then null;end;
end $$;
reset role;update public.curriculum_versions set status='approved' where id='00000000-0000-4000-8000-000000000912';
do $$begin
 begin update public.activity_dependencies set is_mandatory=false;raise exception 'approved update';exception when check_violation then null;end;
 begin delete from public.activity_dependencies;raise exception 'approved delete';exception when check_violation then null;end;
 assert (select relrowsecurity from pg_class where oid='public.activity_dependencies'::regclass);
 assert not has_table_privilege('authenticated','public.activity_dependencies','INSERT,UPDATE,DELETE');
end $$;
set local role authenticated;
do $$begin begin perform public.manage_activity_dependency('00000000-0000-4000-8000-000000000914',null,'00000000-0000-4000-8000-000000000915','artifact_available',null,false);raise exception 'approved append';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
\echo Dependency definitions constraints/history/scoped Admin/direct RLS PASS
