reset role;
create temporary table cn(label text primary key,payload jsonb);grant select,insert on cn to authenticated,service_role;
insert into cn select 'Master',jsonb_build_object('id',ra.id) from public.role_assignments ra join public.roles r on r.id=ra.role_id where r.code='MASTER' and ra.user_id='00000000-0000-4000-8000-000000006002' and ra.cohort_id=(select id from acceptance_cohorts where label='Test') and ra.status='active';
create function pg_temp.cid(k text) returns uuid language sql as $$select (payload->>'id')::uuid from cn where label=k$$;
create function pg_temp.deliver_comment(source uuid) returns void language plpgsql as $$declare d jsonb;begin
 for d in select value from jsonb_array_elements(public.comment_notification_contexts(source)) loop
 perform public.create_domain_notification(jsonb_build_object('notificationType','COMMENT_RECEIVED','recipientContext',d->'recipientContext','formatterInput','{}'::jsonb,'entityReference',d->'entityReference','idempotencyKey',d->>'idempotencyKey','title','New comment received','body','New feedback was added.','recipientStrategy','CURRENT_AUTHORIZED_TARGET_OWNERS_EXCLUDING_AUTHOR'));
 end loop;
end $$;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006002','participant','active' from acceptance_cohorts where label='Test' on conflict do nothing;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006002','member');
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,u from logged_projects cross join unnest(array['00000000-0000-4000-8000-000000006005'::uuid,'00000000-0000-4000-8000-000000006002'::uuid]) u where label='Team' on conflict do nothing;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into cn select 'Share',public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',payload->>'initialVersionId','destinationType','MASTER','destinationId',pg_temp.cid('Master'),'permissionLevel','COMMENT','shareMode','SNAPSHOT')) from submitted_fixtures where label='Team';
-- Canonical Share ID is retained without projecting source content.
reset role;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into cn select 'Team',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team')) from submitted_fixtures where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into cn select 'Personal',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Individual')) from submitted_fixtures where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.cid('Team')),public.start_review(pg_temp.cid('Personal'));
insert into cn select 'Feedback',public.add_feedback('ARTIFACT',(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,'COMMENT','CONFIDENTIAL feedback text') from submitted_fixtures where label='Team';
insert into cn select 'PersonalFeedback',public.add_feedback('ARTIFACT',(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,'QUESTION','CONFIDENTIAL Personal question') from submitted_fixtures where label='Personal';
insert into cn values('Comment',public.add_share_comment(jsonb_build_object('shareId',pg_temp.cid('Share'),'content','CONFIDENTIAL Share comment')));
insert into cn values('Comment2',public.add_share_comment(jsonb_build_object('shareId',pg_temp.cid('Share'),'content','CONFIDENTIAL Share comment')));
reset role;
set local role service_role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true),set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000006006","test":"preserve"}',true);
select pg_temp.deliver_comment(pg_temp.cid('Feedback')),pg_temp.deliver_comment(pg_temp.cid('PersonalFeedback')),pg_temp.deliver_comment(pg_temp.cid('Comment')),pg_temp.deliver_comment(pg_temp.cid('Comment2'));
select pg_temp.deliver_comment(pg_temp.cid('Feedback')),pg_temp.deliver_comment(pg_temp.cid('Comment'));
do $$begin assert current_setting('request.jwt.claim.sub')='00000000-0000-4000-8000-000000006006';assert current_setting('request.jwt.claims')='{"sub":"00000000-0000-4000-8000-000000006006","test":"preserve"}';end $$;
reset role;
do $$begin
 assert (select count(*) from public.notifications where notification_type='COMMENT_RECEIVED')=7,'two Team feedback, one Personal, four distinct comments';
 assert not exists(select 1 from public.notifications where notification_type='COMMENT_RECEIVED' and (recipient_user_id not in('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005') or body<>'New feedback was added.' or title<>'New comment received' or metadata<>'{}')),'author/role-only/Team B excluded, generic metadata only';
 assert exists(select 1 from public.share_comments c join public.share_snapshots snap on snap.share_id=c.share_id where c.id=pg_temp.cid('Comment') and c.target_version_id=snap.source_version_id and c.content='CONFIDENTIAL Share comment');
 assert exists(select 1 from public.feedback_items where id=pg_temp.cid('Feedback') and content='CONFIDENTIAL feedback text' and submission_id=pg_temp.cid('Team'));
 assert (select count(*) from realtime.messages m join public.notifications n on m.payload->>'id'=n.id::text where n.notification_type='COMMENT_RECEIVED' and m.private and m.topic='notifications:'||n.recipient_user_id::text and m.payload=jsonb_build_object('id',n.id,'read_at',null))=7;
 assert not exists(select 1 from public.notifications where notification_type='COMMENT_RECEIVED' and entity_type='submission' and entity_id not in(pg_temp.cid('Team'),pg_temp.cid('Personal')));
 assert not exists(select 1 from public.notifications where notification_type='COMMENT_RECEIVED' and entity_type='share' and entity_id<>pg_temp.cid('Share'));
end $$;
-- Reuse the exact thread ACL, fail closed, and restore identity on ACL failure.
savepoint acl_failure;
create or replace function public.can_read_share_comments(target_share uuid) returns boolean language plpgsql stable security definer set search_path='' as $$begin raise exception 'Disposable ACL failure';end $$;
set local role service_role;
do $$declare prior_sub text:=current_setting('request.jwt.claim.sub',true);prior_claims text:=current_setting('request.jwt.claims',true);begin
 assert public.comment_notification_contexts(pg_temp.cid('Comment'))='[]'::jsonb;
 assert current_setting('request.jwt.claim.sub',true) is not distinct from prior_sub;
 assert current_setting('request.jwt.claims',true) is not distinct from prior_claims;
end $$;
reset role;rollback to savepoint acl_failure;
-- Actual source failures produce no record or notification; realtime failure cannot undo a valid notification.
create function pg_temp.cn_fail() returns trigger language plpgsql as $$begin raise exception 'Disposable failure' using errcode='23514';end $$;
create trigger cn_fail after insert on public.share_comments for each row execute function pg_temp.cn_fail();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.add_share_comment(jsonb_build_object('shareId',pg_temp.cid('Share'),'content','ROLLBACK'));raise exception 'failure bypass';exception when check_violation then null;end;end $$;
reset role;drop trigger cn_fail on public.share_comments;
create trigger cn_fail after insert on public.feedback_items for each row execute function pg_temp.cn_fail();
set local role authenticated;
do $$begin begin perform public.add_feedback('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'COMMENT','ROLLBACK');raise exception 'failure bypass';exception when check_violation then null;end;end $$;
reset role;drop trigger cn_fail on public.feedback_items;
do $$begin assert not exists(select 1 from public.share_comments where content='ROLLBACK');assert not exists(select 1 from public.feedback_items where content='ROLLBACK');assert (select count(*) from public.notifications where notification_type='COMMENT_RECEIVED')=7;end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin
 assert not exists(select 1 from public.notifications where notification_type='COMMENT_RECEIVED');
 assert not exists(select 1 from public.share_comments where share_id=pg_temp.cid('Share'));
 begin perform public.comment_notification_contexts(pg_temp.cid('Comment'));raise exception 'Client selector bypass';exception when insufficient_privilege then null;end;
 begin perform public.create_domain_notification('{}');raise exception 'Client notification bypass';exception when insufficient_privilege then null;end;
 begin perform private.notification_thread_readable('00000000-0000-4000-8000-000000006004',pg_temp.cid('Share'));raise exception 'Client identity bypass';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.revoke_share(jsonb_build_object('shareId',pg_temp.cid('Share')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.add_share_comment(jsonb_build_object('shareId',pg_temp.cid('Share'),'content','REVOKED'));raise exception 'Revoked comment bypass';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert exists(select 1 from public.notifications where notification_type='COMMENT_RECEIVED');assert not exists(select 1 from public.submissions where id=pg_temp.cid('Team'));assert not public.can_read_share_comments(pg_temp.cid('Share'));end $$;
reset role;set local role service_role;
select pg_temp.deliver_comment(pg_temp.cid('Feedback')),pg_temp.deliver_comment(pg_temp.cid('Comment'));
reset role;
do $$begin assert (select count(*) from public.notifications where notification_type='COMMENT_RECEIVED')=7;assert not has_function_privilege('anon','public.comment_notification_contexts(uuid)','execute');assert not has_table_privilege('service_role','private.comment_notification_batches','select');end $$;
select 'M15.13 M8/M13 source owners/author exclusion/exact target/content/history/removal/revoke/rollback/private realtime PASS';
rollback;
