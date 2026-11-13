\set ON_ERROR_STOP on
begin;
create temporary table session_snapshot as select * from public.session_definitions;
select public.seed_professional_sessions();select public.seed_professional_sessions();
do $$ begin
 assert (select count(*) from public.session_definitions)=10, 'exactly ten seed sessions';
 assert (select array_agg(title order by sequence) from public.session_definitions)=array[
 'Think Like an Inventor','The SCAMPER Framework','SCAMPER Applied Workshop','Brainstorming & Problem Storming','Idea Evaluation & Voting','Affinity Diagram','Mind Mapping','Patent Document & Reading Basics','Patent Search & Comparative Analysis','AI-Assisted Invention Refinement'], 'exact titles/order';
 assert not exists(select 1 from public.session_definitions s join public.curriculum_versions v on v.id=s.curriculum_version_id join public.programs p on p.id=v.program_id where v.version_label<>'2026 v1' or p.code<>'PROFESSIONAL_COURSE' or s.status<>'active' or s.session_number<>s.sequence), 'parent/status/order';
 assert not exists((select * from public.session_definitions except select * from session_snapshot) union all (select * from session_snapshot except select * from public.session_definitions)), 'seed retries preserve all metadata';
 begin update public.session_definitions set title='Attack' where session_number=1;raise exception 'approved edit';exception when check_violation then null;end;
 begin delete from public.session_definitions where session_number=1;raise exception 'approved deletion';exception when check_violation then null;end;
 begin insert into public.session_definitions(curriculum_version_id,session_number,title,description,learning_goal,sequence) values('00000000-0000-4000-8000-000000000602',11,'Attack','','Attack',11);raise exception 'approved append';exception when check_violation then null;end;
end $$;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000000711','session-admin@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000000711','active');select public.provision_user_profile('00000000-0000-4000-8000-000000000001','active');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
 ('00000000-0000-4000-8000-000000000711','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000711'),
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000711');
insert into public.curriculum_versions(id,program_id,version_label) values('00000000-0000-4000-8000-000000000712','00000000-0000-4000-8000-000000000601','Session draft fixture');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$ begin
 assert (select count(*) from public.session_definitions)=0, 'Student protected definitions';
 begin update public.session_definitions set title='Attack';raise exception 'direct Student update';exception when insufficient_privilege then null;end;
 begin perform public.manage_session('00000000-0000-4000-8000-000000000712',null,1,'Attack','','Attack',1,'active');raise exception 'Student command';exception when insufficient_privilege then null;end;
 begin perform public.seed_professional_sessions();raise exception 'browser bootstrap';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000711',true);
do $$ declare s uuid; r jsonb; begin
 assert (select count(*) from public.session_definitions)=10, 'Admin scoped reads';
 begin perform public.manage_session('00000000-0000-4000-8000-000000000602','00000000-0000-4000-8000-000000000701',1,'Attack','','Attack',1,'active');raise exception 'Admin approved edit';exception when insufficient_privilege then null;end;
 r:=public.manage_session('00000000-0000-4000-8000-000000000712',null,1,'Draft fixture','Fixture description','Fixture goal',1,'active');s:=(r->>'id')::uuid;
 r:=public.manage_session('00000000-0000-4000-8000-000000000712',s,1,'Draft edited','Fixture description','Fixture goal',1,'inactive');assert r->>'title'='Draft edited' and r->>'status'='inactive', 'Admin draft edit';
 begin perform public.manage_session('00000000-0000-4000-8000-000000000712',null,1,'Duplicate','','Goal',2,'active');raise exception 'duplicate number';exception when unique_violation then null;end;
 begin perform public.manage_session('00000000-0000-4000-8000-000000000712',null,2,'Duplicate','','Goal',1,'active');raise exception 'duplicate sequence';exception when unique_violation then null;end;
 perform public.transition_curriculum('00000000-0000-4000-8000-000000000712','approved');
 begin perform public.manage_session('00000000-0000-4000-8000-000000000712',s,1,'Attack','','Goal',1,'active');raise exception 'approved fixture edit';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Same organization permission cannot cross into an unrelated organization.
insert into public.organizations(id,name,slug) values('00000000-0000-4000-8000-000000000713','Session other fixture','session-other');
insert into public.programs(id,organization_id,name,code,program_type) values('00000000-0000-4000-8000-000000000714','00000000-0000-4000-8000-000000000713','Session fixture','SESSION_FIXTURE','professional_course');
insert into public.curriculum_versions(id,program_id,version_label) values('00000000-0000-4000-8000-000000000715','00000000-0000-4000-8000-000000000714','Other draft');
set local role authenticated;
do $$ begin begin perform public.manage_session('00000000-0000-4000-8000-000000000715',null,1,'Attack','','Goal',1,'active');raise exception 'other organization';exception when insufficient_privilege then null;end;end $$;
reset role;
set local role anon;
do $$ begin begin perform * from public.session_definitions;raise exception 'anonymous read';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$ begin
 assert (select relrowsecurity from pg_class where oid='public.session_definitions'::regclass), 'session RLS';
 assert not has_table_privilege('authenticated','public.session_definitions','INSERT,UPDATE,DELETE'), 'no generic mutation';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.manage_session(uuid,uuid,integer,text,text,text,integer,public.session_status)'::regprocedure), 'safe definer';
 assert not has_function_privilege('service_role','public.manage_session(uuid,uuid,integer,text,text,text,integer,public.session_status)','EXECUTE'), 'service key not product Admin';
end $$;
rollback;
\echo Ten exact sessions, provenance, idempotency, uniqueness, draft-only management and RLS PASS
