\set ON_ERROR_STOP on
begin;
create function pg_temp.queue_check(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'M15.21 assertion: %',label;end if;end$$;
create temporary table q_fixture(label text primary key,payload jsonb);grant select,insert on q_fixture to authenticated;
insert into q_fixture select 'Cohort',jsonb_build_object('id',cohort_id) from public.teams where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A');
insert into q_fixture select 'Other Cohort',jsonb_build_object('id',id) from public.cohorts where primary_master_id='00000000-0000-4000-8000-000000006003';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.queue_check(public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'))='{"items":[]}'::jsonb,'approved and revision-requested history is not pending');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into q_fixture select 'Team submission',public.submit_artifact((select (payload->>'artifactId')::uuid from public.current_work_fixture where label='Artifact Team'),(select (payload->>'id')::uuid from public.current_work_fixture where label='V3'),(select (payload->>'id')::uuid from public.current_work_fixture where label='Instance Team'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into q_fixture select 'Personal submission',public.submit_artifact((select (payload->>'artifactId')::uuid from public.current_work_fixture where label='Artifact Personal'),(select (payload->>'initialVersionId')::uuid from public.current_work_fixture where label='Artifact Personal'),(select (payload->>'id')::uuid from public.current_work_fixture where label='Instance Individual'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into q_fixture select 'Queue',public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'));
select pg_temp.queue_check((select jsonb_array_length(payload->'items')=2 from q_fixture where label='Queue'),'authorized Team and exact Personal submitted target only');
select pg_temp.queue_check((select payload->'items'->0->>'submissionId'=(select payload->>'id' from q_fixture where label='Team submission') and payload->'items'->1->>'submissionId'=(select payload->>'id' from q_fixture where label='Personal submission') from q_fixture where label='Queue'),'oldest submission first');
select pg_temp.queue_check((select payload::text not like '%content_snapshot%' and payload::text not like '%feedback%' and payload::text not like '%DO_NOT_RETURN%' and payload::text not like '%chat%' and payload::text not like '%workspace%' and payload::text not like '%Private sibling%' and payload::text not like '%A2 PRIVATE%' from q_fixture where label='Queue'),'minimal metadata, no sibling/Workspace/body leakage');
select pg_temp.queue_check((select payload->'items'->0->'version'->>'id'=(select payload->>'id' from public.current_work_fixture where label='V3') from q_fixture where label='Queue'),'exact submitted Version');
select pg_temp.queue_check((select (p->'pendingReview'->>'count')::int=1 from jsonb_array_elements(public.get_master_cohort_overview((select (payload->>'id')::uuid from q_fixture where label='Cohort'))->'teams') t,jsonb_array_elements(t->'projects') p where p->'project'->>'id'=(select payload->>'id' from public.current_work_fixture where label='Project Team')),'M15.19 Team pending count agrees');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select pg_temp.queue_check(public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'))='{"items":[]}'::jsonb,'organization Admin cannot bypass exact M8 reviewer authority');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare uid text;begin
 foreach uid in array array['00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',uid,true);
  begin perform public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'));raise exception 'Unrelated/role-only actor succeeded';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 begin perform public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Other Cohort'));raise exception 'Cross-Cohort succeeded';exception when insufficient_privilege then null;end;
 begin perform public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Team submission'));raise exception 'Submission ID used as scope succeeded';exception when insufficient_privilege then null;end;
end$$;
-- A newer Draft cannot replace a submitted Version in the queue.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into q_fixture select 'Newer Draft',public.create_artifact_version((payload->>'artifactId')::uuid,'{"private":"NEWER_DRAFT_PRIVATE"}','Later draft') from public.current_work_fixture where label='Artifact Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.queue_check(not exists(select 1 from jsonb_array_elements(public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'))->'items') x where x->'version'->>'id'=(select payload->>'id' from q_fixture where label='Newer Draft')),'newer Draft excluded');
select pg_temp.queue_check(exists(select 1 from jsonb_array_elements(public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'))->'items') x where x->>'submissionId'=(select payload->>'id' from q_fixture where label='Personal submission') and x->'version'->>'id'=(select payload->>'initialVersionId' from public.current_work_fixture where label='Artifact Personal')),'submitted Personal Version remains exact despite newer Draft');
select public.start_review((payload->>'id')::uuid) from q_fixture where label='Team submission';
select public.request_revision((payload->>'id')::uuid,'PRIVATE_FEEDBACK_MUST_NOT_LEAK') from q_fixture where label='Team submission';
select pg_temp.queue_check(not exists(select 1 from jsonb_array_elements(public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'))->'items') x where x->>'submissionId'=(select payload->>'id' from q_fixture where label='Team submission')),'revision immediately leaves queue');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into q_fixture select 'Revision Draft',public.create_revision_draft((payload->>'id')::uuid,'{"private":"REVISION_PRIVATE"}','Human revision') from q_fixture where label='Team submission';
insert into q_fixture select 'Resubmission',public.submit_artifact((select (payload->>'artifactId')::uuid from public.current_work_fixture where label='Artifact Team'),(select (payload->>'id')::uuid from q_fixture where label='Revision Draft'),(select (payload->>'id')::uuid from public.current_work_fixture where label='Instance Team'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.queue_check((select count(*)=1 from jsonb_array_elements(public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'))->'items') x where x->>'submissionId'=(select payload->>'id' from q_fixture where label='Resubmission')),'new canonical resubmission appears exactly once');
select public.start_review((payload->>'id')::uuid) from q_fixture where label='Resubmission';
select public.approve_artifact((payload->>'id')::uuid,null) from q_fixture where label='Resubmission';
select pg_temp.queue_check(not exists(select 1 from jsonb_array_elements(public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'))->'items') x where x->>'submissionId'=(select payload->>'id' from q_fixture where label='Resubmission')),'approval immediately leaves queue');
-- Canonical Cohort reassignment revokes authority but cannot transfer immutable submissions.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.assign_master_to_cohort((select (payload->>'id')::uuid from q_fixture where label='Cohort'),'00000000-0000-4000-8000-000000006003');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'));raise exception 'Revoked Master retained queue';exception when insufficient_privilege then null;end;end$$;
select pg_temp.queue_check(not public.can_review_submission((select (payload->>'id')::uuid from q_fixture where label='Personal submission')),'old exact Submission ID loses current reviewer authority');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.queue_check(public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'))='{"items":[]}'::jsonb,'replacement Master does not inherit orphaned pending review');
select pg_temp.queue_check(not exists(select 1 from public.submissions where id=(select (payload->>'id')::uuid from q_fixture where label='Personal submission')),'replacement direct SQL cannot open orphan');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into q_fixture select 'Future Draft',public.create_artifact_version((payload->>'artifactId')::uuid,'{"private":"FUTURE_WORK_PRIVATE"}','Future work') from public.current_work_fixture where label='Artifact Team';
insert into q_fixture select 'Future submission',public.submit_artifact((select (payload->>'artifactId')::uuid from public.current_work_fixture where label='Artifact Team'),(payload->>'id')::uuid,(select (payload->>'id')::uuid from public.current_work_fixture where label='Instance Team')) from q_fixture where label='Future Draft';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.queue_check((select count(*)=1 from jsonb_array_elements(public.get_pending_review_queue((select (payload->>'id')::uuid from q_fixture where label='Cohort'))->'items') x where x->>'submissionId'=(select payload->>'id' from q_fixture where label='Future submission')),'new canonically assigned Submission appears for replacement Master');
reset role;
select pg_temp.queue_check((select reviewer_user_id='00000000-0000-4000-8000-000000006002' and status='SUBMITTED' from public.submissions where id=(select (payload->>'id')::uuid from q_fixture where label='Personal submission')),'orphan retains original reviewer and pending status unchanged');
do $$begin begin update public.submissions set reviewer_user_id='00000000-0000-4000-8000-000000006003' where id=(select (payload->>'id')::uuid from q_fixture where label='Personal submission');raise exception 'Reviewer immutability lost';exception when check_violation then null;end;end$$;
select pg_temp.queue_check(not has_function_privilege('anon','public.get_pending_review_queue(uuid)','execute') and not has_function_privilege('service_role','public.get_pending_review_queue(uuid)','execute'),'authenticated-only projection');
select pg_temp.queue_check((select provolatile='s' and proconfig @> array['search_path=""'] from pg_proc where oid='public.get_pending_review_queue(uuid)'::regprocedure),'stable read-only, empty search path');
select pg_temp.queue_check(to_regclass('public.pending_review_queue') is null,'no duplicate queue table');
rollback;
\echo M15.21 pending queue authorization/lifecycle/immutable-reviewer/privacy tests PASS



