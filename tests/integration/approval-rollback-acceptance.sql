-- AT-TX-001. Prepend canonical M8.14 fixture through start_review.
-- Only disposable-cluster test DDL; no production fault API or migrations.
create temporary table tx_context(sid uuid,aid uuid,vid uuid,prior uuid,stage text);
insert into tx_context select (data->>'id')::uuid,(data->>'artifact_id')::uuid,(data->>'artifact_version_id')::uuid,null,null from artifact_handoff where label='submission';
grant select on tx_context to authenticated,anon;
select public.add_feedback('ARTIFACT',(select aid from tx_context),(select vid from tx_context),'COMMENT','Preserve first review feedback');
reset role;
create temporary table tx_evidence(kind text,stage text);

create function pg_temp.tx_state() returns jsonb language sql as $$
 select jsonb_build_object(
 'artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),
 'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),
 'submissions',(select jsonb_agg(to_jsonb(x) order by id) from public.submissions x),
 'actions',(select jsonb_agg(to_jsonb(x) order by id) from public.review_actions x),
 'audit',(select jsonb_agg(to_jsonb(x) order by id) from public.audit_events x),
 'feedback',(select jsonb_agg(to_jsonb(x) order by id) from public.feedback_items x),
 'activities',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x),
 'baseline',(select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x),
 'notifications',(select jsonb_agg(to_jsonb(x) order by id) from public.notifications x),
 'inputs',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_inputs x),
 'outputs',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_outputs x),
 'links',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_object_links x),
 'objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x));
$$;
-- This function is a trigger only. Its assertions prove the specified write
-- really happened before the exception, including all earlier transaction writes.
create function pg_temp.tx_fault() returns trigger language plpgsql set search_path='' as $$
declare c record;hit boolean;begin
 select * into c from pg_temp.tx_context;
 hit:=case c.stage
 when 'supersession' then tg_table_name='artifact_versions' and new.id=c.prior
 when 'version' then tg_table_name='artifact_versions' and new.id=c.vid
 when 'pointer' then tg_table_name='artifacts' and new.id=c.aid
 when 'submission' then tg_table_name='submissions' and new.id=c.sid
 when 'action' then tg_table_name='review_actions'
 when 'audit' then tg_table_name='audit_events'
 when 'notification' then tg_table_name='notifications' and (to_jsonb(new)->>'entity_id')::uuid=c.sid
 else false end;
 if not hit then return new;end if;
 if c.prior is not null then
  assert (select status from public.artifact_versions where id=c.prior)='SUPERSEDED','prior write not observed';
 end if;
 if c.stage<>'supersession' then
  assert exists(select 1 from public.artifact_versions where id=c.vid and status='CURRENT' and approved_by=auth.uid() and approved_at is not null and approval_note='AT-TX-001 approval'),'new current write not observed';
 end if;
 if c.stage in ('pointer','submission','action','audit','notification') then
  assert (select current_version_id from public.artifacts where id=c.aid)=c.vid,'pointer write not observed';
 end if;
 if c.stage in ('submission','action','audit','notification') then
  assert (select status from public.submissions where id=c.sid)='APPROVED','Submission write not observed';
 end if;
 if c.stage in ('action','audit','notification') then
  assert (select count(*) from public.review_actions where submission_id=c.sid and action_type='APPROVED')=1,'action write not observed';
 end if;
 if c.stage in ('audit','notification') then
  assert (select count(*) from public.audit_events where entity_id=c.sid and event_type='ARTIFACT_APPROVED')=1,'audit write not observed';
 end if;
 raise exception 'AT-TX-001 injected %',c.stage using errcode='P0002';
end$$;
revoke all on function pg_temp.tx_fault() from public,anon,authenticated,service_role;
revoke all on function pg_temp.tx_state() from public,anon,authenticated,service_role;

-- Install hooks as the disposable cluster owner, then execute the actual RPC
-- as the authenticated assigned reviewer. Catch only the exact injected error.
create function pg_temp.run_tx_faults(kind text,stages text[]) returns void language plpgsql as $$
declare stage0 text;target_table text;before0 jsonb;deps jsonb;candidates jsonb;message0 text;c record;begin
 foreach stage0 in array stages loop
  update pg_temp.tx_context set stage=stage0;
  select * into c from pg_temp.tx_context;
  before0:=pg_temp.tx_state();
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
  set local role authenticated;
  deps:=pg_temp.artifact_deps('00000000-0000-4000-8000-000000740803');
  candidates:=pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803');
  if c.prior is null then
   assert deps->>'satisfied'='false' and jsonb_array_length(candidates)=0,'first approval dependency already unlocked';
  else
   assert deps->>'satisfied'='true' and exists(select 1 from jsonb_array_elements(candidates) x where x->>'artifactVersionId'=c.prior::text),'prior committed CURRENT must remain valid';
  end if;
  reset role;
  target_table:=case stage0 when 'supersession' then 'artifact_versions' when 'version' then 'artifact_versions' when 'pointer' then 'artifacts' when 'submission' then 'submissions' when 'action' then 'review_actions' when 'notification' then 'notifications' else 'audit_events' end;
  execute format('create trigger tx_injection after %s on public.%I for each row execute function pg_temp.tx_fault()',case when stage0 in ('action','audit','notification') then 'insert' else 'update' end,target_table);
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
  set local role authenticated;
  begin
   perform public.approve_artifact(c.sid,'AT-TX-001 approval');
   raise exception 'Approval returned success despite injected fault';
  exception when no_data_found then
   get stacked diagnostics message0=message_text;
   assert message0='AT-TX-001 injected '||stage0,'unexpected error instead of boundary injection';
  end;
  reset role;
  execute format('drop trigger tx_injection on public.%I',target_table);
  assert before0=pg_temp.tx_state(),'persistent state changed at '||stage0;
  assert (select status from public.submissions where id=c.sid)='UNDER_REVIEW';
  assert exists(select 1 from public.artifact_versions where id=c.vid and status='UNDER_REVIEW' and approved_by is null and approved_at is null and approval_note is null);
  assert (select current_version_id from public.artifacts where id=c.aid) is not distinct from c.prior;
  assert (select count(*) from public.artifact_versions where artifact_id=c.aid and status='CURRENT')=case when c.prior is null then 0 else 1 end;
  assert not exists(select 1 from public.review_actions where submission_id=c.sid and action_type='APPROVED');
  assert not exists(select 1 from public.audit_events where entity_id=c.sid and event_type='ARTIFACT_APPROVED');
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
  set local role authenticated;
  assert deps=pg_temp.artifact_deps('00000000-0000-4000-8000-000000740803'),'downstream availability changed after rollback';
  assert candidates=pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803'),'downstream candidates changed after rollback';
  assert not exists(select 1 from jsonb_array_elements(pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803')) x where x->>'artifactVersionId'=c.vid::text),'rolled-back version satisfied approved_output';
  reset role;
  insert into pg_temp.tx_evidence values(kind,stage0);
 end loop;
end$$;
revoke all on function pg_temp.run_tx_faults(text,text[]) from public,anon,authenticated,service_role;

-- First approval: no prior current. Test both new Version and pointer writes.
reset role;
create function pg_temp.tx_pre_fault() returns trigger language plpgsql set search_path='' as $$
declare c record;hit boolean;begin
 select * into c from pg_temp.tx_context;
 hit:=case c.stage when 'version' then tg_table_name='artifact_versions' and new.id=c.vid when 'pointer' then tg_table_name='artifacts' and new.id=c.aid when 'audit' then tg_table_name='audit_events' and (to_jsonb(new)->>'entity_id')::uuid=c.sid else false end;
 if not hit then return new;end if;
 assert auth.uid()='00000000-0000-4000-8000-000000006002'::uuid,'Canonical assigned reviewer';
 raise exception 'AT-TX-001 injected %',c.stage using errcode='P0002';
end$$;
create function pg_temp.run_tx_pre_faults(kind text,stages text[]) returns void language plpgsql as $$
declare stage0 text;target_table text;before0 jsonb;deps jsonb;candidates jsonb;message0 text;c record;begin
 foreach stage0 in array stages loop
  update pg_temp.tx_context set stage=stage0;
  select * into c from pg_temp.tx_context;
  before0:=pg_temp.tx_state();
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
  set local role authenticated;
  deps:=pg_temp.artifact_deps('00000000-0000-4000-8000-000000740803');
  candidates:=pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803');
  if c.prior is null then
   assert deps->>'satisfied'='false' and jsonb_array_length(candidates)=0,'first approval dependency already unlocked';
  else
   assert deps->>'satisfied'='true' and exists(select 1 from jsonb_array_elements(candidates) x where x->>'artifactVersionId'=c.prior::text),'prior committed CURRENT must remain valid';
  end if;
  reset role;
  target_table:=case stage0 when 'supersession' then 'artifact_versions' when 'version' then 'artifact_versions' when 'pointer' then 'artifacts' when 'submission' then 'submissions' when 'action' then 'review_actions' else 'audit_events' end;
  execute format('create trigger tx_injection before %s on public.%I for each row execute function pg_temp.tx_pre_fault()',case when stage0 in ('action','audit') then 'insert' else 'update' end,target_table);
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
  set local role authenticated;
  begin
   perform public.approve_artifact(c.sid,'AT-TX-001 approval');
   raise exception 'Approval returned success despite injected fault';
  exception when no_data_found then
   get stacked diagnostics message0=message_text;
   assert message0='AT-TX-001 injected '||stage0,'unexpected error instead of boundary injection';
  end;
  reset role;
  execute format('drop trigger tx_injection on public.%I',target_table);
  assert before0=pg_temp.tx_state(),'persistent state changed at '||stage0;
  assert (select status from public.submissions where id=c.sid)='UNDER_REVIEW';
  assert exists(select 1 from public.artifact_versions where id=c.vid and status='UNDER_REVIEW' and approved_by is null and approved_at is null and approval_note is null);
  assert (select current_version_id from public.artifacts where id=c.aid) is not distinct from c.prior;
  assert (select count(*) from public.artifact_versions where artifact_id=c.aid and status='CURRENT')=case when c.prior is null then 0 else 1 end;
  assert not exists(select 1 from public.review_actions where submission_id=c.sid and action_type='APPROVED');
  assert not exists(select 1 from public.audit_events where entity_id=c.sid and event_type='ARTIFACT_APPROVED');
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
  set local role authenticated;
  assert deps=pg_temp.artifact_deps('00000000-0000-4000-8000-000000740803'),'downstream availability changed after rollback';
  assert candidates=pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803'),'downstream candidates changed after rollback';
  assert not exists(select 1 from jsonb_array_elements(pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803')) x where x->>'artifactVersionId'=c.vid::text),'rolled-back version satisfied approved_output';
  reset role;
  insert into pg_temp.tx_evidence values(kind,stage0);
 end loop;
end$$;
select pg_temp.run_tx_pre_faults('M17.10 pre-write',array['version','pointer','audit']);
\echo M17.10 after-validation/before-pointer/before-audit rollback PASS


select pg_temp.run_tx_faults('first',array['version','pointer','notification']);
\echo M8.18 first approval Version/pointer rollback + downstream locked PASS

-- Clean normal approval and identical retry after all first-approval failures.
create temporary table tx_success(kind text,data jsonb);
grant select,insert on tx_success to authenticated;
create temporary table tx_unchanged as select pg_temp.tx_state() data;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into tx_success select 'first',public.approve_artifact(sid,'AT-TX-001 approval') from tx_context;
reset role;
create temporary table tx_first_state as select pg_temp.tx_state() data;
create temporary table tx_first_version as select to_jsonb(v) data from public.artifact_versions v where id=(select vid from tx_context);
set local role authenticated;
insert into tx_success select 'firstRetry',public.approve_artifact(sid,'AT-TX-001 approval') from tx_context;
reset role;
do $$declare k text;begin
 assert (select data from tx_success where kind='first')=(select data from tx_success where kind='firstRetry');
 assert (select data from tx_first_state)=pg_temp.tx_state();
 foreach k in array array['feedback','activities','baseline','inputs','outputs','links','objects'] loop
  assert (select data->k from tx_unchanged) is not distinct from (select data->k from tx_first_state),'first approval unrelated mutation '||k;
 end loop;
 assert coalesce(pg_temp.tx_state()->'notifications','[]'::jsonb) @> coalesce((select data->'notifications' from tx_unchanged),'[]'::jsonb),'first approval preserves existing notices';
 assert (select count(*) from public.notifications where entity_id=(select sid from tx_context) and notification_type='ARTIFACT_APPROVED')=jsonb_array_length(public.approval_notification_contexts((select sid from tx_context))),'all canonical first-approval recipients notified';
 assert (select count(*) from public.review_actions where submission_id=(select sid from tx_context) and action_type='APPROVED')=1;
 assert (select count(*) from public.audit_events where entity_id=(select sid from tx_context) and event_type='ARTIFACT_APPROVED')=1;
end$$;

-- Replacement: canonical new Draft / Submission / review, same Artifact.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into artifact_handoff select 'replacement',public.create_artifact_version(aid,'{"revision":"AT-TX-001"}','Rollback acceptance') from tx_context;
insert into artifact_handoff select 'replacementSubmission',public.submit_artifact((select aid from tx_context),(data->>'id')::uuid,(select upstream from artifact_handoff_context)) from artifact_handoff where label='replacement';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((data->>'id')::uuid) from artifact_handoff where label='replacementSubmission';
select public.add_feedback('ARTIFACT',(select aid from tx_context),(select (data->>'id')::uuid from artifact_handoff where label='replacement'),'COMMENT','Preserve this feedback');
reset role;
update tx_context set prior=vid,vid=(select (data->>'id')::uuid from artifact_handoff where label='replacement'),sid=(select (data->>'id')::uuid from artifact_handoff where label='replacementSubmission');
select pg_temp.run_tx_faults('replacement',array['supersession','version','pointer','submission','action','audit','notification']);
\echo M8.18 replacement six AFTER-write boundaries / exact rollback / dependency candidates PASS

-- Test hooks have no execute authority for runtime roles; runtime users cannot
-- install new triggers. No client-controlled fault parameter exists.
do $$declare r text;f regprocedure;begin
 foreach r in array array['anon','authenticated','service_role'] loop
  foreach f in array array['pg_temp.tx_fault()'::regprocedure,'pg_temp.tx_state()'::regprocedure,'pg_temp.run_tx_faults(text,text[])'::regprocedure] loop
   assert not has_function_privilege(r,f,'EXECUTE');
  end loop;
 end loop;
 assert not exists(select 1 from pg_trigger where tgname='tx_injection');
end$$;
set local role authenticated;
do $$declare actor text;begin
 foreach actor in array array['00000000-0000-4000-8000-000000006005','00000000-0000-4000-8000-000000006003'] loop
  perform set_config('request.jwt.claim.sub',actor,true);
  begin perform public.approve_artifact((select sid from tx_context));raise exception 'unauthorized approval accepted';exception when insufficient_privilege then null;end;
 end loop;
 begin perform pg_temp.run_tx_faults('forged',array['audit']);raise exception 'public hook accepted';exception when insufficient_privilege then null;end;
end$$;
reset role;set local role anon;
do $$begin begin perform public.approve_artifact((select sid from tx_context));raise exception 'anonymous approval accepted';exception when insufficient_privilege then null;end;end$$;
reset role;

-- Final successful replacement and exact-state idempotency.
create temporary table tx_before_success as select pg_temp.tx_state() data;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into tx_success select 'replacement',public.approve_artifact(sid,'AT-TX-001 approval') from tx_context;
reset role;
create temporary table tx_after_success as select pg_temp.tx_state() data;
set local role authenticated;
insert into tx_success select 'replacementRetry',public.approve_artifact(sid,'AT-TX-001 approval') from tx_context;
reset role;
do $$declare c record;before0 jsonb;after0 jsonb;k text;begin
 select * into c from tx_context;select data into before0 from tx_before_success;select data into after0 from tx_after_success;
 assert after0=pg_temp.tx_state(),'retry changed persistent state';
 assert (select data from tx_success where kind='replacement')=(select data from tx_success where kind='replacementRetry');
 assert (select status from public.artifact_versions where id=c.prior)='SUPERSEDED';
 assert (select data-'status' from tx_first_version)=(select to_jsonb(v)-'status' from public.artifact_versions v where id=c.prior),'prior approved history altered';
 assert exists(select 1 from public.artifact_versions where id=c.vid and status='CURRENT' and approved_by='00000000-0000-4000-8000-000000006002' and approved_at is not null and approval_note='AT-TX-001 approval');
 assert (select current_version_id from public.artifacts where id=c.aid)=c.vid;
 assert (select status from public.artifacts where id=c.aid)='ACTIVE';
 assert (select status from public.submissions where id=c.sid)='APPROVED';
 assert (select count(*) from public.artifact_versions where artifact_id=c.aid and status='CURRENT')=1;
 assert (select count(*) from public.review_actions where submission_id=c.sid and action_type='APPROVED')=1;
 assert (select count(*) from public.audit_events where entity_id=c.sid and event_type='ARTIFACT_APPROVED' and actor_user_id='00000000-0000-4000-8000-000000006002' and metadata='{}')=1;
 foreach k in array array['feedback','activities','baseline','inputs','outputs','links','objects'] loop assert before0->k is not distinct from after0->k,'unrelated success mutation '||k;end loop;
 assert (select count(*) from public.notifications where entity_id=(select sid from tx_context) and notification_type='ARTIFACT_APPROVED')>0,'canonical approval notices committed';
 assert coalesce(after0->'notifications','[]'::jsonb) @> coalesce(before0->'notifications','[]'::jsonb),'existing notification history retained';
 assert (select count(*) from public.notifications where entity_id=c.sid and notification_type='ARTIFACT_APPROVED')=jsonb_array_length(public.approval_notification_contexts(c.sid)),'all canonical replacement recipients notified';
 assert (select count(*) from tx_evidence where kind='replacement')=7;
 assert (select count(*) from tx_evidence where kind='first')=3;
end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert pg_temp.artifact_deps('00000000-0000-4000-8000-000000740803')->>'satisfied'='true';assert exists(select 1 from jsonb_array_elements(pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803')) x where x->>'artifactVersionId'=(select vid::text from tx_context));end$$;
reset role;
\echo M8.18 AT-TX-001 BLOCKER PASS; success/retry/history/audit/baseline/auth/hook-security PASS; canonical notification insertion is atomic
rollback;
