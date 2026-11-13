reset role;
-- Fresh Definitions/Activity Instances only; never rewrite historical snapshots.
create temporary table cv_activities(label text primary key,id uuid);
alter table public.activity_definitions disable trigger activity_history;
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,ai_role_code,configuration,status)
select ('00000000-0000-4000-8000-'||lpad((141500+n)::text,12,'0'))::uuid,session_definition_id,'M14.15 disposable '||n,
case n when 1 then 'scamper'::public.activity_method_type when 2 then 'brainstorming'::public.activity_method_type else 'comparison'::public.activity_method_type end,
case when n=1 then 'Personal Workspace' else 'Team Workspace' end,141500+n,
case n when 1 then 'STRUCTURED_CREATIVITY_ASSISTANT' when 2 then 'BRAINSTORMING_FACILITATOR' else 'COMPARATIVE_CRITICAL_ANALYST' end,
'{"ai":{"enabled":true}}','active' from public.activity_definitions cross join generate_series(1,3) n where id='00000000-0000-4000-8000-000000149001';
alter table public.activity_definitions enable trigger activity_history;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into cv_activities values('Team',pg_temp.research_context('Session9'));
-- Privileged disposable baseline of fresh executions, matching M14.9 fixtures.
-- No existing execution snapshot or Activity Engine behavior is changed.
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
select ('00000000-0000-4000-8000-'||lpad((141510+n)::text,12,'0'))::uuid,('00000000-0000-4000-8000-'||lpad((141500+n)::text,12,'0'))::uuid,a.cohort_id,(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,case when n=1 then null else a.team_id end,'00000000-0000-4000-8000-000000006004',clock_timestamp(),'active',public.activity_start_snapshot(('00000000-0000-4000-8000-'||lpad((141500+n)::text,12,'0'))::uuid)
from public.activity_instances a cross join generate_series(1,3) n join logged_projects p on p.label=case when n=1 then 'Individual' else 'Team' end where a.id=pg_temp.research_context('Session9');
insert into cv_activities values('Personal','00000000-0000-4000-8000-000000141511'),('Brainstorm','00000000-0000-4000-8000-000000141512'),('Gap','00000000-0000-4000-8000-000000141513');
create temporary table cv_sources(label text primary key,id uuid,original jsonb);
grant select on cv_sources to service_role,authenticated;
create function pg_temp.cv_source(label0 text,activity0 text) returns uuid language plpgsql as $$
declare a public.activity_instances;role0 text;task0 text;kind0 text;method0 text;body0 text;op jsonb;attempt0 jsonb;ref0 jsonb;out0 uuid;begin
 select * into a from public.activity_instances where id=(select id from cv_activities where label=activity0);
 if not found then raise exception 'Missing disposable Activity %',activity0;end if;
 task0:=case activity0 when 'Gap' then 'GAP_ANALYSIS' when 'Brainstorm' then 'BRAINSTORMING_ASSISTANCE' else 'SCAMPER_ASSISTANCE' end;
 role0:=case activity0 when 'Gap' then 'COMPARATIVE_CRITICAL_ANALYST' when 'Brainstorm' then 'BRAINSTORMING_FACILITATOR' else 'STRUCTURED_CREATIVITY_ASSISTANT' end;
 kind0:=case when activity0='Gap' then 'ANALYSIS' else 'SUGGESTION' end;
 body0:=case activity0 when 'Gap' then '{"gap":"Missing function","evidence":"Source observation","why_it_matters":"Impact","candidate_direction":"Investigate","verification_needed":"Human review"}' when 'Brainstorm' then '{"candidate_options":"Option","different_perspectives":"Perspective","assumptions":"Assumption","verification_needed":"Human review"}' else '{"technique":"Combine","original_element":"Source","proposed_change":"Change","reasoning":"Reason","potential_benefit":"Benefit","risk_or_unknown":"Human review"}' end;
 op:=public.begin_ai_task_operation(jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','idempotencyKey','conversion-'||label0,'fingerprint',encode(sha256(convert_to(label0,'UTF8')),'hex'),'projectId',a.project_id,'workspaceId',a.workspace_id,'activityInstanceId',a.id,'taskType',task0,'aiRole',role0,'modelProfile',case when activity0='Gap' then 'AI_DEEP' else 'AI_STANDARD' end));
 attempt0:=jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','operationId',op->>'operationId','attemptId',op->>'attemptId');
 perform public.record_ai_task_attempt(attempt0||'{"inputUsage":10,"outputUsage":10,"latencyMs":1,"successFailure":"SUCCESS"}');
 ref0:=public.resolve_ai_context_source(jsonb_build_object('projectId',a.project_id,'workspaceId',a.workspace_id,'activityInstanceId',a.id,'entityType','ACTIVITY_INSTANCE','entityId',a.id,'contextRole','COURSE_CONTEXT'))-'content';
 out0:=public.save_ai_task_result(attempt0||jsonb_build_object('promptText',task0,'responseText',body0,'outputType',kind0,'references',jsonb_build_array(ref0),'metadata','{}'::jsonb));
 perform public.set_ai_output_disposition(out0,'ACCEPT_AS_CANDIDATE',0);
 insert into cv_sources select label0,out0,to_jsonb(o)-'disposition'-'disposition_revision' from public.ai_outputs o where id=out0;
 return out0;
exception when others then raise exception 'Conversion fixture % / % failed: %',label0,activity0,sqlerrm using errcode=sqlstate;
end$$;
select pg_temp.cv_source(label0,activity0) from (values('Team','Team'),('OtherHuman','Team'),('Brainstorm','Brainstorm'),('Gap','Gap'),('Personal','Personal'),('Rollback','Team'),('Keep','Team'),('Rejected','Team'),('RaceA','Team'),('RaceB','Team')) cases(label0,activity0);
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
select public.set_ai_output_disposition((select id from cv_sources where label='Keep'),'KEEP_FOR_REVIEW',1);
select public.set_ai_output_disposition((select id from cv_sources where label='Rejected'),'REJECTED',1);
-- A structurally plausible legacy row without a completed accepted runtime
-- operation is not a conversion source.
do $$declare source0 public.ai_outputs;legacy0 uuid;begin
 select * into source0 from public.ai_outputs where id=(select id from cv_sources where label='Team');
 insert into public.ai_outputs(project_id,workspace_id,activity_instance_id,ai_role,task_type,prompt_text,response_text,output_type)
 values(source0.project_id,source0.workspace_id,source0.activity_instance_id,source0.ai_role,source0.task_type,'Legacy fixture',source0.response_text,source0.output_type) returning id into legacy0;
 perform public.set_ai_output_disposition(legacy0,'ACCEPT_AS_CANDIDATE',0);
 insert into cv_sources select 'Legacy',id,to_jsonb(o)-'disposition'-'disposition_revision' from public.ai_outputs o where id=legacy0;
end$$;
create function pg_temp.cv_request(label0 text,kind0 text default 'IDEA') returns jsonb language sql security definer set search_path='' as $$select jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','aiOutputId',s.id,'targetObjectType',kind0,'candidateTitle','Human-confirmed '||label0,'candidateContent',o.response_text,'confirmed',true,'sourceResponseHash',encode(sha256(convert_to(o.response_text,'UTF8')),'hex')) from cv_sources s join public.ai_outputs o on o.id=s.id where label=label0$$;
-- CONVERSION TESTS
-- M14.30: conversion/replay must not mutate unrelated governance domains.
create function pg_temp.cv_governance_history() returns jsonb language plpgsql as $$
declare result0 jsonb:='{}';table0 text;rows0 jsonb;begin
 foreach table0 in array array['artifacts','project_baseline_items','team_memberships','mind_maps','mind_map_nodes','mind_map_edges','session10_reconstruction_checkpoints','ai_usage_events'] loop
  execute format('select coalesce(jsonb_agg(to_jsonb(t) order by id),''[]''::jsonb) from public.%I t',table0) into rows0;
  result0:=result0||jsonb_build_object(table0,rows0);
 end loop;return result0;
end$$;
create temporary table cv_governance_before as select pg_temp.cv_governance_history() body;
create temporary table cv_before as select (select count(*) from public.evidence) evidence_count,(select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p) projects,(select jsonb_agg(to_jsonb(a) order by id) from public.artifact_versions a) versions,(select count(*) from public.decisions) decisions,(select count(*) from public.shares) shares,(select jsonb_agg(to_jsonb(r) order by id) from public.ai_context_references r) refs;
set local role service_role;
select public.convert_ai_output_to_candidate(pg_temp.cv_request('Team'));
select public.convert_ai_output_to_candidate(pg_temp.cv_request('Team'));
select public.convert_ai_output_to_candidate(pg_temp.cv_request('Brainstorm'));
select public.convert_ai_output_to_candidate(pg_temp.cv_request('Gap','GAP'));
select public.convert_ai_output_to_candidate(pg_temp.cv_request('Personal'));
select public.convert_ai_output_to_candidate(pg_temp.cv_request('OtherHuman')||'{"actorId":"00000000-0000-4000-8000-000000006005"}');
do $$begin
 perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Team','GAP')),'23505');
 perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Team')||'{"candidateTitle":"Changed"}'),'23505');
 perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Rollback','GAP')),'22023');
 perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Keep')),'55000');
 perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Rejected')),'55000');
 perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Legacy')),'22000');
 perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Rollback')||'{"confirmed":false}'),'22023');
 perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Rollback')||'{"candidateTitle":" "}'),'22023');
end$$;
reset role;
do $$begin
 assert (select count(*) from public.development_objects where origin_type='AI' and origin_reference_id is not null)=5;
 assert (select count(*) from public.idea_details d join public.development_objects o on o.id=d.development_object_id where o.origin_type='AI' and d.acceptance_state='candidate')=4;
 assert not exists(select 1 from public.development_objects where origin_type='AI' and (status is not null or verification_status is not null or current_version_number<>1 or archived_at is not null or created_by not in ('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005')));
 assert exists(select 1 from public.development_objects where origin_type='AI' and origin_reference_id=(select id from cv_sources where label='OtherHuman') and created_by='00000000-0000-4000-8000-000000006005');
 assert (select count(*) from public.ai_outputs where disposition='CONVERTED_TO_PROJECT_OBJECT')=5;
 assert not exists(select 1 from cv_sources s join public.ai_outputs o on o.id=s.id where s.original is distinct from to_jsonb(o)-'disposition'-'disposition_revision');
 assert (select count(*) from public.change_log where related_ai_output_id in(select id from cv_sources) and entity_type='DEVELOPMENT_OBJECT')=5;
 assert not exists(select 1 from public.change_log c join public.ai_outputs a on a.id=c.related_ai_output_id where c.entity_type='DEVELOPMENT_OBJECT' and ((c.reason::jsonb->>'original_requested_by')::uuid<>a.requested_by or c.reason::jsonb->>'ai_role'<>a.ai_role or c.reason::jsonb->>'task_type'<>a.task_type or c.reason::jsonb->>'output_type'<>a.output_type::text or c.changed_by<>(c.reason::jsonb->>'human_confirmed_by')::uuid));
 perform pg_temp.research_bad(format('select public.set_ai_output_disposition(%L,''KEEP_FOR_REVIEW'',2)',(select id from cv_sources where label='Team')),'22023');
 perform pg_temp.research_bad(format('update public.ai_outputs set response_text=''Forged'' where id=%L',(select id from cv_sources where label='Team')),'55000');
 perform pg_temp.research_bad(format('update public.development_objects set origin_reference_id=gen_random_uuid() where origin_type=''AI'' and origin_reference_id=%L',(select id from cv_sources where label='Team')),'23514');
end$$;
-- Force each required durable step to fail; every prior step must roll back.
create function pg_temp.cv_force_fail() returns trigger language plpgsql as $$begin raise exception 'Forced conversion failure' using errcode='23514';end$$;
do $$declare target0 text;before0 bigint;begin
 foreach target0 in array array['development_objects','idea_details','change_log','ai_outputs'] loop
  select count(*) into before0 from public.development_objects;
  execute format('create trigger cv_forced_failure before %s on public.%I for each row execute function pg_temp.cv_force_fail()',case when target0='ai_outputs' then 'update' else 'insert' end,target0);
  perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Rollback')),'23514');
  execute format('drop trigger cv_forced_failure on public.%I',target0);
  assert (select count(*) from public.development_objects)=before0;
  assert (select disposition='ACCEPT_AS_CANDIDATE' from public.ai_outputs where id=(select id from cv_sources where label='Rollback'));
  assert not exists(select 1 from public.development_objects where origin_type='AI' and origin_reference_id=(select id from cv_sources where label='Rollback'));
 end loop;
end$$;
select public.convert_ai_output_to_candidate(pg_temp.cv_request('Rollback')||'{"candidateContent":"Explicit human draft"}');
-- Valid conversion also works inside a caller savepoint/subtransaction.
do $$begin begin
 perform public.convert_ai_output_to_candidate(pg_temp.cv_request('RaceB'));
exception when others then raise;end;end$$;
-- Direct clients cannot call the server attestation RPC or forge provenance.
set local role authenticated;
do $$begin
 perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('RaceA')),'42501');
 perform pg_temp.research_bad('update public.ai_outputs set disposition=''CONVERTED_TO_PROJECT_OBJECT''','42501');
 perform pg_temp.research_bad('insert into public.development_objects default values','42501');
end$$;
reset role;
do $$declare u text;begin
 foreach u in array array['00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008'] loop
  perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('RaceA')||jsonb_build_object('actorId',u)),'42501');
  perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('Personal')||jsonb_build_object('actorId',u)),'42501');
 end loop;
end$$;
-- Assert before the fixture deliberately removes its source member.
do $$begin assert pg_temp.cv_governance_history()=(select body from cv_governance_before),'Candidate conversion/replay mutated unrelated governance or fabricated usage';end$$;
\echo M14.30 Candidate-retry baseline/current/membership/Mind-Map/checkpoint/usage history PASS
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.15 removal');
do $$begin perform pg_temp.research_bad(format('select public.convert_ai_output_to_candidate(%L::jsonb)',pg_temp.cv_request('RaceA')),'42501');end$$;
do $$begin
 assert not exists(select 1 from cv_sources s join public.ai_outputs o on o.id=s.id where s.original is distinct from to_jsonb(o)-'disposition'-'disposition_revision');
 assert (select count(*) from public.evidence)=(select evidence_count from cv_before);
 assert (select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p)=(select projects from cv_before);
 assert (select jsonb_agg(to_jsonb(a) order by id) from public.artifact_versions a)=(select versions from cv_before);
 assert (select count(*) from public.decisions)=(select decisions from cv_before);
 assert (select count(*) from public.shares)=(select shares from cv_before);
 assert (select jsonb_agg(to_jsonb(r) order by id) from public.ai_context_references r)=(select refs from cv_before);
 assert not has_function_privilege('authenticated','public.convert_ai_output_to_candidate(jsonb)','EXECUTE');
 assert not has_function_privilege('anon','public.convert_ai_output_to_candidate(jsonb)','EXECUTE');
end$$;
select 'M14.15 AT-AI-008 Personal/Team/SCAMPER/Brainstorm/Gap/candidate/AI-provenance/confirmation/atomicity/retry/privacy/governance PASS';
rollback;


