reset role;
-- Real human-verified source, real saved AI Outputs, no real provider calls.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.verify_evidence(pg_temp.research_source('Evidence'),'VERIFIED','Human checked original patent source');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create function pg_temp.sep_state() returns jsonb language sql as $$select jsonb_build_object('patents',(select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p),'evidence',(select jsonb_agg(to_jsonb(e) order by id) from public.evidence e),'links',(select jsonb_agg(to_jsonb(e) order by id) from public.evidence_links e),'verification',(select jsonb_agg(to_jsonb(e) order by id) from public.evidence_verification_history e),'decisions',(select jsonb_agg(to_jsonb(e) order by id) from public.decisions e))$$;
create temporary table sep_before as select pg_temp.sep_state() body;
create function pg_temp.sep_tripwire() returns trigger language plpgsql as $$begin raise exception 'Automatic Evidence mutation attempted' using errcode='P1417';end$$;
create trigger sep_evidence before insert or update or delete on public.evidence for each row execute function pg_temp.sep_tripwire();
create trigger sep_links before insert or update or delete on public.evidence_links for each row execute function pg_temp.sep_tripwire();
create trigger sep_history before insert or update or delete on public.evidence_verification_history for each row execute function pg_temp.sep_tripwire();
create trigger sep_patents before insert or update or delete on public.patent_records for each row execute function pg_temp.sep_tripwire();
-- Fresh immutable execution for the existing Patent Research role/task.
alter table public.activity_definitions disable trigger activity_history;
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,ai_role_code,configuration,status)
select '00000000-0000-4000-8000-000000141701',session_definition_id,'M14.17 disposable Patent research','patent_research','Team Workspace',141701,'PATENT_RESEARCH_ASSISTANT','{"ai":{"enabled":true}}','active' from public.activity_definitions where id='00000000-0000-4000-8000-000000149001';
alter table public.activity_definitions enable trigger activity_history;
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
select '00000000-0000-4000-8000-000000141702','00000000-0000-4000-8000-000000141701',cohort_id,project_id,workspace_id,team_id,started_by,clock_timestamp(),'active',public.activity_start_snapshot('00000000-0000-4000-8000-000000141701') from public.activity_instances where id=(select id from cv_activities where label='Gap');
create temporary table sep_outputs(label text,id uuid);
create function pg_temp.sep_output(label0 text,task0 text,body0 jsonb) returns uuid language plpgsql as $$
declare a public.activity_instances;op jsonb;attempt0 jsonb;refs jsonb;out0 uuid;pat boolean:=task0='PATENT_RESEARCH_ASSISTANCE';begin
 select * into a from public.activity_instances where id=case when pat then '00000000-0000-4000-8000-000000141702'::uuid else (select id from cv_activities where label='Gap') end;
 refs:=jsonb_build_array(
  public.resolve_ai_context_source(jsonb_build_object('projectId',a.project_id,'workspaceId',a.workspace_id,'activityInstanceId',a.id,'entityType','EVIDENCE','entityId',pg_temp.research_source('Evidence'),'contextRole','EVIDENCE'))-'content',
  public.resolve_ai_context_source(jsonb_build_object('projectId',a.project_id,'workspaceId',a.workspace_id,'activityInstanceId',a.id,'entityType','ARTIFACT_VERSION','entityId',(select payload->>'initialVersionId' from submitted_fixtures where label='Team'),'contextRole','CURRENT_ARTIFACT'))-'content',
  public.resolve_ai_context_source(jsonb_build_object('projectId',a.project_id,'workspaceId',a.workspace_id,'activityInstanceId',a.id,'entityType','ACTIVITY_INSTANCE','entityId',a.id,'contextRole','COURSE_CONTEXT'))-'content');
 assert refs->0 is not null and refs->0<>'null'::jsonb;
 if pat then
  refs:=refs||jsonb_build_array(public.resolve_ai_context_source(jsonb_build_object('projectId',a.project_id,'workspaceId',a.workspace_id,'activityInstanceId',a.id,'entityType','PATENT_RECORD','entityId',pg_temp.research_source('Patent'),'contextRole','PATENT'))-'content');
  assert refs->3 is not null and refs->3<>'null'::jsonb;
 end if;
 op:=public.begin_ai_task_operation(jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','idempotencyKey','separation-'||label0,'fingerprint',encode(sha256(convert_to(label0,'UTF8')),'hex'),'projectId',a.project_id,'workspaceId',a.workspace_id,'activityInstanceId',a.id,'taskType',task0,'aiRole',case when pat then 'PATENT_RESEARCH_ASSISTANT' else 'COMPARATIVE_CRITICAL_ANALYST' end,'modelProfile','AI_DEEP'));
 attempt0:=jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','operationId',op->>'operationId','attemptId',op->>'attemptId');
 perform public.record_ai_task_attempt(attempt0||'{"inputUsage":10,"outputUsage":10,"latencyMs":1,"successFailure":"SUCCESS"}');
 out0:=public.save_ai_task_result(attempt0||jsonb_build_object('promptText','Authorized Evidence, human verification still required','responseText',body0::text,'outputType',case when task0='COMPARATIVE_ANALYSIS' then 'COMPARISON' else 'ANALYSIS' end,'references',refs,'metadata',case when pat then jsonb_build_object('source_references',(select jsonb_agg(jsonb_build_object('reference','source-'||lpad(n::text,3,'0'))||(r-'permission_scope') order by n) from jsonb_array_elements(refs) with ordinality x(r,n) where r->>'context_role' in ('PATENT','EVIDENCE'))) else '{}'::jsonb end));
 insert into sep_outputs values(label0,out0);return out0;
end$$;
select pg_temp.sep_output('Summary','GAP_ANALYSIS','{"gap":"Potential gap","evidence":"Summary of verified source, still AI analysis","why_it_matters":"Possible impact","candidate_direction":"Human review","verification_needed":"Provider confidence 100% does not verify this output"}');
select pg_temp.sep_output('Comparison','COMPARATIVE_ANALYSIS','{"similarities":"Source observations","differences":"Tentative interpretation","assumptions":"Unverified AI comparison","source_references":"Suggested https://example.test/unreviewed is not trusted evidence","verification_needed":"Human review"}');
select pg_temp.sep_output('Patent','PATENT_RESEARCH_ASSISTANCE','{"search_terms":"Proposed terms","source_observations":[{"observation":"Source-backed technical observation","source_reference":"source-001","interpretation":"Tentative correspondence","uncertainty":"Exact source location unavailable","location_kind":"UNSPECIFIED","location":""},{"observation":"Patent source describes an element","source_reference":"source-004","interpretation":"Possible technical relation","uncertainty":"Human source review needed","location_kind":"UNSPECIFIED","location":""}],"interpretation":"Unverified AI interpretation","uncertainty":"Needs source review","verification_needed":"Human source review","assessment_scope":"TECHNICAL_OBSERVATIONS_ONLY"}');
-- Existing M14.15 and M14.16 canonical commands are exercised with tripwires.
select public.convert_ai_output_to_candidate(pg_temp.cv_request('Team'));
select public.apply_ai_artifact_revision(pg_temp.ar_request('Team'));
do $$begin
 assert exists(select 1 from public.evidence where id=pg_temp.research_source('Evidence') and verification_status='VERIFIED');
 assert (select count(*) from sep_outputs)=3;
 assert not exists(select 1 from sep_outputs x join public.ai_outputs a on a.id=x.id where a.verification_status<>'UNVERIFIED' or a.disposition<>'KEEP_FOR_REVIEW' or a.output_type not in ('ANALYSIS','COMPARISON'));
 assert (select count(*) from public.ai_context_references r join sep_outputs o on o.id=r.ai_output_id where r.entity_type='EVIDENCE' and r.entity_id=pg_temp.research_source('Evidence'))=3;
 assert (select count(*) from public.ai_context_references r join sep_outputs o on o.id=r.ai_output_id where o.label='Patent' and r.entity_type='PATENT_RECORD' and r.context_role='PATENT' and r.entity_id=pg_temp.research_source('Patent'))=1;
 assert not exists(select 1 from public.ai_outputs a join sep_outputs o on o.id=a.id where o.label='Patent' and (a.response_text::jsonb->>'assessment_scope'<>'TECHNICAL_OBSERVATIONS_ONLY' or jsonb_array_length(a.response_text::jsonb->'source_observations')<>2));
 assert not exists(select 1 from public.ai_outputs a join sep_outputs o on o.id=a.id where o.label='Patent' and jsonb_array_length(a.metadata->'source_references')<>2);
 assert (select count(*) from public.ai_outputs a join sep_outputs o on o.id=a.id cross join lateral jsonb_array_elements(a.metadata->'source_references') binding join public.ai_context_references r on r.ai_output_id=a.id and r.entity_id=(binding->>'entity_id')::uuid and r.context_role::text=binding->>'context_role' and r.included_snapshot_hash=binding->>'included_snapshot_hash' where o.label='Patent')=2,'Stored aliases bind canonical source/hash references';
 assert pg_temp.sep_state()=(select body from sep_before),'All Evidence content, source, verification, history, links and Decisions unchanged';
end$$;
drop trigger sep_evidence on public.evidence;drop trigger sep_links on public.evidence_links;drop trigger sep_history on public.evidence_verification_history;
drop trigger sep_patents on public.patent_records;
-- Only an explicit canonical human operation creates source-backed Evidence.
create temporary table sep_human as select public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'MEASUREMENT','Human source','Human reviewed observations','Recorded lab notebook') body from logged_projects where label='Team';
do $$begin
 assert (select body->>'verification_status' from sep_human)='UNVERIFIED';
 assert (select body->>'created_by' from sep_human)='00000000-0000-4000-8000-000000006004';
 assert not exists(select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='evidence_type' and e.enumlabel='AI_OUTPUT');
end$$;
\echo M14.17 AT-EV-002 real-AI/verified-source/summary/comparison/patent/candidate/artifact/no-Evidence-mutation/human-only PASS
\echo M14.28 Patent/Evidence source-immutability/structured-analysis/UNVERIFIED/context-reference/no-auto-Evidence PASS
rollback;
