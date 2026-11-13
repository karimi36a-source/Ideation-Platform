reset role;
-- Fresh fixture only: no historical production snapshots are rewritten.
-- Privileged baseline seed before assertions; retain all runtime guards.
-- A separate Definition/Instance avoids rewriting started historical snapshots.
alter table public.activity_definitions disable trigger activity_history;
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,ai_role_code,configuration,status)
select '00000000-0000-4000-8000-000000149001',session_definition_id,'M14.9 disposable SCAMPER', 'scamper',workspace_mode,149001,'STRUCTURED_CREATIVITY_ASSISTANT','{"ai":{"enabled":true}}','active' from public.activity_definitions where id=(select activity_definition_id from public.activity_instances where id=pg_temp.research_context('Session9'));
alter table public.activity_definitions enable trigger activity_history;
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
select '00000000-0000-4000-8000-000000149002','00000000-0000-4000-8000-000000149001',cohort_id,project_id,workspace_id,team_id,started_by,clock_timestamp(),'active',public.activity_start_snapshot('00000000-0000-4000-8000-000000149001') from public.activity_instances where id=pg_temp.research_context('Session9');
update research_context set id='00000000-0000-4000-8000-000000149002' where label='Session9';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$declare r jsonb;begin
 r:=public.resolve_activity_ai_configuration(pg_temp.research_context('Session9'));
 assert r is not null and r->>'ai_role_code'='STRUCTURED_CREATIVITY_ASSISTANT';
 assert r #>> '{configuration,ai,enabled}'='true';
 assert r->>'status'='active';
 assert r->>'independent_work_satisfied'='false';
 assert not (r ?| array['instructions','participants','outputs','chat','source_workspace','secrets']);
 assert (select count(*) from jsonb_object_keys(r->'configuration'))=1;
end$$;
reset role;
-- Canonical actor-authored Object output, linked through existing operation.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
select public.add_activity_output(pg_temp.research_context('Session9'),pg_temp.research_source('Gap'));
reset role;
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=pg_temp.research_context('Session9');
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
select '00000000-0000-4000-8000-000000149003',activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,clock_timestamp(),'active',jsonb_set(configuration_snapshot,'{configuration,ai}','{"enabled":true,"independent_work_required":true,"completion_rule":{"min_required_inputs":0,"min_outputs":1}}') from public.activity_instances where id=pg_temp.research_context('Session9');
set local role authenticated;
select public.add_activity_output('00000000-0000-4000-8000-000000149003',pg_temp.research_source('Gap'));
reset role;
update research_context set id='00000000-0000-4000-8000-000000149003' where label='Session9';
set local role authenticated;
do $$begin assert public.resolve_activity_ai_configuration(pg_temp.research_context('Session9'))->>'independent_work_satisfied'='true','Canonical independent output proof missing';end$$;
reset role;
-- No resource differentiation for unrelated/role-only/missing identities.
do $$declare actor0 uuid;begin
 for actor0 in select id from public.users where id<>'00000000-0000-4000-8000-000000006004'::uuid loop
  perform set_config('request.jwt.claim.sub',actor0::text,true);
  if not public.can_read_activity_instance(pg_temp.research_context('Session9')) then
   assert public.resolve_activity_ai_configuration(pg_temp.research_context('Session9')) is null;
  end if;
 end loop;
 assert not has_function_privilege('anon','public.resolve_activity_ai_configuration(uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.resolve_activity_ai_configuration(uuid)','EXECUTE');
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin assert public.resolve_activity_ai_configuration('00000000-0000-4000-8000-999999999999') is null;end$$;
-- Exact Team B and role-only identities, independent of public identifiers.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin assert public.resolve_activity_ai_configuration(pg_temp.research_context('Session9')) is null;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert public.resolve_activity_ai_configuration(pg_temp.research_context('Session9')) is null;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
do $$begin assert public.resolve_activity_ai_configuration(pg_temp.research_context('Session9')) is null;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert public.resolve_activity_ai_configuration((select id from instances where label='Individual')) is not null;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert public.resolve_activity_ai_configuration((select id from instances where label='Individual')) is null;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.9 current authorization');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert public.resolve_activity_ai_configuration(pg_temp.research_context('Session9')) is null;end$$;
select 'M14.9 Activity AI configuration current-authorization independent-work projection PASS';
rollback;



