reset role;
create temporary table usage_cases(label text primary key,input jsonb,payload jsonb);
grant select,insert on usage_cases to authenticated;
create function pg_temp.usage_bad(statement text,expected text default '42501') returns void language plpgsql as $$begin
 execute statement;raise exception 'Usage boundary bypass';exception when others then if sqlstate<>expected then raise;end if;end$$;
create function pg_temp.usage_input(project0 text default 'Team') returns jsonb language sql as $$
 select jsonb_build_object('attemptId',gen_random_uuid(),'projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id',
  'activityInstanceId',(select id from instances where label=case when project0='Team' then 'Team' else 'Individual' end),
  'taskType','USAGE_FIXTURE','modelProfile','AI_STANDARD','inputUsage',200,'outputUsage',40,'estimatedCost',0.000000000125,'latencyMs',120,'successFailure','SUCCESS')
 from logged_projects where label=project0
$$;
create temporary table usage_core_before as select
 (select jsonb_agg(to_jsonb(a) order by id) from public.ai_outputs a) outputs,
 (select jsonb_agg(to_jsonb(a) order by id) from public.ai_context_references a) refs,
 (select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p) projects,
 (select jsonb_agg(to_jsonb(s) order by id) from public.shares s) shares;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into usage_cases(label,input) values
 ('PersonalSuccess',pg_temp.usage_input('Individual')||'{"modelProfile":"AI_FAST","estimatedCost":null,"inputUsage":100,"outputUsage":20,"latencyMs":35}'),
 ('TeamSuccess',pg_temp.usage_input()),
 ('TeamFailure',pg_temp.usage_input()||'{"modelProfile":"AI_DEEP","successFailure":"FAILURE","inputUsage":null,"outputUsage":null,"estimatedCost":null,"latencyMs":10}');
update usage_cases set payload=private.record_ai_usage_event(input);
do $$declare r record;k text;body jsonb;q text;begin
 for r in select * from usage_cases loop
  assert r.payload->>'user_id'='00000000-0000-4000-8000-000000006004';
  assert r.payload->>'id'=r.input->>'attemptId';
  assert private.record_ai_usage_event(r.input)=r.payload,'Retry changed timestamp/state';
 end loop;
 assert (select count(*) from public.ai_usage_events)=3;
 assert (select payload->>'success_failure' from usage_cases where label='TeamFailure')='FAILURE';
 assert (select payload->'input_usage' from usage_cases where label='TeamFailure')='null'::jsonb;
 assert (select payload->'estimated_cost' from usage_cases where label='PersonalSuccess')='null'::jsonb;
 assert (select (payload->>'estimated_cost')::numeric from usage_cases where label='TeamSuccess')=0.000000000125,'Sub-cent estimates must not be rounded into invented zeroes';
 assert (select (payload->>'latency_ms')::int from usage_cases where label='TeamFailure')=10;
 assert not exists(select 1 from public.ai_outputs),'Failure must not need or create AI Output';
 foreach k in array array['prompt_text','response_text','context','metadata','storageReference','signedUrl','apiKey','userId','providerRequest','errorMessage','stackTrace','createdAt'] loop
  perform pg_temp.usage_bad(format('select private.record_ai_usage_event(pg_temp.usage_input()||jsonb_build_object(%L,''confidential payload forbidden''))',k),'22023');
 end loop;
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input()||''{"modelProfile":"GPT-5.6 Terra"}'')','22P02');
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input()||''{"modelProfile":"STANDARD"}'')','22P02');
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input()||''{"successFailure":"UNKNOWN"}'')','22P02');
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input()||''{"taskType":"confidential prompt with spaces"}'')','23514');
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input()||''{"taskType":"https://example.test/private"}'')','23514');
 foreach k in array array['inputUsage','outputUsage','latencyMs','estimatedCost'] loop
  perform pg_temp.usage_bad(format('select private.record_ai_usage_event(pg_temp.usage_input()||jsonb_build_object(%L,-1))',k),'23514');
  perform pg_temp.usage_bad(format('select private.record_ai_usage_event(pg_temp.usage_input()||jsonb_build_object(%L,''raw provider body''))',k),'22023');
 end loop;
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input()||''{"inputUsage":1.5}'')','22023');
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input()||''{"latencyMs":null}'')','22023');
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input()||''{"outputUsage":9007199254740992}'')','23514');
 perform pg_temp.usage_bad(format('select private.record_ai_usage_event(pg_temp.usage_input()||jsonb_build_object(''activityInstanceId'',%L))',(select id from instances where label='Individual')),'23514');
 perform pg_temp.usage_bad(format('select private.record_ai_usage_event(pg_temp.usage_input()||jsonb_build_object(''workspaceId'',%L))',(select payload->>'primary_workspace_id' from logged_projects where label='Individual')));
 perform pg_temp.usage_bad(format('select private.record_ai_usage_event(pg_temp.usage_input()||jsonb_build_object(''projectId'',%L,''workspaceId'',%L))',(select payload->>'id' from logged_projects where label='Case'),(select payload->>'primary_workspace_id' from logged_projects where label='Case')));
 perform pg_temp.usage_bad('select private.record_ai_usage_event(''{}'')','22023');
 perform pg_temp.usage_bad('select private.record_ai_usage_event(''[]'')','22023');
 perform pg_temp.usage_bad(format('select private.record_ai_usage_event(%L::jsonb||''{"inputUsage":999}'')',(select input from usage_cases where label='TeamSuccess')::text),'23505');
 perform pg_temp.usage_bad(format('insert into public.ai_usage_events(user_id,project_id,workspace_id,task_type,model_profile,latency_ms,success_failure) values(''00000000-0000-4000-8000-000000006005'',%L,%L,''USAGE_FIXTURE'',''AI_STANDARD'',0,''FAILURE'')',(select payload->>'id' from logged_projects where label='Team'),(select payload->>'primary_workspace_id' from logged_projects where label='Team')));
 for r in select id from public.ai_usage_events loop
  foreach k in array array['id','user_id','project_id','workspace_id','activity_instance_id','task_type','model_profile','input_usage','output_usage','estimated_cost','latency_ms','success_failure','created_at'] loop
   perform pg_temp.usage_bad(format('update public.ai_usage_events set %I=%I where id=%L',k,k,r.id),'55000');
  end loop;
 end loop;
 perform pg_temp.usage_bad('delete from public.ai_usage_events','55000');
end$$;
-- Server timestamp cannot be forged through a trusted insert either.
do $$declare r public.ai_usage_events;before0 timestamptz:=clock_timestamp();begin
 insert into public.ai_usage_events(project_id,workspace_id,task_type,model_profile,input_usage,output_usage,estimated_cost,latency_ms,success_failure,created_at)
 select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'TIMESTAMP_FIXTURE','AI_STANDARD',0,0,0,0,'FAILURE','2000-01-01' from logged_projects where label='Team' returning * into r;
 assert r.created_at>=before0;insert into usage_cases values('ServerTimestamp',null,to_jsonb(r));
 perform pg_temp.usage_bad(format('insert into public.ai_usage_events(project_id,workspace_id,task_type,model_profile,estimated_cost,latency_ms,success_failure) values(%L,%L,''USAGE_FIXTURE'',''AI_STANDARD'',''NaN'',0,''FAILURE'')',r.project_id,r.workspace_id),'23514');
end$$;
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_usage_events)=4;
 perform pg_temp.usage_bad('insert into public.ai_usage_events default values');
 perform pg_temp.usage_bad('update public.ai_usage_events set input_usage=999');
 perform pg_temp.usage_bad('delete from public.ai_usage_events');
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input())');
end$$;
reset role;
-- Another current authorized Team participant records its own operation. This
-- does not expose either user's operational history to the other participant.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into usage_cases(label,input) values('OtherUser',pg_temp.usage_input());
update usage_cases set payload=private.record_ai_usage_event(input) where label='OtherUser';
set local role authenticated;
do $$begin assert (select count(*) from public.ai_usage_events)=1;end$$;
reset role;
do $$declare u text;begin
 foreach u in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',u,true);
  execute 'set local role authenticated';
  assert not exists(select 1 from public.ai_usage_events),'Cross-Team/Personal/role-only/organization enumeration';
  assert not exists(select 1 from public.ai_usage_events where id=(select (payload->>'id')::uuid from usage_cases where label='TeamSuccess'));
  perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input())');
  execute 'reset role';
  perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input())');
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.4 removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_usage_events)=1;
 assert (select model_profile from public.ai_usage_events)='AI_FAST';
end$$;
reset role;
select pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input())');
select pg_temp.usage_bad(format('select private.record_ai_usage_event(%L::jsonb)',(select input from usage_cases where label='TeamSuccess')::text));
do $$begin
 assert (select count(*) from public.ai_usage_events)=5;
 assert not has_table_privilege('anon','public.ai_usage_events','SELECT');
 assert not has_table_privilege('service_role','public.ai_usage_events','SELECT,INSERT');
 assert not has_table_privilege('authenticated','public.ai_usage_events','INSERT,UPDATE,DELETE');
 assert not has_function_privilege('authenticated','private.record_ai_usage_event(jsonb)','EXECUTE');
 assert (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='ai_usage_events')=
  array['id','user_id','project_id','workspace_id','activity_instance_id','task_type','model_profile','input_usage','output_usage','estimated_cost','latency_ms','success_failure','created_at'];
 assert (select jsonb_agg(to_jsonb(a) order by id) from public.ai_outputs a) is not distinct from (select outputs from usage_core_before);
 assert (select jsonb_agg(to_jsonb(a) order by id) from public.ai_context_references a) is not distinct from (select refs from usage_core_before);
 assert (select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p)=(select projects from usage_core_before);
 assert (select jsonb_agg(to_jsonb(s) order by id) from public.shares s) is not distinct from (select shares from usage_core_before);
end$$;
-- M14.6 additive profile compatibility. Roll back only these temporary events
-- so all existing M14.4 cardinality, history and privacy assertions stay exact.
savepoint extraction_profile_check;
do $$declare state0 text;row0 jsonb;before0 jsonb;begin
 assert enum_range(null::public.ai_usage_model_profile)::text[] = array['AI_FAST','AI_STANDARD','AI_DEEP','AI_EXTRACTION'];
 select jsonb_agg(to_jsonb(e) order by id) into before0 from public.ai_usage_events e;
 foreach state0 in array array['SUCCESS','FAILURE'] loop
  row0:=private.record_ai_usage_event(pg_temp.usage_input('Individual')||jsonb_build_object('taskType','EXTRACTION','modelProfile','AI_EXTRACTION','successFailure',state0));
  assert row0->>'model_profile'='AI_EXTRACTION' and row0->>'success_failure'=state0;
  assert row0->>'user_id'='00000000-0000-4000-8000-000000006004';
 end loop;
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.ai_usage_events e where task_type<>'EXTRACTION')=before0,'Prior metrics history changed';
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input(''Individual'')||''{"modelProfile":"EXTRACTION"}'')','22P02');
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input()||''{"modelProfile":"AI_EXTRACTION"}'')');
end$$;
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_usage_events where model_profile='AI_EXTRACTION')=2;
 perform pg_temp.usage_bad('select private.record_ai_usage_event(pg_temp.usage_input(''Individual'')||''{"modelProfile":"AI_EXTRACTION"}'')');
end$$;
reset role;
rollback to savepoint extraction_profile_check;
select 'M14.6 extraction profile migration/success/failure/immutable-history/current-scope/default-deny compatibility PASS';
select 'AI_USAGE_ROW='||payload::text from usage_cases where label='TeamFailure';
select 'M14.4 success/failure/no-AI-Output/server-actor/scope/metrics/cost-null/idempotency/conflict/minimized-content/immutable/Personal/Team/self-only/removal/role-only/ID/RLS/no-core-mutation PASS';
rollback;

