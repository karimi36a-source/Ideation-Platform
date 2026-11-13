reset role;
create temporary table runtime_requests(label text primary key,body jsonb);
create temporary table runtime_ops(label text primary key,body jsonb);
create temporary table runtime_refs(body jsonb);
create temporary table runtime_template(body jsonb);
grant select,insert,update on runtime_requests,runtime_ops,runtime_refs,runtime_template to service_role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.seed_ai_prompt_templates();
insert into runtime_template select private.resolve_active_ai_prompt_template('STRUCTURED_CREATIVITY_ASSISTANT','scamper');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
reset role;
insert into runtime_requests values('One',jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','idempotencyKey','runtime-one','fingerprint',repeat('a',64),'projectId',(select payload->>'id' from logged_projects where label='Team'),'workspaceId',(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'activityInstanceId',pg_temp.research_context('Session9'),'taskType','SCAMPER_ASSISTANCE','aiRole','STRUCTURED_CREATIVITY_ASSISTANT','modelProfile','AI_STANDARD'));
set local role authenticated;
reset role;
insert into runtime_refs select public.resolve_ai_context_source(jsonb_build_object('projectId',body->>'projectId','workspaceId',body->>'workspaceId','activityInstanceId',body->>'activityInstanceId','entityType','ACTIVITY_INSTANCE','entityId',body->>'activityInstanceId','contextRole','COURSE_CONTEXT'))-'content' from runtime_requests where label='One';
create function pg_temp.runtime_req(k text) returns jsonb language sql as $$select body||jsonb_build_object('idempotencyKey',k) from runtime_requests where label='One'$$;
create function pg_temp.runtime_attempt(k text) returns jsonb language sql as $$select jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','operationId',body->>'operationId','attemptId',body->>'attemptId','inputUsage',10,'outputUsage',4,'latencyMs',20,'successFailure','SUCCESS') from runtime_ops where label=k$$;
create function pg_temp.runtime_save(k text) returns jsonb language sql as $$select pg_temp.runtime_attempt(k)||jsonb_build_object('promptText','SCAMPER_ASSISTANCE','responseText','Unverified fixture suggestion','outputType','SUGGESTION','providerReference','mock:response_fixture','references',(select jsonb_agg(body) from runtime_refs),'metadata',jsonb_build_object('prompt_template_id',(select body->>'id' from runtime_template),'prompt_template_version',(select body->'version' from runtime_template),'model_profile','AI_STANDARD'))$$;
-- RUNTIME TESTS
set local role service_role;
insert into runtime_ops values('One',public.begin_ai_task_operation(pg_temp.runtime_req('One')));
select public.record_ai_task_attempt(pg_temp.runtime_attempt('One'));
select public.record_ai_task_attempt(pg_temp.runtime_attempt('One'));
select public.save_ai_task_result(pg_temp.runtime_save('One'));
select public.save_ai_task_result(pg_temp.runtime_save('One'));
do $$begin assert public.begin_ai_task_operation(pg_temp.runtime_req('One'))->>'completed'='true';end$$;
reset role;
do $$begin
 assert (select count(*) from public.ai_outputs where task_type='SCAMPER_ASSISTANCE')=1;
 assert (select count(*) from public.ai_context_references r join public.ai_outputs o on o.id=r.ai_output_id where o.task_type='SCAMPER_ASSISTANCE')=1;
 assert (select count(*) from public.ai_usage_events)=1;
 assert (select verification_status='UNVERIFIED' and disposition='KEEP_FOR_REVIEW' from public.ai_outputs where task_type='SCAMPER_ASSISTANCE');
end$$;
set local role service_role;
do $$begin
 perform pg_temp.research_bad(format('select public.begin_ai_task_operation(%L::jsonb)',pg_temp.runtime_req('One')||jsonb_build_object('fingerprint',repeat('b',64))),'23505');
end$$;
insert into runtime_ops values('FailedSave',public.begin_ai_task_operation(pg_temp.runtime_req('FailedSave')));
select public.record_ai_task_attempt(pg_temp.runtime_attempt('FailedSave'));
do $$begin
 perform pg_temp.research_bad(format('select public.save_ai_task_result(%L::jsonb)',pg_temp.runtime_save('FailedSave')||'{"references":[{"entity_type":"ACTIVITY_INSTANCE","entity_id":"00000000-0000-4000-8000-999999999999","context_role":"COURSE_CONTEXT","included_snapshot_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","permission_scope":{"access":"SOURCE"},"share_snapshot_id":null}]}'),'42501');
 perform pg_temp.research_bad(format('select public.save_ai_task_result(%L::jsonb)',pg_temp.runtime_save('FailedSave')||jsonb_build_object('references',jsonb_build_array((select body||jsonb_build_object('included_snapshot_hash',repeat('b',64)) from runtime_refs)))),'42501');
end$$;
reset role;
do $$begin assert (select count(*) from public.ai_outputs where task_type='SCAMPER_ASSISTANCE')=1;end$$;
set local role service_role;
select public.release_ai_task_operation(pg_temp.runtime_attempt('FailedSave'));
update runtime_ops set body=public.begin_ai_task_operation(pg_temp.runtime_req('FailedSave')) where label='FailedSave';
select public.record_ai_task_attempt(pg_temp.runtime_attempt('FailedSave'));
select public.save_ai_task_result(pg_temp.runtime_save('FailedSave'));
reset role;
create function pg_temp.failure_state() returns jsonb language plpgsql as $$
declare result jsonb:='{}';kind text;rows0 jsonb;begin
 foreach kind in array array['development_objects','artifacts','artifact_versions','decisions','evidence','shares','development_projects','ai_outputs','ai_context_references','team_memberships','mind_maps','mind_map_nodes','mind_map_edges','session10_reconstruction_checkpoints','project_baseline_items','submissions','review_actions','evidence_links','decision_links','share_snapshots','change_log','audit_events'] loop
  execute format('select coalesce(jsonb_agg(to_jsonb(t) order by id),''[]''::jsonb) from public.%I t',kind) into rows0;
  result:=result||jsonb_build_object(kind,rows0);
 end loop;return result;end$$;
create temporary table provider_failure_before as select pg_temp.failure_state() body;
set local role service_role;
insert into runtime_ops values('ProviderFail',public.begin_ai_task_operation(pg_temp.runtime_req('ProviderFail')));
select public.record_ai_task_attempt(pg_temp.runtime_attempt('ProviderFail')||'{"successFailure":"FAILURE"}');
select public.release_ai_task_operation(pg_temp.runtime_attempt('ProviderFail'));
reset role;
do $$begin
 assert pg_temp.failure_state()=(select body from provider_failure_before),'Provider failure changed canonical Project/output/reference state';
 assert (select count(*) from public.ai_usage_events where id=(select (body->>'attemptId')::uuid from runtime_ops where label='ProviderFail') and success_failure='FAILURE')=1;
end$$;
set local role service_role;

update runtime_ops set body=public.begin_ai_task_operation(pg_temp.runtime_req('ProviderFail')) where label='ProviderFail';
select public.record_ai_task_attempt(pg_temp.runtime_attempt('ProviderFail'));
select public.save_ai_task_result(pg_temp.runtime_save('ProviderFail'));
reset role;
-- M14.30: repeated timeout attempts, then one canonical successful result.
-- Isolate these extra cases without changing the existing regression fixtures.
savepoint m1430_retry;
create temporary table retry_before as select pg_temp.failure_state() body,(select count(*) from public.ai_usage_events) usage_count,(select coalesce(array_agg(id),'{}'::uuid[]) from public.ai_usage_events) usage_ids;
set local role service_role;
do $$declare i integer;first_attempt uuid;current_attempt uuid;begin
 for i in 1..2 loop
  insert into runtime_ops values('RetryGate',public.begin_ai_task_operation(pg_temp.runtime_req('RetryGate'))) on conflict(label) do update set body=excluded.body;
  current_attempt:=(select (body->>'attemptId')::uuid from runtime_ops where label='RetryGate');
  if i=1 then first_attempt:=current_attempt;else assert first_attempt<>current_attempt;end if;
  perform public.record_ai_task_attempt(pg_temp.runtime_attempt('RetryGate')||'{"successFailure":"FAILURE","inputUsage":null,"outputUsage":null}');
  perform public.release_ai_task_operation(pg_temp.runtime_attempt('RetryGate'));
 end loop;
end$$;
reset role;
do $$begin
 assert pg_temp.failure_state()=(select body from retry_before),'Repeated failures changed Project history or left Output/reference orphans';
 assert (select count(*) from public.ai_usage_events)=(select usage_count+2 from retry_before);
end$$;
set local role service_role;
update runtime_ops set body=public.begin_ai_task_operation(pg_temp.runtime_req('RetryGate')) where label='RetryGate';
select public.record_ai_task_attempt(pg_temp.runtime_attempt('RetryGate'));
select public.save_ai_task_result(pg_temp.runtime_save('RetryGate'));
-- A lost save/browser reply is reconciled by the same platform operation.
do $$declare original0 jsonb;replay0 jsonb;begin
 original0:=public.begin_ai_task_operation(pg_temp.runtime_req('RetryGate'));
 replay0:=public.begin_ai_task_operation(pg_temp.runtime_req('RetryGate'));
 assert original0=replay0 and original0->>'completed'='true';
 assert public.save_ai_task_result(pg_temp.runtime_save('RetryGate')||'{"providerReference":"mock:guessed_provider_id"}')=(original0->>'outputId')::uuid;
 perform pg_temp.research_bad(format('select public.begin_ai_task_operation(%L::jsonb)',pg_temp.runtime_req('RetryGate')||jsonb_build_object('fingerprint',repeat('f',64))),'23505');
end$$;
reset role;
do $$declare state0 jsonb:=pg_temp.failure_state();op0 public.ai_task_operations;begin
 select * into op0 from public.ai_task_operations where id=(select (body->>'operationId')::uuid from runtime_ops where label='RetryGate');
 assert (select count(*) from public.ai_usage_events)=(select usage_count+3 from retry_before);
 assert (select count(*) from public.ai_usage_events where not(id=any((select usage_ids from retry_before)::uuid[])) and success_failure='FAILURE' and input_usage is null and output_usage is null)=2;
 assert (select count(*) from public.ai_usage_events where not(id=any((select usage_ids from retry_before)::uuid[])) and success_failure='SUCCESS' and input_usage=10 and output_usage=4)=1;
 assert (select count(*) from public.ai_outputs)=(select jsonb_array_length(body->'ai_outputs')+1 from retry_before);
 assert (select count(*) from public.ai_context_references where ai_output_id=op0.output_id)=1;
 assert not exists(select 1 from public.ai_context_references r left join public.ai_outputs o on o.id=r.ai_output_id where o.id is null);
 assert (select model_provider_reference from public.ai_outputs where id=op0.output_id)='mock:response_fixture';
 assert state0-'ai_outputs'-'ai_context_references'=(select body-'ai_outputs'-'ai_context_references' from retry_before),'Retry mutated unrelated Project state';
end$$;
\echo M14.30 repeated-timeout/one-success/lost-reply/provider-ID/usage/references/project-history PASS
rollback to savepoint m1430_retry;
release savepoint m1430_retry;
-- Force audit/provenance insertion failure and prove the whole result rolls back.
create function pg_temp.reject_runtime_reference() returns trigger language plpgsql as $$begin raise exception 'Forced provenance failure' using errcode='P0001';end$$;
create trigger runtime_force_failure before insert on public.ai_context_references for each row execute function pg_temp.reject_runtime_reference();
set local role service_role;
insert into runtime_ops values('Forced',public.begin_ai_task_operation(pg_temp.runtime_req('Forced')));
select public.record_ai_task_attempt(pg_temp.runtime_attempt('Forced'));
select pg_temp.research_bad(format('select public.save_ai_task_result(%L::jsonb)',pg_temp.runtime_save('Forced')),'P0001');
reset role;
drop trigger runtime_force_failure on public.ai_context_references;
do $$begin assert (select count(*) from public.ai_outputs where task_type='SCAMPER_ASSISTANCE')=3;end$$;
set local role authenticated;
do $$begin
 perform pg_temp.research_bad('select * from public.ai_task_operations');
 perform pg_temp.research_bad('insert into public.ai_task_operations default values');
 perform pg_temp.research_bad('update public.ai_task_operations set status=''retryable''');
 perform pg_temp.research_bad('select public.begin_ai_task_operation(''{}'')');
 perform pg_temp.research_bad('select public.record_ai_task_attempt(''{}'')');
 perform pg_temp.research_bad('select public.save_ai_task_result(''{}'')');
 perform pg_temp.research_bad('select public.release_ai_task_operation(''{}'')');
end$$;
reset role;
-- A colliding event identity must not be mistaken for this operation's usage.
set local role service_role;
insert into runtime_ops values('UsageConflict',public.begin_ai_task_operation(pg_temp.runtime_req('UsageConflict')));
reset role;
select private.record_ai_usage_event((select jsonb_build_object('attemptId','00000000-0000-4000-8000-000000141199','projectId',body->>'projectId','workspaceId',body->>'workspaceId','activityInstanceId',body->>'activityInstanceId','taskType','OTHER_TASK','modelProfile','AI_STANDARD','inputUsage',10,'outputUsage',4,'latencyMs',20,'successFailure','SUCCESS') from runtime_requests where label='One'));
update public.ai_task_operations set attempt_id='00000000-0000-4000-8000-000000141199' where id=(select (body->>'operationId')::uuid from runtime_ops where label='UsageConflict');
update runtime_ops set body=jsonb_set(body,'{attemptId}','"00000000-0000-4000-8000-000000141199"') where label='UsageConflict';
set local role service_role;
select pg_temp.research_bad(format('select public.record_ai_task_attempt(%L::jsonb)',pg_temp.runtime_attempt('UsageConflict')),'23505');
reset role;
-- New key is no authority for Team B or an instructional role alone.
set local role service_role;
select pg_temp.research_bad(format('select public.begin_ai_task_operation(%L::jsonb)',pg_temp.runtime_req('Denied')||'{"actorId":"00000000-0000-4000-8000-000000006006"}'),'42501');
select pg_temp.research_bad(format('select public.begin_ai_task_operation(%L::jsonb)',pg_temp.runtime_req('Denied')||'{"actorId":"00000000-0000-4000-8000-000000006002"}'),'42501');
insert into runtime_ops values('Removed',public.begin_ai_task_operation(pg_temp.runtime_req('Removed')));
reset role;
create temporary table removed_ai_history as select
 (select jsonb_agg(to_jsonb(o) order by id) from public.ai_outputs o) outputs,
 (select jsonb_agg(to_jsonb(r) order by id) from public.ai_context_references r) refs;
grant select on runtime_requests to authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','Runtime revocation');
set local role service_role;
select public.record_ai_task_attempt(pg_temp.runtime_attempt('Removed'));
select pg_temp.research_bad(format('select public.save_ai_task_result(%L::jsonb)',pg_temp.runtime_save('Removed')),'42501');
select pg_temp.research_bad(format('select public.begin_ai_task_operation(%L::jsonb)',pg_temp.runtime_req('One')),'42501');
select pg_temp.research_bad(format('select public.begin_ai_task_operation(%L::jsonb)',pg_temp.runtime_req('AfterRemoval')),'42501');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin
 assert not public.can_read_development_project((select (body->>'projectId')::uuid from runtime_requests where label='One'));
 assert not exists(select 1 from public.ai_outputs where requested_by='00000000-0000-4000-8000-000000006004');
 assert not exists(select 1 from public.ai_context_references);
end$$;

reset role;
do $$begin
 assert exists(select 1 from public.ai_usage_events where id=(select (body->>'attemptId')::uuid from runtime_ops where label='Removed'));
 assert (select count(*) from public.ai_outputs where task_type='SCAMPER_ASSISTANCE')=3;
 assert (select count(*) from public.ai_context_references r join public.ai_outputs o on o.id=r.ai_output_id where o.task_type='SCAMPER_ASSISTANCE')=3;
 assert (select count(*) from public.ai_usage_events where success_failure='FAILURE')=1;
 assert (select outputs from removed_ai_history) is not distinct from (select jsonb_agg(to_jsonb(o) order by id) from public.ai_outputs o);
 assert (select refs from removed_ai_history) is not distinct from (select jsonb_agg(to_jsonb(r) order by id) from public.ai_context_references r);
 assert not has_function_privilege('anon','public.begin_ai_task_operation(jsonb)','EXECUTE');
 assert not has_table_privilege('service_role','public.ai_task_operations','SELECT,INSERT,UPDATE,DELETE');
end$$;
select 'M14.21 AT-AI-009 failure-usage/no-project-mutation/no-output-orphans/authorized-retry PASS';
select 'M14.20 AT-AI-004 current-membership/completed-replay/new-key/output-reference-denial/history PASS';
select 'M14.11 atomic-output/provenance/idempotency/retry/usage/revocation/default-deny PASS';
rollback;

