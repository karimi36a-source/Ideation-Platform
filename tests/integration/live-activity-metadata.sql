\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare target uuid;metadata jsonb;begin
 select (value#>>'{activity,id}')::uuid into target from public.mind_map_browser_fixture where key='activity';
 assert public.can_read_activity_instance(target),'Student must read own Activity';
 assert not exists(select 1 from public.activity_definitions where id='00000000-0000-4000-8000-000001119001'),'Definition table RLS must remain Admin-only';
 metadata:=public.activity_resume_definition_metadata(target);
 assert metadata=jsonb_build_object('id','00000000-0000-4000-8000-000001119001','name','Browser Team Mind Map','session_definition_id','00000000-0000-4000-8000-000000950702','method_type','mind_map'),'Gated metadata must match exact seeded definition';
 assert public.activity_resume_definition_identity(target)=metadata-'session_definition_id'-'method_type','Existing M7 identity contract changed';
 assert public.activity_resume_definition_metadata(gen_random_uuid()) is null,'Guessed ID authorized';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
 assert public.activity_resume_definition_metadata(target) is null,'Team B metadata leak';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 assert public.activity_resume_definition_metadata(target) is null,'Role-only Master metadata leak';
end $$;
reset role;
do $$begin
 assert not has_function_privilege('anon','public.activity_resume_definition_metadata(uuid)','EXECUTE'),'Anonymous RPC access';
 assert not has_function_privilege('service_role','public.activity_resume_definition_metadata(uuid)','EXECUTE'),'Service bypass grant';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((value->>'teamId')::uuid,'00000000-0000-4000-8000-000000006004') from public.mind_map_browser_fixture where key='scope';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert public.activity_resume_definition_metadata((select (value#>>'{activity,id}')::uuid from public.mind_map_browser_fixture where key='activity')) is null,'Removed member metadata leak';
end $$;
rollback;
\echo M16.19 M7-gated Activity metadata/definition-RLS/Team-B-role-only-removal-denial PASS
