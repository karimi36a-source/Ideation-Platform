reset role;
create temporary table ns_context(label text primary key,payload jsonb);
grant select,insert on ns_context to authenticated,service_role;
create function pg_temp.ns_id(k text) returns uuid language sql as $$select (payload->>'id')::uuid from ns_context where label=k$$;
create function pg_temp.ns_request(sid uuid) returns jsonb language sql as $$select jsonb_build_object('notificationType','SUBMISSION_RECEIVED','recipientContext',jsonb_build_object('sourceId',sid),
 'formatterInput','{}'::jsonb,'entityReference',jsonb_build_object('entityType','submission','entityId',sid),'idempotencyKey','submission-received:'||sid::text,
 'title','Submission received','body','A submission is available for your assigned review.','recipientStrategy','CURRENT_ASSIGNED_SUBMISSION_REVIEWER')$$;
create function pg_temp.ns_denied(req jsonb,expected text default '42501') returns void language plpgsql as $$begin
 perform public.create_domain_notification(req);raise exception 'Notification attack succeeded';
 exception when others then if sqlstate<>expected then raise;end if;end $$;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
insert into ns_context select 'Assignment',jsonb_build_object('id',ra.id,'endsAt',ra.ends_at) from public.role_assignments ra join public.roles r on r.id=ra.role_id join acceptance_cohorts c on c.id=ra.cohort_id where c.label='Test' and ra.user_id='00000000-0000-4000-8000-000000006002' and r.code='MASTER' and ra.status='active' limit 1;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin
 begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),(select id from instances where label='Team'));raise exception 'Team B submitted Team A';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ns_context select 'Personal',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Individual')) from submitted_fixtures where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into ns_context select 'Team',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team')) from submitted_fixtures where label='Team';
reset role;
do $$begin
 assert not exists(select 1 from public.notifications where entity_type='submission' and entity_id in(pg_temp.ns_id('Personal'),pg_temp.ns_id('Team'))),'no pre-delivery notification';
 assert exists(select 1 from public.submissions where id=pg_temp.ns_id('Team') and reviewer_user_id='00000000-0000-4000-8000-000000006002' and artifact_version_id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team')),'exact M8 reviewer/Version';
end $$;
set local role service_role;
insert into ns_context values('PersonalNotice',public.create_domain_notification(pg_temp.ns_request(pg_temp.ns_id('Personal')))),('TeamNotice',public.create_domain_notification(pg_temp.ns_request(pg_temp.ns_id('Team'))));
do $$declare n jsonb;begin
 n:=public.create_domain_notification(pg_temp.ns_request(pg_temp.ns_id('Team')));
 assert n->>'id'=(select payload->>'id' from ns_context where label='TeamNotice'),'stable notification retry';
 perform pg_temp.ns_denied(pg_temp.ns_request(pg_temp.ns_id('Team'))||'{"recipientUserId":"00000000-0000-4000-8000-000000006003"}','22023');
 perform pg_temp.ns_denied(jsonb_set(pg_temp.ns_request(pg_temp.ns_id('Team')),'{recipientContext,teamMembershipId}','"00000000-0000-4000-8000-000000006006"'));
 perform pg_temp.ns_denied(pg_temp.ns_request('00000000-0000-4000-8000-000000009999'));
end $$;
reset role;
do $$begin
 assert (select count(*) from public.notifications where entity_id in(pg_temp.ns_id('Personal'),pg_temp.ns_id('Team')))=2,'different real Submissions, same summary, distinct notices';
 assert not exists(select 1 from public.notifications where entity_id in(pg_temp.ns_id('Personal'),pg_temp.ns_id('Team')) and (recipient_user_id<>'00000000-0000-4000-8000-000000006002' or title<>'Submission received' or body<>'A submission is available for your assigned review.' or metadata<>'{}')),'no unrelated roles, source body or Team metadata';
 assert (select count(*) from realtime.messages m join public.notifications n on m.payload->>'id'=n.id::text where n.entity_id in(pg_temp.ns_id('Personal'),pg_temp.ns_id('Team')) and m.event='notification.changed' and m.private and m.topic='notifications:'||n.recipient_user_id::text and m.payload=jsonb_build_object('id',n.id,'read_at',null))=2,'only assigned Master private refresh, no retry duplicate';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),(select id from instances where label='Team'));raise exception 'M8 duplicate accepted';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
do $$begin
 assert not public.can_review_submission(pg_temp.ns_id('Team')),'unrelated Cohort Master cannot open';
 assert not exists(select 1 from public.notifications where entity_id=pg_temp.ns_id('Team')),'unrelated Master receives nothing';
 perform pg_temp.ns_denied(pg_temp.ns_request(pg_temp.ns_id('Team')));
end $$;
-- Canonical revision produces a distinct Submission event, not a rewritten cycle.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.ns_id('Personal'));
select public.request_revision(pg_temp.ns_id('Personal'),'Human revision request');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ns_context values('RevisionVersion',public.create_revision_draft(pg_temp.ns_id('Personal'),'{"notes":"private revised body"}','Human revision'));
insert into ns_context select 'Revision',public.submit_artifact((payload->>'artifactId')::uuid,pg_temp.ns_id('RevisionVersion'),(select id from instances where label='Individual')) from submitted_fixtures where label='Personal';
-- Separate Draft for forced rollback/operational-delivery failure tests.
insert into ns_context select 'RollbackArtifact',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Private Draft',null,true,true) from logged_projects where label='Individual';
reset role;
create function pg_temp.ns_fail() returns trigger language plpgsql as $$begin raise exception 'Disposable failure' using errcode='23514';end $$;
create trigger ns_fail before insert on public.submissions for each row execute function pg_temp.ns_fail();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from ns_context where label='RollbackArtifact'),(select (payload->>'initialVersionId')::uuid from ns_context where label='RollbackArtifact'),(select id from instances where label='Individual'));raise exception 'Rollback injection bypassed';exception when check_violation then null;end;
end $$;
reset role;
drop trigger ns_fail on public.submissions;
do $$begin
 assert not exists(select 1 from public.submissions where artifact_id=(select (payload->>'artifactId')::uuid from ns_context where label='RollbackArtifact')),'no rolled-back Submission';
 assert exists(select 1 from public.artifact_versions where id=(select (payload->>'initialVersionId')::uuid from ns_context where label='RollbackArtifact') and status='DRAFT'),'Version transition rolled back';
 assert (select count(*) from public.notifications where notification_type='SUBMISSION_RECEIVED')=2,'draft/failure/duplicate creates no notice';
end $$;
-- Failure after commit leaves the canonical Submission and exact Version intact.
create trigger ns_fail before insert on public.notifications for each row execute function pg_temp.ns_fail();
set local role service_role;
select pg_temp.ns_denied(pg_temp.ns_request(pg_temp.ns_id('Revision')),'23514');
reset role;
drop trigger ns_fail on public.notifications;
do $$begin assert exists(select 1 from public.submissions where id=pg_temp.ns_id('Revision') and status='SUBMITTED');end $$;
create trigger ns_fail before insert on realtime.messages for each row execute function pg_temp.ns_fail();
set local role service_role;
select public.create_domain_notification(pg_temp.ns_request(pg_temp.ns_id('Revision')));
reset role;
drop trigger ns_fail on realtime.messages;
set local role service_role;
select public.create_domain_notification(pg_temp.ns_request(pg_temp.ns_id('Revision')));
reset role;
do $$begin
 assert pg_temp.ns_id('Revision')<>pg_temp.ns_id('Personal');
 assert (select count(*) from public.notifications where notification_type='SUBMISSION_RECEIVED')=3,'one per real cycle; realtime failure cannot undo canonical delivery';
 assert not exists(select 1 from public.notifications where notification_type in('REVISION_REQUESTED','ARTIFACT_APPROVED')),'later notification producers not implemented';
end $$;
-- Assignment loss blocks new delivery AND target access, never rewrites history.
update public.role_assignments set ends_at=clock_timestamp() where id=pg_temp.ns_id('Assignment');
set local role service_role;
select pg_temp.ns_denied(pg_temp.ns_request(pg_temp.ns_id('Team')));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert exists(select 1 from public.notifications where entity_id=pg_temp.ns_id('Team')),'own notice retained';
 assert not public.can_review_submission(pg_temp.ns_id('Team')),'expired Master cannot open review';
 assert not exists(select 1 from public.submissions where id=pg_temp.ns_id('Team')),'notification grants no Submission read';
end $$;
reset role;
update public.role_assignments set ends_at=null,status='inactive' where id=pg_temp.ns_id('Assignment');
set local role service_role;
select pg_temp.ns_denied(pg_temp.ns_request(pg_temp.ns_id('Revision')));
reset role;
-- Canonical M8 itself fails closed when no current reviewer is available.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.submit_artifact((select (payload->>'artifactId')::uuid from ns_context where label='RollbackArtifact'),(select (payload->>'initialVersionId')::uuid from ns_context where label='RollbackArtifact'),(select id from instances where label='Individual'));raise exception 'Missing reviewer fallback';exception when insufficient_privilege then null;end;
end $$;
reset role;
update public.role_assignments set status='active' where id=pg_temp.ns_id('Assignment');
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000006002';
set local role service_role;
select pg_temp.ns_denied(pg_temp.ns_request(pg_temp.ns_id('Revision')));
reset role;
update public.users set account_status='active' where id='00000000-0000-4000-8000-000000006002';
update public.cohorts set primary_master_id='00000000-0000-4000-8000-000000006003' where id=(select id from acceptance_cohorts where label='Test');
set local role service_role;
select pg_temp.ns_denied(pg_temp.ns_request(pg_temp.ns_id('Team')));
reset role;
do $$begin
 assert (select count(*) from public.notifications where notification_type='SUBMISSION_RECEIVED')=3;
 assert not exists(select 1 from public.notifications where notification_type='SUBMISSION_RECEIVED' and recipient_user_id<>'00000000-0000-4000-8000-000000006002'),'no fallback audience';
end $$;
select 'M15.10 exact Personal/Team Submission/reviewer/cycle/retry/rollback/history/current assignment/private realtime PASS';
rollback;
