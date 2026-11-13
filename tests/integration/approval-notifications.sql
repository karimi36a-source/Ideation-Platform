reset role;
create temporary table rn(label text primary key,payload jsonb);
grant select,insert on rn to authenticated,service_role;
create function pg_temp.rid(k text) returns uuid language sql as $$select (payload->>'id')::uuid from rn where label=k$$;
create function pg_temp.rdeliver(sid uuid) returns void language plpgsql as $$declare d jsonb;begin
 for d in select value from jsonb_array_elements(public.approval_notification_contexts(sid)) loop
 perform public.create_domain_notification(jsonb_build_object('notificationType','ARTIFACT_APPROVED','recipientContext',d->'recipientContext','formatterInput','{}'::jsonb,
 'entityReference',jsonb_build_object('entityType','submission','entityId',sid),'idempotencyKey',d->>'idempotencyKey','title','Artifact approved','body','An Artifact submission has been approved.','recipientStrategy','CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM'));
 end loop;
end $$;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into rn select 'Personal',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Individual')) from submitted_fixtures where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into rn select 'Team',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team')) from submitted_fixtures where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
do $$begin begin perform public.approve_artifact(pg_temp.rid('Team'),'Foreign review');raise exception 'Unrelated Master reviewed';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.rid('Personal')),public.start_review(pg_temp.rid('Team'));
select public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'COMMENT','Private draft feedback, not a revision');
reset role;
set local role service_role;
do $$begin assert public.approval_notification_contexts(pg_temp.rid('Team'))='[]'::jsonb,'draft feedback not a revision event';end $$;
reset role;
-- A required M8 Version update failure rolls back approval status/action/audit.
create function pg_temp.rfail() returns trigger language plpgsql as $$begin raise exception 'Disposable failure' using errcode='23514';end $$;
create trigger rfail before update on public.artifact_versions for each row execute function pg_temp.rfail();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.approve_artifact(pg_temp.rid('Team'),'Private approval instructions');raise exception 'Rollback bypass';exception when check_violation then null;end;end $$;
reset role;
drop trigger rfail on public.artifact_versions;
do $$begin
 assert exists(select 1 from public.submissions where id=pg_temp.rid('Team') and status='UNDER_REVIEW');
 assert not exists(select 1 from public.audit_events where entity_id=pg_temp.rid('Team') and event_type='ARTIFACT_APPROVED');
 assert not exists(select 1 from public.notifications where notification_type='ARTIFACT_APPROVED');
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
reset role;
savepoint partial_approval;
create function pg_temp.no_approval_audit() returns trigger language plpgsql as $$begin return null;end $$;
create trigger suppress_approval_audit before insert on public.audit_events for each row when(new.event_type='ARTIFACT_APPROVED') execute function pg_temp.no_approval_audit();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.approve_artifact(pg_temp.rid('Team'),'Partial disposable state');
reset role;
set local role service_role;
do $$begin assert public.approval_notification_contexts(pg_temp.rid('Team'))='[]'::jsonb,'partial approval without canonical event must never notify';end $$;
reset role;
rollback to savepoint partial_approval;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.approve_artifact(pg_temp.rid('Personal'),'Private Personal approval instructions');
reset role;
-- Freeze an empty audience inside approval itself; later eligibility is not a replay audience.
savepoint empty_audience;
update public.project_memberships set status='inactive',ends_at=clock_timestamp() where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team');
set local role authenticated;
select public.approve_artifact(pg_temp.rid('Team'),'Private approval instructions');
reset role;
set local role service_role;
do $$begin assert public.approval_notification_contexts(pg_temp.rid('Team'))='[]'::jsonb;end $$;
reset role;
insert into public.project_memberships(project_id,user_id) select distinct project_id,user_id from public.project_memberships where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') and user_id in('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005');
set local role service_role;
do $$begin assert public.approval_notification_contexts(pg_temp.rid('Team'))='[]'::jsonb,'empty audience must stay empty on retry';end $$;
reset role;
rollback to savepoint empty_audience;
set local role authenticated;
select public.approve_artifact(pg_temp.rid('Team'),'Private approval instructions');
reset role;
-- Eligibility lost before first dispatch excludes the former participant entirely.
savepoint first_dispatch;
update public.project_memberships set status='inactive',ends_at=clock_timestamp() where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') and user_id='00000000-0000-4000-8000-000000006004';
set local role service_role;
do $$begin assert jsonb_array_length(public.approval_notification_contexts(pg_temp.rid('Team')))=1;end $$;
reset role;
rollback to savepoint first_dispatch;
set local role service_role;
select pg_temp.rdeliver(pg_temp.rid('Personal')),pg_temp.rdeliver(pg_temp.rid('Team'));
select pg_temp.rdeliver(pg_temp.rid('Personal')),pg_temp.rdeliver(pg_temp.rid('Team'));
reset role;
do $$begin
 assert (select count(*) from public.notifications where entity_id=pg_temp.rid('Personal') and recipient_user_id='00000000-0000-4000-8000-000000006004')=1;
 assert (select count(*) from public.notifications where entity_id=pg_temp.rid('Team'))=2,'current Team/Project participants only';
 assert not exists(select 1 from public.notifications where notification_type='ARTIFACT_APPROVED' and (recipient_user_id not in('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005') or title<>'Artifact approved' or body<>'An Artifact submission has been approved.' or metadata<>'{}')),'no Team B/roles/body/feedback fanout';
 assert (select count(*) from realtime.messages m join public.notifications n on m.payload->>'id'=n.id::text where n.notification_type='ARTIFACT_APPROVED' and m.private and m.topic='notifications:'||n.recipient_user_id::text and m.payload=jsonb_build_object('id',n.id,'read_at',null))=3,'private minimal refresh once';
 assert (select count(*) from public.review_actions where submission_id=pg_temp.rid('Team') and action_type='APPROVED' and note='Private approval instructions')=1,'canonical review note preserved';
 assert exists(select 1 from public.submissions s join public.artifacts a on a.id=s.artifact_id join public.artifact_versions v on v.id=s.artifact_version_id where s.id=pg_temp.rid('Team') and v.status='CURRENT' and a.current_version_id=v.id and v.approved_by=s.reviewer_user_id and v.approval_note='Private approval instructions'),'exact approved Version, not a newer Draft';
 assert (select count(*) from public.review_actions where submission_id=pg_temp.rid('Team') and action_type='APPROVED')=1;
 assert (select count(*) from private.approval_notification_batches)=2;
 begin update private.approval_notification_batches set audience='[]';raise exception 'batch mutable';exception when check_violation then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.approve_artifact(pg_temp.rid('Team'),'Private approval instructions');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin
 assert not exists(select 1 from public.notifications where notification_type='ARTIFACT_APPROVED');
 assert not exists(select 1 from public.submissions where id=pg_temp.rid('Team'));
 begin perform public.approval_notification_contexts(pg_temp.rid('Team'));raise exception 'exact ID audience bypass';exception when insufficient_privilege then null;end;
 begin perform public.create_domain_notification('{}');raise exception 'fake revision notice';exception when insufficient_privilege then null;end;
 begin perform 1 from private.approval_notification_batches;raise exception 'batch leak';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Later joiners can obtain canonical source authority, never old notifications.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006011','m1511-late@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006011','active');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006011','participant','active' from acceptance_cohorts where label='Test';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006011','member');
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006011' from logged_projects where label='Team';
set local role service_role;
select pg_temp.rdeliver(pg_temp.rid('Team'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert exists(select 1 from public.notifications where notification_type='ARTIFACT_APPROVED' and entity_id=pg_temp.rid('Team')),'own history retained after removal';
 assert not exists(select 1 from public.submissions where id=pg_temp.rid('Team')),'old notice is no authority';
end $$;
reset role;
do $$begin
 assert not exists(select 1 from public.notifications where notification_type='ARTIFACT_APPROVED' and recipient_user_id='00000000-0000-4000-8000-000000006011');
 assert (select count(*) from public.notifications where entity_id=pg_temp.rid('Team'))=2;
end $$;
-- A distinct later approved Version has a new audit event and notice.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into rn values('V2',public.create_artifact_version((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),'{"notes":"Private later version"}','Human later version'));
reset role;
do $$begin
 assert exists(select 1 from public.notifications n join public.submissions sub on sub.id=n.entity_id join public.artifacts a on a.id=sub.artifact_id where n.entity_id=pg_temp.rid('Personal') and sub.artifact_version_id=a.current_version_id and sub.artifact_version_id<>pg_temp.rid('V2')),'existing notice still targets exact approved Version, not newer Draft';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into rn select 'Personal2',public.submit_artifact((payload->>'artifactId')::uuid,pg_temp.rid('V2'),(select id from instances where label='Individual')) from submitted_fixtures where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.rid('Personal2'));
reset role;
create temporary table approval_atomic_before as select jsonb_build_object(
 'artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),
 'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),
 'submissions',(select jsonb_agg(to_jsonb(x) order by id) from public.submissions x),
 'actions',(select jsonb_agg(to_jsonb(x) order by id) from public.review_actions x),
 'audit',(select jsonb_agg(to_jsonb(x) order by id) from public.audit_events x),
 'notifications',(select jsonb_agg(to_jsonb(x) order by id) from public.notifications x),
 'batches',(select jsonb_agg(to_jsonb(x) order by event_id) from private.approval_notification_batches x)) data;
create function pg_temp.assert_approval_rollback() returns void language plpgsql as $$begin
 assert (select data from approval_atomic_before)=jsonb_build_object(
 'artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),
 'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),
 'submissions',(select jsonb_agg(to_jsonb(x) order by id) from public.submissions x),
 'actions',(select jsonb_agg(to_jsonb(x) order by id) from public.review_actions x),
 'audit',(select jsonb_agg(to_jsonb(x) order by id) from public.audit_events x),
 'notifications',(select jsonb_agg(to_jsonb(x) order by id) from public.notifications x),
 'batches',(select jsonb_agg(to_jsonb(x) order by event_id) from private.approval_notification_batches x)),
 'Canonical notification failure must roll back every approval write';
end$$;
create trigger rfail before insert on public.notifications for each row execute function pg_temp.rfail();
set local role authenticated;
do $$begin begin perform public.approve_artifact(pg_temp.rid('Personal2'),'Private later approval note');raise exception 'notification failure bypass';exception when check_violation then null;end;end $$;
reset role;
drop trigger rfail on public.notifications;
select pg_temp.assert_approval_rollback();
do $$begin
 assert exists(select 1 from public.submissions where id=pg_temp.rid('Personal2') and status='UNDER_REVIEW');
 assert not exists(select 1 from public.audit_events where entity_id=pg_temp.rid('Personal2') and event_type='ARTIFACT_APPROVED');
 assert not exists(select 1 from public.notifications where entity_id=pg_temp.rid('Personal2') and notification_type='ARTIFACT_APPROVED');
 assert not has_function_privilege('authenticated','private.create_atomic_approval_notifications()','execute');
 assert not has_function_privilege('service_role','private.create_atomic_approval_notifications()','execute');
end $$;
\echo M17.10 before-notification-insert approval/pointer/Version/audit/notification/batch rollback PASS
set local role authenticated;
select public.approve_artifact(pg_temp.rid('Personal2'),'Private later approval note');
reset role;
create trigger rfail before insert on realtime.messages for each row execute function pg_temp.rfail();
set local role service_role;
select pg_temp.rdeliver(pg_temp.rid('Personal2'));
reset role;
drop trigger rfail on realtime.messages;
set local role service_role;
select pg_temp.rdeliver(pg_temp.rid('Personal2'));
reset role;
do $$begin
 assert (select count(*) from public.notifications where notification_type='ARTIFACT_APPROVED')=4,'distinct cycle, same safe summary';
 assert not exists(select 1 from public.notifications where notification_type='REVISION_REQUESTED'),'no revision producer from approval';
 assert not has_function_privilege('anon','public.approval_notification_contexts(uuid)','execute');
 assert not has_function_privilege('authenticated','public.approval_notification_contexts(uuid)','execute');
 assert not has_table_privilege('service_role','private.approval_notification_batches','select');
end $$;
select 'M15.12 canonical Team/Personal approval/current recipients/frozen audience/exact Version/history/removal/cycles/rollback/private realtime PASS';
rollback;
