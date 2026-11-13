reset role;
update public.teams set status='active' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
-- Fresh disposable curriculum context only; no production or historical
-- definition is rewritten. M7 starts the actual Session 10 execution below.
alter table public.activity_definitions disable trigger activity_history;
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,ai_role_code,configuration,status)
select '00000000-0000-4000-8000-000000142701',s.id,'Reconstruct and refine','comparison','Team Workspace',142701,'COMPARATIVE_CRITICAL_ANALYST','{"ai":{"enabled":true,"allowed_tasks":["COMPARATIVE_ANALYSIS","SESSION10_GAP_REFINEMENT"]}}','active' from public.session_definitions s where s.session_number=10 and s.curriculum_version_id=(select curriculum_version_id from public.session_definitions where id=(select session_definition_id from public.activity_definitions where id=(select activity_definition_id from public.activity_instances where id=pg_temp.research_context('Session9'))));
alter table public.activity_definitions enable trigger activity_history;
create temporary table s10(label text primary key,data jsonb);grant all on s10 to authenticated,service_role;
grant select on research_sources,research_context to service_role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
set local role authenticated;
insert into s10 select 'start',public.start_activity('00000000-0000-4000-8000-000000142701',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')) from logged_projects where label='Team';
do $$begin assert (select data->>'started' from s10 where label='start')='true','Canonical Session 10 start failed: '||(select data->>'reasonCode' from s10 where label='start');end$$;
insert into s10 select 'activity',data->'activity' from s10 where label='start';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into s10 select 'concept',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'INVENTION_CONCEPT','Invention Concept V1',(select (data->>'id')::uuid from s10 where label='activity'),true,true) from logged_projects where label='Team';
reset role;
-- Human-authored source fixture, before submission/approval. Source labels and
-- structure are not generated or normalized by AI.
update public.artifact_versions set content_snapshot='{"problem":"Unstable support","solution":"Articulated support","components":[{"name":"C1 support"}],"functions":["Maintain alignment"],"relationships":["C1 supports load"],"architecture":"Adjustable joint","technical_results":"Stability requires testing","constraints":"Manufacturing complexity","open_questions":["Wear under load"]}' where id=(select (data->>'initialVersionId')::uuid from s10 where label='concept');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into s10 select 'submission',public.submit_artifact((data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,(select (data->>'id')::uuid from s10 where label='activity')) from s10 where label='concept';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (data->>'id')::uuid from s10 where label='submission'));
select public.approve_artifact((select (data->>'id')::uuid from s10 where label='submission'));
insert into s10 select 'baseline',public.set_project_baseline_item((p.payload->>'id')::uuid,'CURRENT_INVENTION_CONCEPT',(c.data->>'artifactId')::uuid,(c.data->>'initialVersionId')::uuid) from logged_projects p cross join s10 c where p.label='Team' and c.label='concept';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into s10 select 'decision',public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','Research direction','question','Test wear?','method','DISCUSSION','options','[{"label":"Test"},{"label":"Investigate"}]'::jsonb)) from logged_projects where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into s10 select 'gap2',public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'GAP','Unselected gap','Do not analyze implicitly','User') from logged_projects where label='Team';
insert into s10 select kind,public.create_artifact((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,kind::public.artifact_type,'Saved '||kind,(select (data->>'id')::uuid from s10 where label='activity'),false,false) from logged_projects p cross join unnest(array['INVENTION_STRUCTURE','MIND_MAP','MINIMUM_ESSENTIAL_STRUCTURE']) kind where p.label='Team';
insert into s10 select kind,public.create_development_object((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,kind::public.development_object_type,case kind when 'PROBLEM' then 'Unstable support' else 'Articulated support' end,'Existing human Project structure','User') from logged_projects p cross join unnest(array['PROBLEM','SOLUTION']) kind where p.label='Team';
select public.relate_development_objects((select (data->>'id')::uuid from s10 where label='SOLUTION'),(select (data->>'id')::uuid from s10 where label='PROBLEM'),'SOLVES');
reset role;
update public.artifact_versions set content_snapshot='{"notes":"Human-authored saved structure","components":[{"name":"C1 support"}],"functions":["Maintain alignment"],"nodes":[{"label":"C1 support"}]}' where id in(select (data->>'initialVersionId')::uuid from s10 where label in ('INVENTION_STRUCTURE','MIND_MAP','MINIMUM_ESSENTIAL_STRUCTURE'));
create temporary table s10_before as select
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v) versions,
 (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b) baselines,
 (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,
 (select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p) patents,
 (select jsonb_agg(to_jsonb(d) order by id) from public.decisions d) decisions,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects;
create function pg_temp.s10_request(k text,task0 text default 'COMPARATIVE_ANALYSIS') returns jsonb language sql as $$
select jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','idempotencyKey',k,'fingerprint',encode(sha256(convert_to(k,'UTF8')),'hex'),'projectId',data->>'project_id','workspaceId',data->>'workspace_id','activityInstanceId',data->>'id','taskType',task0,'aiRole','COMPARATIVE_CRITICAL_ANALYST','modelProfile','AI_DEEP') from s10 where label='activity'$$;
create function pg_temp.s10_ref(kind0 text,id0 uuid,role0 text) returns jsonb language sql as $$select public.resolve_ai_context_source(jsonb_build_object('projectId',data->>'project_id','workspaceId',data->>'workspace_id','activityInstanceId',data->>'id','entityType',kind0,'entityId',id0,'contextRole',role0))-'content' from s10 where label='activity'$$;
insert into s10 select 'refs',jsonb_build_array(pg_temp.s10_ref('ARTIFACT_VERSION',(select (data->>'initialVersionId')::uuid from s10 where label='concept'),'CURRENT_ARTIFACT'),pg_temp.s10_ref('ACTIVITY_INSTANCE',(select (data->>'id')::uuid from s10 where label='activity'),'COURSE_CONTEXT'),pg_temp.s10_ref('EVIDENCE',pg_temp.research_source('Evidence'),'EVIDENCE'),pg_temp.s10_ref('PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT'));
update s10 set data=data||(select jsonb_agg(pg_temp.s10_ref('ARTIFACT_VERSION',(sources.data->>'initialVersionId')::uuid,'CURRENT_ARTIFACT')) from s10 sources where sources.label in ('INVENTION_STRUCTURE','MIND_MAP','MINIMUM_ESSENTIAL_STRUCTURE'))||jsonb_build_array(pg_temp.s10_ref('ARTIFACT_VERSION',(select id from public.artifact_versions where artifact_id=pg_temp.research_source('Landscape') and version_number=1),'CURRENT_ARTIFACT')) where label='refs';
set local role service_role;
insert into s10 values('reconstructionOperation',public.begin_ai_task_operation(pg_temp.s10_request('reconstruct')));
select public.record_ai_task_attempt(data||'{"actorId":"00000000-0000-4000-8000-000000006004","inputUsage":5,"outputUsage":5,"latencyMs":1,"successFailure":"SUCCESS"}') from s10 where label='reconstructionOperation';
insert into s10 select 'reconstruction',to_jsonb(public.save_ai_task_result(data||jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','promptText','Reconstruct current invention; report uncertainty','responseText','{"similarities":"C1 articulated support maintains alignment","differences":"Wear remains unknown","assumptions":"Human review required","source_references":"Current V1 and research sources","verification_needed":"Load and wear tests"}','outputType','COMPARISON','references',(select data from s10 where label='refs'),'metadata','{}'::jsonb))) from s10 where label='reconstructionOperation';
select pg_temp.research_bad(format('select public.begin_ai_task_operation(%L::jsonb)',pg_temp.s10_request('no-checkpoint','SESSION10_GAP_REFINEMENT')));
reset role;
set local role authenticated;
insert into s10 values('checkpoint',public.confirm_session10_reconstruction(jsonb_build_object('activityInstanceId',(select data->>'id' from s10 where label='activity'),'reconstructionAiOutputId',(select data#>>'{}' from s10 where label='reconstruction'),'confirmed',true)));
do $$declare c jsonb;begin
 c:=public.confirm_session10_reconstruction(jsonb_build_object('activityInstanceId',(select data->>'id' from s10 where label='activity'),'reconstructionAiOutputId',(select data#>>'{}' from s10 where label='reconstruction'),'confirmed',true));
 assert c=(select data from s10 where label='checkpoint'),'Retry changed confirmer/time';
 perform pg_temp.research_bad(format('select public.confirm_session10_reconstruction(%L::jsonb)',jsonb_build_object('activityInstanceId',(select data->>'id' from s10 where label='activity'),'reconstructionAiOutputId',(select data#>>'{}' from s10 where label='reconstruction'),'confirmed',true,'confirmedBy','spoof')),'22023');
 perform pg_temp.research_bad(format('select public.confirm_session10_reconstruction(%L::jsonb)',jsonb_build_object('activityInstanceId',pg_temp.research_context('Session9'),'reconstructionAiOutputId',(select data#>>'{}' from s10 where label='reconstruction'),'confirmed',true)));
end$$;
reset role;
create function pg_temp.s10_gap_request(k text) returns jsonb language sql as $$select pg_temp.s10_request(k,'SESSION10_GAP_REFINEMENT')||jsonb_build_object('session10CheckpointId',data->>'id','reconstructionAiOutputId',data->>'reconstruction_ai_output_id','session10GapId',pg_temp.research_source('Gap')) from s10 where label='checkpoint'$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
set local role authenticated;
do $$declare c jsonb;begin
 c:=public.resolve_session10_checkpoint(jsonb_build_object('checkpointId',(select data->>'id' from s10 where label='checkpoint'),'reconstructionAiOutputId',(select data#>>'{}' from s10 where label='reconstruction'),'activityInstanceId',(select data->>'id' from s10 where label='activity'),'projectId',(select data->>'project_id' from s10 where label='activity'),'workspaceId',(select data->>'workspace_id' from s10 where label='activity')));
 assert c->>'confirmed_by'='00000000-0000-4000-8000-000000006004','Another authorized actor must preserve original confirmer';
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
update s10 set data=data||jsonb_build_array(pg_temp.s10_ref('DEVELOPMENT_OBJECT',pg_temp.research_source('Gap'),'GAP'),pg_temp.s10_ref('DECISION',(select (data#>>'{decision,id}')::uuid from s10 where label='decision'),'TEAM_DECISION')) where label='refs';
insert into s10 values('gap2Ref',pg_temp.s10_ref('DEVELOPMENT_OBJECT',(select (data->>'id')::uuid from s10 where label='gap2'),'GAP'));
set local role service_role;
select pg_temp.research_bad(format('select public.begin_ai_task_operation(%L::jsonb)',pg_temp.s10_gap_request('foreign-gap')||'{"session10GapId":"00000000-0000-4000-8000-999999999999"}'));
insert into s10 values('gapOperation',public.begin_ai_task_operation(pg_temp.s10_gap_request('gap-analysis')));
select public.record_ai_task_attempt(data||'{"actorId":"00000000-0000-4000-8000-000000006004","inputUsage":5,"outputUsage":5,"latencyMs":1,"successFailure":"SUCCESS"}') from s10 where label='gapOperation';
reset role;
create function pg_temp.s10_save(refs0 jsonb) returns jsonb language sql as $$select data||jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','promptText','One selected wear gap','responseText','{"current_state":"Articulated support","gap":"Wear under load","candidate_directions":"Test replaceable bearing","impact_analysis":"Complexity, manufacturing and maintenance require evaluation","uncertainties":"Load performance unknown","verification_needed":"Search, measure and test; no legal conclusion"}','outputType','ANALYSIS','references',refs0,'metadata','{}'::jsonb) from s10 where label='gapOperation'$$;
set local role service_role;
select pg_temp.research_bad(format('select public.save_ai_task_result(%L::jsonb)',pg_temp.s10_save((select jsonb_agg(r) from s10,jsonb_array_elements(data) r where label='refs' and r->>'context_role'<>'GAP'))));
select pg_temp.research_bad(format('select public.save_ai_task_result(%L::jsonb)',pg_temp.s10_save((select data from s10 where label='refs')||jsonb_build_array((select data from s10 where label='gap2Ref')))));
insert into s10 select 'gapOutput',to_jsonb(public.save_ai_task_result(pg_temp.s10_save(data))) from s10 where label='refs';
reset role;
insert into s10 select 'conversionRequest',jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','aiOutputId',id,'targetObjectType','SOLUTION','candidateTitle','Human-selected bearing direction','candidateContent','Candidate only; load testing required','confirmed',true,'sourceResponseHash',encode(sha256(convert_to(response_text,'UTF8')),'hex')) from public.ai_outputs where id=(select (data#>>'{}')::uuid from s10 where label='gapOutput');
set local role service_role;
select pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',(select data from s10 where label='conversionRequest')),'55000');
reset role;
set local role authenticated;
select public.set_ai_output_disposition((select (data#>>'{}')::uuid from s10 where label='gapOutput'),'ACCEPT_AS_CANDIDATE',0);
reset role;
set local role service_role;
insert into s10 select 'candidate',public.convert_ai_output_to_candidate(data) from s10 where label='conversionRequest';
reset role;
do $$begin
 assert (select verification_status='UNVERIFIED' and disposition='KEEP_FOR_REVIEW' from public.ai_outputs where id=(select (data#>>'{}')::uuid from s10 where label='reconstruction'));
 assert (select verification_status='UNVERIFIED' from public.ai_outputs where id=(select (data#>>'{}')::uuid from s10 where label='gapOutput'));
 assert (select count(*) from public.ai_context_references where ai_output_id=(select (data#>>'{}')::uuid from s10 where label='gapOutput') and context_role='GAP')=1;
 assert not exists(select 1 from public.ai_context_references where ai_output_id=(select (data#>>'{}')::uuid from s10 where label='gapOutput') and entity_id=(select (data->>'id')::uuid from s10 where label='gap2'));
 assert (select data->>'origin_type'='AI' and data->>'created_by'='00000000-0000-4000-8000-000000006004' and data->>'status' is null and data->>'verification_status' is null from s10 where label='candidate');
 assert (select artifacts from s10_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select versions from s10_before)=(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v);
 assert (select baselines from s10_before)=(select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b);
 assert (select evidence from s10_before)=(select jsonb_agg(to_jsonb(e) order by id) from public.evidence e);
 assert (select patents from s10_before)=(select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p);
 assert (select decisions from s10_before)=(select jsonb_agg(to_jsonb(d) order by id) from public.decisions d);
 assert (select objects from s10_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o where o.id<>(select (data->>'id')::uuid from s10 where label='candidate'));
end$$;
-- Direct mutations remain denied even if a temporary fixture grant is present.
grant insert,update,delete on public.session10_reconstruction_checkpoints to authenticated;
set local role authenticated;
select pg_temp.research_bad('insert into public.session10_reconstruction_checkpoints select * from public.session10_reconstruction_checkpoints');
do $$declare n integer;begin
 update public.session10_reconstruction_checkpoints set confirmed_at=now();get diagnostics n=row_count;assert n=0;
 delete from public.session10_reconstruction_checkpoints;get diagnostics n=row_count;assert n=0;
end$$;
reset role;
revoke insert,update,delete on public.session10_reconstruction_checkpoints from authenticated;
do $$declare actor0 text;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);execute 'set local role authenticated';
  assert not exists(select 1 from public.session10_reconstruction_checkpoints);
  perform pg_temp.research_bad(format('select public.confirm_session10_reconstruction(%L::jsonb)',jsonb_build_object('activityInstanceId',(select data->>'id' from s10 where label='activity'),'reconstructionAiOutputId',(select data#>>'{}' from s10 where label='reconstruction'),'confirmed',true)));
  execute 'reset role';
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','Session 10 current authorization');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
set local role authenticated;
do $$begin assert (select count(*) from public.session10_reconstruction_checkpoints)=1,'Historical review remains available to current authorized Team';end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin assert not exists(select 1 from public.session10_reconstruction_checkpoints);end$$;
reset role;
set local role service_role;
select pg_temp.research_bad(format('select public.begin_ai_task_operation(%L::jsonb)',pg_temp.s10_gap_request('gap-analysis')));
reset role;
do $$begin
 assert not has_function_privilege('authenticated','private.begin_ai_task_operation_m1411(jsonb)','EXECUTE');
 assert not has_function_privilege('service_role','private.save_ai_task_result_m1411(jsonb)','EXECUTE');
 assert (select count(*) from public.session10_reconstruction_checkpoints)=1;
end$$;
select 'SESSION10_CHECKPOINT_ROW='||data::text from s10 where label='checkpoint';
select 'M14.27 reconstruction/checkpoint/exact-one-Gap/Decision/context/candidate/baseline/RLS/removal PASS';
rollback;
