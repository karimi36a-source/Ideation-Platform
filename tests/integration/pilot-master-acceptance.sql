\set ON_ERROR_STOP on
-- M15.29 reuses the isolated current-work fixture and existing M7/M8/M15 RPCs.
-- No Team membership, source ACL, reviewer transfer, or production code changes.
begin;
create temporary table pm(label text primary key,payload jsonb);
grant select,insert on pm to authenticated,service_role;
insert into pm select label,payload from public.current_work_fixture;
insert into pm select 'Cohort',jsonb_build_object('id',cohort_id) from public.teams where id=(select (payload->>'teamId')::uuid from pm where label='Team A');
insert into pm select 'Foreign',jsonb_build_object('id',id) from public.cohorts where primary_master_id='00000000-0000-4000-8000-000000006003';
create function pg_temp.pmid(k text,f text default 'id') returns uuid language sql as $$select (payload->>f)::uuid from pm where label=k$$;
create function pg_temp.pm_actor(n integer) returns text language sql as $$select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true)$$;
create function pg_temp.pm_check(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'M15.29: %',label;end if;end$$;
create function pg_temp.pm_deny(command text) returns void language plpgsql as $$begin
 begin execute command;exception when insufficient_privilege then return;end;
 raise exception 'M15.29 unexpected authorization success: %',command;
end$$;
-- Reuse the approved post-commit dispatcher contract; no fake notification rows.
create function pg_temp.pm_notify(kind text,sid uuid) returns void language plpgsql as $$declare d jsonb;contexts jsonb;begin
 if kind='SUBMISSION_RECEIVED' then
  contexts:=jsonb_build_array(jsonb_build_object('recipientContext',jsonb_build_object('sourceId',sid),'idempotencyKey','submission-received:'||sid::text));
 elsif kind='REVISION_REQUESTED' then contexts:=public.revision_notification_contexts(sid);
 elsif kind='ARTIFACT_APPROVED' then contexts:=public.approval_notification_contexts(sid);
 else raise exception 'Unknown test notification';end if;
 for d in select value from jsonb_array_elements(contexts) loop
  perform public.create_domain_notification(jsonb_build_object('notificationType',kind,'recipientContext',d->'recipientContext','formatterInput','{}'::jsonb,
   'entityReference',jsonb_build_object('entityType','submission','entityId',sid),'idempotencyKey',d->>'idempotencyKey',
   'title',case kind when 'SUBMISSION_RECEIVED' then 'Submission received' when 'REVISION_REQUESTED' then 'Revision requested' else 'Artifact approved' end,
   'body',case kind when 'SUBMISSION_RECEIVED' then 'A submission is available for your assigned review.' when 'REVISION_REQUESTED' then 'A revision has been requested for a submission.' else 'An Artifact submission has been approved.' end,
   'recipientStrategy',case kind when 'SUBMISSION_RECEIVED' then 'CURRENT_ASSIGNED_SUBMISSION_REVIEWER' else 'CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM' end));
 end loop;
end$$;
set local role authenticated;
select pg_temp.pm_actor(6005);
select public.send_team_chat_message(pg_temp.pmid('Team A','teamId'),'M1529_PRIVATE_TEAM_CHAT');
select pg_temp.pm_actor(6002);
insert into pm select 'Overview',public.get_master_cohort_overview(pg_temp.pmid('Cohort'));
select pg_temp.pm_check((select jsonb_array_length(payload->'teams')=2 from pm where label='Overview'),'assigned Cohort authorized Teams');
select pg_temp.pm_check(exists(select 1 from public.cohorts where id=pg_temp.pmid('Cohort')) and not exists(select 1 from public.cohorts where id=pg_temp.pmid('Foreign')),'Cohort exact-scope RLS');
select pg_temp.pm_check(exists(select 1 from pm o,jsonb_array_elements(o.payload->'teams') t,jsonb_array_elements(t->'projects') p,jsonb_array_elements(p->'activities') a,jsonb_array_elements(a->'instances') i where o.label='Overview' and i->>'id'=pg_temp.pmid('Instance Team')::text),'existing assigned Activity flow is available in operational overview');
-- Assignment alone must not manufacture a source Team launch entitlement.
select pg_temp.pm_check(public.start_activity('00000000-0000-4000-8000-000000098004',pg_temp.pmid('Project Team'),pg_temp.pmid('Project Team','primary_workspace_id'),pg_temp.pmid('Team A','teamId'))->>'started'='false','M7 launch gate preserved for nonmember Master');
select pg_temp.pm_check(public.get_pending_review_queue(pg_temp.pmid('Cohort'))='{"items":[]}'::jsonb,'approved/revision history is not pending');
select pg_temp.pm_actor(6005);
insert into pm select 'S1',public.submit_artifact(pg_temp.pmid('Artifact Team','artifactId'),pg_temp.pmid('V3'),pg_temp.pmid('Instance Team'));
commit;
begin;
set local role service_role;
select pg_temp.pm_notify('SUBMISSION_RECEIVED',pg_temp.pmid('S1')),pg_temp.pm_notify('SUBMISSION_RECEIVED',pg_temp.pmid('S1'));
set local role authenticated;
select pg_temp.pm_actor(6002);
insert into pm select 'Q1',public.get_pending_review_queue(pg_temp.pmid('Cohort'));
select pg_temp.pm_check((select jsonb_array_length(payload->'items')=1 and payload->'items'->0->>'submissionId'=pg_temp.pmid('S1')::text and payload->'items'->0->'version'->>'id'=pg_temp.pmid('V3')::text and payload->'items'->0->'activity'->>'id'=pg_temp.pmid('Instance Team')::text from pm where label='Q1'),'exact submitted Version and Activity in pending queue');
select pg_temp.pm_check(exists(select 1 from public.artifact_versions where id=pg_temp.pmid('V3') and status='SUBMITTED'),'assigned submitted content readable');
select public.start_review(pg_temp.pmid('S1'));
insert into pm select 'Comment',public.add_feedback('ARTIFACT',pg_temp.pmid('Artifact Team','artifactId'),pg_temp.pmid('V3'),'COMMENT','M1529 exact submitted Version feedback');
select pg_temp.pm_check((select payload->>'author_user_id'='00000000-0000-4000-8000-000000006002' and payload->>'target_version_id'=pg_temp.pmid('V3')::text and payload->>'submission_id'=pg_temp.pmid('S1')::text from pm where label='Comment'),'comment identity/exact target/submission');
select pg_temp.pm_check(public.get_pending_review_queue(pg_temp.pmid('Cohort'))->'items'->0->>'reviewState'='UNDER_REVIEW','review remains pending');
select public.request_revision(pg_temp.pmid('S1'),'M1529 private revision instructions');
select pg_temp.pm_check(public.get_pending_review_queue(pg_temp.pmid('Cohort'))='{"items":[]}'::jsonb,'revision leaves queue');
commit;
begin;
set local role service_role;
select pg_temp.pm_notify('REVISION_REQUESTED',pg_temp.pmid('S1')),pg_temp.pm_notify('REVISION_REQUESTED',pg_temp.pmid('S1'));
set local role authenticated;
select pg_temp.pm_actor(6005);
insert into pm select 'V4',public.create_revision_draft(pg_temp.pmid('S1'),'{"private":"M1529_RESUBMITTED_V4"}','Pilot revision');
insert into pm select 'S2',public.submit_artifact(pg_temp.pmid('Artifact Team','artifactId'),pg_temp.pmid('V4'),pg_temp.pmid('Instance Team'));
insert into pm select 'V5',public.create_artifact_version(pg_temp.pmid('Artifact Team','artifactId'),'{"private":"M1529_UNRELATED_DRAFT_V5"}','Not submitted');
commit;
begin;
set local role service_role;
select pg_temp.pm_notify('SUBMISSION_RECEIVED',pg_temp.pmid('S2')),pg_temp.pm_notify('SUBMISSION_RECEIVED',pg_temp.pmid('S2'));
set local role authenticated;
select pg_temp.pm_actor(6002);
select pg_temp.pm_check(public.get_pending_review_queue(pg_temp.pmid('Cohort'))->'items'->0->'version'->>'id'=pg_temp.pmid('V4')::text,'resubmission shows V4, never newer V5');
select pg_temp.pm_check(not exists(select 1 from public.artifact_versions where id=pg_temp.pmid('V5')),'known newer Draft denied');
select pg_temp.pm_check(not exists(select 1 from public.workspaces where id=pg_temp.pmid('Project Individual','primary_workspace_id')) and not exists(select 1 from public.artifacts where id=pg_temp.pmid('Artifact Personal','artifactId')),'Personal Workspace and private Artifact denied');
select pg_temp.pm_check(not exists(select 1 from public.chat_messages where chat_channel_id=pg_temp.pmid('Team A','chatChannelId')),'known private Team Chat denied');
select pg_temp.pm_check(public.get_submitted_artifact_metadata(pg_temp.pmid('Artifact Team','artifactId'))->>'id'=pg_temp.pmid('Artifact Team','artifactId')::text,'exact submitted metadata accessible');
select pg_temp.pm_deny(format('select public.get_master_cohort_overview(%L)',pg_temp.pmid('Foreign')));
select pg_temp.pm_deny(format('select public.get_pending_review_queue(%L)',pg_temp.pmid('S2')));
select pg_temp.pm_actor(6003);
select pg_temp.pm_deny(format('select public.get_master_cohort_overview(%L)',pg_temp.pmid('Cohort')));
select pg_temp.pm_deny(format('select public.approve_artifact(%L,null)',pg_temp.pmid('S2')));
select pg_temp.pm_check(not exists(select 1 from public.artifact_versions where id=pg_temp.pmid('V4')),'role-only/unrelated Master exact Version denied');
reset role;
savepoint inactive_master;
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=pg_temp.pmid('Cohort');
set local role authenticated;
select pg_temp.pm_actor(6002);
select pg_temp.pm_deny(format('select public.get_pending_review_queue(%L)',pg_temp.pmid('Cohort')));
select pg_temp.pm_deny(format('select public.start_review(%L)',pg_temp.pmid('S2')));
rollback to savepoint inactive_master;
set local role authenticated;
select pg_temp.pm_actor(6002);
select public.start_review(pg_temp.pmid('S2')),public.approve_artifact(pg_temp.pmid('S2'),'Pilot exact V4 approval');
select pg_temp.pm_check(public.get_pending_review_queue(pg_temp.pmid('Cohort'))='{"items":[]}'::jsonb,'approval leaves queue');
insert into pm select 'Final overview',public.get_master_cohort_overview(pg_temp.pmid('Cohort'));
select pg_temp.pm_check(exists(select 1 from pm o,jsonb_array_elements(o.payload->'teams') t,jsonb_array_elements(t->'projects') p,jsonb_array_elements(p->'approvedOutputs') v where o.label='Final overview' and p->'project'->>'id'=pg_temp.pmid('Project Team')::text and v->>'versionId'=pg_temp.pmid('V4')::text and v->>'status'='CURRENT' and p->'pendingReview'->>'count'='0' and p->'revisionRequested'->>'pending'='false' and p->>'lastMeaningfulWorkflowUpdateAt' is not null),'canonical approved output/progress/status');
commit;
begin;
set local role service_role;
select pg_temp.pm_notify('ARTIFACT_APPROVED',pg_temp.pmid('S2')),pg_temp.pm_notify('ARTIFACT_APPROVED',pg_temp.pmid('S2'));
reset role;
select pg_temp.pm_check((select current_version_id=pg_temp.pmid('V4') from public.artifacts where id=pg_temp.pmid('Artifact Team','artifactId')) and (select status='DRAFT' from public.artifact_versions where id=pg_temp.pmid('V5')),'approval pointer is exact submitted V4; V5 unchanged');
select pg_temp.pm_check((select count(*)=2 and bool_and(recipient_user_id='00000000-0000-4000-8000-000000006002') from public.notifications where notification_type='SUBMISSION_RECEIVED' and entity_id in(pg_temp.pmid('S1'),pg_temp.pmid('S2'))),'each submission notifies exact assigned Master once');
select pg_temp.pm_check((select count(*)=2 and count(distinct recipient_user_id)=2 and bool_and(recipient_user_id in('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005')) from public.notifications where notification_type='REVISION_REQUESTED' and entity_id=pg_temp.pmid('S1')),'revision notifies current owning Team once each');
select pg_temp.pm_check((select count(*)=2 and count(distinct recipient_user_id)=2 and bool_and(recipient_user_id in('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005')) from public.notifications where notification_type='ARTIFACT_APPROVED' and entity_id=pg_temp.pmid('S2')),'approval notifies current owning Team once each');
select pg_temp.pm_check(not exists(select 1 from public.notifications where entity_id in(pg_temp.pmid('S1'),pg_temp.pmid('S2')) and (metadata<>'{}'::jsonb or body like '%M1529%' or body like '%DO_NOT_RETURN%')),'notification summaries omit private content');
-- Replacement gets current operational scope, never old immutable review rights.
set local role authenticated;
select pg_temp.pm_actor(6005);
insert into pm select 'Orphan',public.submit_artifact(pg_temp.pmid('Artifact Team','artifactId'),pg_temp.pmid('V5'),pg_temp.pmid('Instance Team'));
select pg_temp.pm_actor(6001);
select public.assign_master_to_cohort(pg_temp.pmid('Cohort'),'00000000-0000-4000-8000-000000006003');
select pg_temp.pm_actor(6002);
select pg_temp.pm_deny(format('select public.get_master_cohort_overview(%L)',pg_temp.pmid('Cohort')));
select pg_temp.pm_deny(format('select public.start_review(%L)',pg_temp.pmid('Orphan')));
select pg_temp.pm_actor(6003);
select pg_temp.pm_check(public.get_master_cohort_overview(pg_temp.pmid('Cohort'))->'cohort'->>'id'=pg_temp.pmid('Cohort')::text and public.get_pending_review_queue(pg_temp.pmid('Cohort'))='{"items":[]}'::jsonb,'replacement overview allowed but no inherited review queue');
select pg_temp.pm_check(not public.can_review_submission(pg_temp.pmid('Orphan')) and not exists(select 1 from public.artifact_versions where id=pg_temp.pmid('V5')),'replacement cannot inspect old submitted content');
select pg_temp.pm_deny(format('select public.start_review(%L)',pg_temp.pmid('Orphan')));
select pg_temp.pm_deny(format('select public.request_revision(%L,''No inherited authority'')',pg_temp.pmid('Orphan')));
select pg_temp.pm_deny(format('select public.approve_artifact(%L,null)',pg_temp.pmid('Orphan')));
select pg_temp.pm_deny(format('select public.add_feedback(''ARTIFACT'',%L,%L,''COMMENT'',''No inherited authority'')',pg_temp.pmid('Artifact Team','artifactId'),pg_temp.pmid('V5')));
reset role;
select pg_temp.pm_check((select reviewer_user_id='00000000-0000-4000-8000-000000006002' and status='SUBMITTED' from public.submissions where id=pg_temp.pmid('Orphan')),'historical reviewer/provenance unchanged');
select pg_temp.pm_check(not exists(select 1 from public.team_memberships where user_id in('00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003')),'no implicit Team membership created');
commit;
\echo M15.29 assigned-Master/activity-review/exact-Version/notifications/queue/progress/privacy/replacement PASS
