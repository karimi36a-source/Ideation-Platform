\set ON_ERROR_STOP on
begin;
create function pg_temp.revcheck(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'M15.22 assertion: %',label;end if;end$$;
create temporary table r_fixture(label text primary key,payload jsonb);grant select,insert on r_fixture to authenticated;
insert into r_fixture select 'Cohort',jsonb_build_object('id',cohort_id) from public.teams where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A');
-- An independently scoped A2 Personal revision; Share to Team A must not expose it.
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,started_by,started_at,status,configuration_snapshot)
 select '00000000-0000-4000-8000-000000098102',(select (payload->>'id')::uuid from r_fixture where label='Cohort'),(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'00000000-0000-4000-8000-000000006005',clock_timestamp(),'active','{}' from public.current_work_fixture where label='A2 Project';
insert into r_fixture select 'A2 Instance',jsonb_build_object('id',id) from public.activity_instances where project_id=(select (payload->>'id')::uuid from public.current_work_fixture where label='A2 Project');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into r_fixture select 'A2 Submission',public.submit_artifact((select (payload->>'artifactId')::uuid from public.current_work_fixture where label='A2 Artifact'),(select (payload->>'initialVersionId')::uuid from public.current_work_fixture where label='A2 Artifact'),(select (payload->>'id')::uuid from r_fixture where label='A2 Instance'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((payload->>'id')::uuid) from r_fixture where label='A2 Submission';
select public.request_revision((payload->>'id')::uuid,'PRIVATE_A2_FEEDBACK_MUST_NOT_LEAK') from r_fixture where label='A2 Submission';
insert into r_fixture select 'Master status',public.get_revision_status((select (payload->>'id')::uuid from r_fixture where label='Cohort'));
select pg_temp.revcheck((select jsonb_array_length(payload->'outstanding')=2 and payload::text not like '%PRIVATE_A2_FEEDBACK%' and payload::text not like '%DO_NOT_RETURN%' and payload::text not like '%content_snapshot%' from r_fixture where label='Master status'),'assigned Master exact metadata, no body');
select pg_temp.revcheck(not exists(select 1 from r_fixture r,jsonb_array_elements(r.payload->'outstanding') x where r.label='Master status' and x->'drafts'<>'[]'::jsonb),'Master cannot enumerate unpublished Drafts');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into r_fixture values('A1 before',public.get_revision_status());
select pg_temp.revcheck((select jsonb_array_length(payload->'outstanding')=1 and payload->'outstanding'->0->>'submissionId'=(select payload->>'id' from public.current_work_fixture where label='Revision') and jsonb_array_length(payload->'outstanding'->0->'drafts')=1 from r_fixture where label='A1 before'),'A1 sees Team revision and canonical V3 Draft only, not A2 Personal Share source');
select pg_temp.revcheck(public.get_revision_status()=(select payload from r_fixture where label='A1 before'),'refresh independent of notification delivery');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.revcheck(jsonb_array_length(public.get_revision_status()->'outstanding')=2,'A2 own Personal plus own Team revision');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.revcheck(public.get_revision_status()='{"outstanding":[],"history":[]}'::jsonb,'Team B cannot enumerate Team A revision');
do $$begin
 begin perform public.get_revision_status((select (payload->>'id')::uuid from r_fixture where label='Cohort'));raise exception 'Role-only Student succeeded';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
 begin perform public.get_revision_status((select (payload->>'id')::uuid from r_fixture where label='Cohort'));raise exception 'Unrelated Master succeeded';exception when insufficient_privilege then null;end;
 begin perform public.get_revision_status((select (payload->>'id')::uuid from public.current_work_fixture where label='Revision'));raise exception 'Exact Submission ID widened scope';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.revcheck(public.get_revision_status()='{"outstanding":[],"history":[]}'::jsonb,'removed member loses revision metadata and Draft references');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.assign_master_to_cohort((select (payload->>'id')::uuid from r_fixture where label='Cohort'),'00000000-0000-4000-8000-000000006003');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.get_revision_status((select (payload->>'id')::uuid from r_fixture where label='Cohort'));raise exception 'Revoked Master succeeded';exception when insufficient_privilege then null;end;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.revcheck(public.get_revision_status((select (payload->>'id')::uuid from r_fixture where label='Cohort'))='{"outstanding":[],"history":[]}'::jsonb,'replacement does not inherit historical revision authority');
select pg_temp.revcheck(not exists(select 1 from jsonb_array_elements(public.get_master_cohort_overview((select (payload->>'id')::uuid from r_fixture where label='Cohort'))->'teams') t,jsonb_array_elements(t->'projects') p where p->'revisionRequested'->>'pending'='true'),'Master overview same immutable-reviewer boundary');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into r_fixture select 'Successor',public.submit_artifact((select (payload->>'artifactId')::uuid from public.current_work_fixture where label='Artifact Team'),(select (payload->>'id')::uuid from public.current_work_fixture where label='V3'),(select (payload->>'id')::uuid from public.current_work_fixture where label='Instance Team'));
select pg_temp.revcheck(not exists(select 1 from jsonb_array_elements(public.get_revision_status()->'outstanding') x where x->>'submissionId'=(select payload->>'id' from public.current_work_fixture where label='Revision')),'S2 closes S1 obligation');
select pg_temp.revcheck(exists(select 1 from jsonb_array_elements(public.get_revision_status()->'history') x where x->>'submissionId'=(select payload->>'id' from public.current_work_fixture where label='Revision') and x->'version'->>'id'=(select payload->>'id' from public.current_work_fixture where label='V2') and x->>'status'='REVISION_REQUESTED' and x->>'hasSuccessor'='true'),'S1/V2 immutable history and successor state preserved');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select pg_temp.revcheck(exists(select 1 from jsonb_array_elements(public.get_pending_review_queue((select (payload->>'id')::uuid from r_fixture where label='Cohort'))->'items') x where x->>'submissionId'=(select payload->>'id' from r_fixture where label='Successor')),'S2 enters new reviewer pending queue');
select public.start_review((payload->>'id')::uuid) from r_fixture where label='Successor';
select public.approve_artifact((payload->>'id')::uuid,null) from r_fixture where label='Successor';
select pg_temp.revcheck(public.get_revision_status((select (payload->>'id')::uuid from r_fixture where label='Cohort'))='{"outstanding":[],"history":[]}'::jsonb,'approved successor is not an outstanding revision');
reset role;
select pg_temp.revcheck(not has_function_privilege('authenticated','private.revision_state(uuid)','execute') and not has_function_privilege('anon','public.get_revision_status(uuid)','execute'),'internal state has no direct-ID capability; public authenticated-only');
select pg_temp.revcheck(to_regclass('public.revision_queue') is null and to_regclass('public.revision_status') is null,'no parallel revision persistence');
rollback;
\echo M15.22 revision lifecycle/current authority/Personal-Team isolation/refresh tests PASS
