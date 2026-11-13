\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into public.current_work_fixture select 'M1519 Other Cohort',jsonb_build_object('id',id) from public.cohorts where primary_master_id='00000000-0000-4000-8000-000000006003';
insert into public.current_work_fixture select 'M1519 Other Team',public.create_team(id,'Other Cohort private Team') from public.cohorts where primary_master_id='00000000-0000-4000-8000-000000006003';
reset role;
create function pg_temp.check_true(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'M15.19 assertion: %',label;end if;end$$;
create temporary table overview_before(payload jsonb);grant select,insert on overview_before to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into overview_before select public.get_master_cohort_overview((select cohort_id from public.teams where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A')));
select pg_temp.check_true((select jsonb_array_length(payload->'teams')>=1 from overview_before),'assigned Master sees Team operational metadata');
select pg_temp.check_true((select payload::text not like '%'||(select f.payload->>'teamId' from public.current_work_fixture f where label='M1519 Other Team')||'%' from overview_before),'cross-Cohort Team excluded');
select pg_temp.check_true((select payload::text not like '%DO_NOT_RETURN%' and payload::text not like '%A2 PRIVATE%' and payload::text not like '%content_snapshot%' and payload::text not like '%configuration_snapshot%' and payload::text not like '%feedback%' and payload::text not like '%chat%' from overview_before),'no private content/Personal/feedback/chat projection');
select pg_temp.check_true((select exists(select 1 from jsonb_array_elements(payload->'teams') t,jsonb_array_elements(t->'projects') p where p->'project'->>'id'=(select f.payload->>'id' from public.current_work_fixture f where label='Project Team')) from overview_before),'exact Team Project');
select pg_temp.check_true((select exists(select 1 from jsonb_array_elements(payload->'teams') t,jsonb_array_elements(t->'projects') p where (p->'pendingReview'->>'count')::int=0 and p->'revisionRequested'->>'pending'='true' and exists(select 1 from jsonb_array_elements(p->'approvedOutputs') v where v->>'versionId'=(select f.payload->>'initialVersionId' from public.current_work_fixture f where label='Artifact Team'))) from overview_before),'approved V1 preserved despite V2 revision and V3 Draft; revision is not review');
select pg_temp.check_true((select exists(select 1 from jsonb_array_elements(payload->'teams') t,jsonb_array_elements(t->'projects') p where jsonb_array_length(p->'activities')=2 and p->>'lastMeaningfulWorkflowUpdateAt' is not null) from overview_before),'multiple existing canonical Activity candidates; meaningful timestamp');
select pg_temp.check_true((select payload::text not like '%'||(select f.payload->>'id' from public.current_work_fixture f where label='Project Individual')||'%' from overview_before),'Personal Project ID excluded');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.send_team_chat_message((select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A'),'M1519_CHAT_MUST_REMAIN_PRIVATE');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.check_true(public.get_master_cohort_overview((select (payload->'cohort'->>'id')::uuid from overview_before))=(select payload from overview_before),'chat does not change overview or meaningful workflow timestamp');
-- The overview does not broaden the existing exact source RLS.
select pg_temp.check_true(not exists(select 1 from public.artifact_versions where id=(select (payload->>'id')::uuid from public.current_work_fixture where label='V3')),'private unpublished V3 stays inaccessible to Master');
do $$declare cid uuid;uid text;begin
 select (payload->'cohort'->>'id')::uuid into cid from overview_before;
 foreach uid in array array['00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',uid,true);
  begin perform public.get_master_cohort_overview(cid);raise exception 'Unauthorized actor succeeded';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 begin perform public.get_master_cohort_overview((select (payload->>'id')::uuid from public.current_work_fixture where label='M1519 Other Cohort'));raise exception 'Foreign Cohort succeeded';exception when insufficient_privilege then null;end;
 begin perform public.get_master_cohort_overview('00000000-0000-4000-8000-999999999999');raise exception 'Guessed Cohort succeeded';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select pg_temp.check_true(public.get_master_cohort_overview((select (payload->'cohort'->>'id')::uuid from overview_before))->'cohort'=(select payload->'cohort' from overview_before),'canonical organization Admin read supported');
reset role;
select pg_temp.check_true(not has_function_privilege('anon','public.get_master_cohort_overview(uuid)','execute') and not has_function_privilege('service_role','public.get_master_cohort_overview(uuid)','execute'),'minimal authenticated-only grants');
select pg_temp.check_true((select proconfig @> array['search_path=""'] and provolatile='s' and prosecdef from pg_proc where oid='public.get_master_cohort_overview(uuid)'::regprocedure),'read-only fixed search path');
-- Membership counts use current canonical rows. A removed member leaves history.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A'),'00000000-0000-4000-8000-000000006004',null);
select pg_temp.check_true((select (t->>'activeMemberCount')::int=(select (old_t->>'activeMemberCount')::int-1 from overview_before o,jsonb_array_elements(o.payload->'teams') old_t where old_t->'team'->>'id'=t->'team'->>'id') from jsonb_array_elements(public.get_master_cohort_overview((select (payload->'cohort'->>'id')::uuid from overview_before))->'teams') t where t->'team'->>'id'=(select payload->>'teamId' from public.current_work_fixture where label='Team A')),'removed membership excluded');
reset role;
-- No chat/view telemetry enters the canonical timestamp sources.
select pg_temp.check_true(pg_get_functiondef('public.get_master_cohort_overview(uuid)'::regprocedure) not like '%public.chat%' and pg_get_functiondef('public.get_master_cohort_overview(uuid)'::regprocedure) not like '%public.ai_%','no private/telemetry source joins');
rollback;
-- A separate transaction verifies new submission closes old revision and becomes review action.
begin;
create temporary table pending_overview(payload jsonb);grant select,insert on pending_overview to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.submit_artifact((select (payload->>'artifactId')::uuid from public.current_work_fixture where label='Artifact Team'),(select (payload->>'id')::uuid from public.current_work_fixture where label='V3'),(select (payload->>'id')::uuid from public.current_work_fixture where label='Instance Team'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into pending_overview select public.get_master_cohort_overview((select cohort_id from public.teams where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A')));
do $$begin if not exists(select 1 from pending_overview o,jsonb_array_elements(o.payload->'teams') t,jsonb_array_elements(t->'projects') p where (p->'pendingReview'->>'count')::int=1 and p->'revisionRequested'->>'pending'='false') then raise exception 'New submission review/revision derivation failed';end if;end$$;
rollback;
begin;
update public.development_projects set status='archived',archived_at=clock_timestamp() where id=(select (payload->>'id')::uuid from public.current_work_fixture where label='Project Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare result jsonb;begin
 result:=public.get_master_cohort_overview((select cohort_id from public.teams where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A')));
 if not exists(select 1 from jsonb_array_elements(result->'teams') t where t->'team'->>'id'=(select payload->>'teamId' from public.current_work_fixture where label='Team A') and t->'projects'='[]'::jsonb) then raise exception 'Archived Project was retained as active work';end if;
end$$;
rollback;
-- Expiration/removal of assignment denies new calls, regardless of known valid IDs.
begin;
create temporary table master_expiry(cid uuid);grant select on master_expiry to authenticated;
insert into master_expiry select cohort_id from public.teams where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A');
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select cid from master_expiry);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.get_master_cohort_overview((select cid from master_expiry));raise exception 'Inactive assignment succeeded';exception when insufficient_privilege then null;end;end$$;
rollback;
\echo M15.19 Master Cohort overview runtime/privacy/review/removal/assignment tests PASS





