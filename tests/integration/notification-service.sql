reset role;
create temporary table notification_service_before as select count(*) n from public.notifications where idempotency_digest is not null;
create temporary table notify_context(label text primary key,id uuid);
grant select,insert on notify_context to authenticated,service_role;
create function pg_temp.notify_request(code text,source uuid,kind text,target uuid,mid uuid default null,key0 text default 'm153-retry') returns jsonb language sql as $$
 select jsonb_build_object('notificationType',code,'recipientContext',jsonb_strip_nulls(jsonb_build_object('sourceId',source,'teamMembershipId',mid)),
 'formatterInput','{}'::jsonb,'entityReference',jsonb_build_object('entityType',kind,'entityId',target),
 'title',case when code like 'MEMBER_%' then 'Team membership updated' when code='ARTIFACT_SHARED' then 'Artifact shared' else 'Notification' end,'body',case code when 'MEMBER_ADDED' then 'You have been added to a Team.' when 'MEMBER_REMOVED' then 'Your Team membership has ended.' when 'MEMBER_MOVED' then 'Your Team assignment has changed.' when 'ARTIFACT_SHARED' then 'An Artifact Snapshot has been shared with you.' else 'A safe summary.' end, 'idempotencyKey',key0,'recipientStrategy',case when code like 'MEMBER_%' then 'AFFECTED_MEMBERSHIP_USER' when code='ARTIFACT_SHARED' then 'CURRENT_SHARE_DESTINATION' when code='SUBMISSION_RECEIVED' then 'CURRENT_ASSIGNED_SUBMISSION_REVIEWER' else 'CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM' end)
$$;
create function pg_temp.notify_bad(input0 jsonb,expected text default '42501') returns void language plpgsql as $$ begin
 perform public.create_domain_notification(input0);raise exception 'Notification attack succeeded';
exception when others then if sqlstate<>expected then raise;end if;end $$;
-- Real canonical submission and Share operations; no notification event hooks.
insert into notify_context select 'MasterAssignment',ra.id from public.role_assignments ra join public.roles r on r.id=ra.role_id join acceptance_cohorts c on c.id=ra.cohort_id where c.label='Test' and ra.user_id='00000000-0000-4000-8000-000000006002' and r.code='MASTER' and ra.status='active' limit 1;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into notify_context select 'PersonalSubmission',(public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Individual'))->>'id')::uuid from submitted_fixtures where label='Personal';
insert into notify_context select 'Share',(public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',payload->>'initialVersionId','destinationType','TEAM','destinationId',(select payload->>'teamId' from acceptance_teams where label='A'),'permissionLevel','VIEW','shareMode','SNAPSHOT'))->>'id')::uuid from submitted_fixtures where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into notify_context select 'MasterShare',(public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',payload->>'initialVersionId','destinationType','MASTER','destinationId',(select id from notify_context where label='MasterAssignment'),'permissionLevel','VIEW','shareMode','SNAPSHOT'))->>'id')::uuid from submitted_fixtures where label='Team';
insert into notify_context select 'TeamSubmission',(public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team'))->>'id')::uuid from submitted_fixtures where label='Team';
reset role;
-- Store canonical event IDs as trusted domain references, never recipient IDs.
insert into notify_context select 'MasterShareEvent',id from public.audit_events where event_type='SHARE_CREATED' and entity_id=(select id from notify_context where label='MasterShare');
insert into notify_context select 'ShareEvent',id from public.audit_events where event_type='SHARE_CREATED' and entity_id=(select id from notify_context where label='Share');
insert into notify_context select 'MembershipEvent',id from public.audit_events where event_type='MEMBER_ADDED' and metadata->>'userId'='00000000-0000-4000-8000-000000006004' limit 1;
insert into notify_context select 'TargetTeam',(payload->>'teamId')::uuid from acceptance_teams where label='A';
insert into notify_context select 'Member',m.id from public.team_memberships m join acceptance_teams t on (t.payload->>'teamId')::uuid=m.team_id where t.label='A' and m.user_id='00000000-0000-4000-8000-000000006004' and m.status='active';
insert into notify_context select 'OtherMember',m.id from public.team_memberships m join acceptance_teams t on (t.payload->>'teamId')::uuid=m.team_id where t.label='B' and m.user_id='00000000-0000-4000-8000-000000006006' and m.status='active';
set local role service_role;
do $$ declare req jsonb;n jsonb;n2 jsonb;begin
 req:=pg_temp.notify_request('SUBMISSION_RECEIVED',(select id from notify_context where label='PersonalSubmission'),'submission',(select id from notify_context where label='PersonalSubmission'));
 n:=public.create_domain_notification(req);n2:=public.create_domain_notification(req);
 assert n=n2 and n->>'recipient_user_id'='00000000-0000-4000-8000-000000006002' and n->'read_at'='null'::jsonb,'canonical reviewer and exact retry';
 perform pg_temp.notify_bad(req||'{"body":"Changed safe summary"}','23505');
 perform pg_temp.notify_bad(req||'{"recipientUserId":"spoof"}','22023');
 perform pg_temp.notify_bad(req||'{"notificationType":"UNKNOWN"}','22023');
 perform pg_temp.notify_bad(req||'{"entityReference":{"entityType":"share","entityId":"00000000-0000-4000-8000-000000006004"}}');
 n2:=public.create_domain_notification(pg_temp.notify_request('SUBMISSION_RECEIVED',(select id from notify_context where label='TeamSubmission'),'submission',(select id from notify_context where label='TeamSubmission'),null,'m153-distinct-event'));assert n->>'id'<>n2->>'id';
 n:=public.create_domain_notification(pg_temp.notify_request('MEMBER_ADDED',(select id from notify_context where label='MembershipEvent'),'team',(select id from notify_context where label='TargetTeam'),null,'m153-membership'));
 assert n->>'recipient_user_id'='00000000-0000-4000-8000-000000006004','affected user from immutable audit';
 n:=public.create_domain_notification(pg_temp.notify_request('ARTIFACT_SHARED',(select id from notify_context where label='MasterShareEvent'),'share',(select id from notify_context where label='MasterShare'),null,'m153-master-share'));
 assert n->>'recipient_user_id'='00000000-0000-4000-8000-000000006002','exact scoped Master assignment';
 req:=pg_temp.notify_request('ARTIFACT_SHARED',(select id from notify_context where label='ShareEvent'),'share',(select id from notify_context where label='Share'),(select id from notify_context where label='Member'),'m153-share');
 n:=public.create_domain_notification(req||'{"idempotencyKey":"m153-retry"}');
 n:=public.create_domain_notification(req);assert n->>'recipient_user_id'='00000000-0000-4000-8000-000000006004';
 perform pg_temp.notify_bad(jsonb_set(req,'{recipientContext,teamMembershipId}',to_jsonb((select id from notify_context where label='OtherMember'))));
end $$;
reset role;
-- Normal clients cannot invoke the privileged operation, even with exact IDs.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.notify_bad(pg_temp.notify_request('SUBMISSION_RECEIVED',(select id from notify_context where label='TeamSubmission'),'submission',(select id from notify_context where label='TeamSubmission')));
do $$begin
 begin insert into public.notifications(recipient_user_id,notification_type) values(auth.uid(),'ARTIFACT_APPROVED');raise exception 'fake approval allowed';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.notifications where recipient_user_id<>auth.uid()),'other recipients hidden';
 assert not exists(select 1 from public.notifications where entity_type='submission' and entity_id in(select id from notify_context where label in ('TeamSubmission','PersonalSubmission'))),'known private notification target IDs hidden';
 assert not exists(select 1 from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team')),'notification linkage grants no source access';
end $$;
-- Real revision/approval flows prove event-backed outcome resolution.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(id) from notify_context where label in ('PersonalSubmission','TeamSubmission');
select public.request_revision(id,'Human requested revision') from notify_context where label='PersonalSubmission';
select public.approve_artifact(id,'Human approval') from notify_context where label='TeamSubmission';
reset role;
insert into notify_context select 'RevisionEvent',id from public.audit_events where event_type='REVISION_REQUESTED' and entity_id=(select id from notify_context where label='PersonalSubmission');
insert into notify_context select 'ApprovalEvent',id from public.audit_events where event_type='ARTIFACT_APPROVED' and entity_id=(select id from notify_context where label='TeamSubmission');
-- Explicit participation for a selected authorized Team outcome recipient.
insert into public.project_memberships(project_id,user_id,project_role,status)
 select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006004','participant','active' from logged_projects where label='Team'
 on conflict do nothing;
set local role service_role;
do $$declare n jsonb;begin
 n:=public.create_domain_notification(pg_temp.notify_request('REVISION_REQUESTED',(select id from notify_context where label='RevisionEvent'),'submission',(select id from notify_context where label='PersonalSubmission'),null,'m153-revision'));
 assert n->>'recipient_user_id'='00000000-0000-4000-8000-000000006004','Personal outcome owner';
 n:=public.create_domain_notification(pg_temp.notify_request('ARTIFACT_APPROVED',(select id from notify_context where label='ApprovalEvent'),'submission',(select id from notify_context where label='TeamSubmission'),(select id from notify_context where label='Member'),'m153-approval'));
 assert n->>'recipient_user_id'='00000000-0000-4000-8000-000000006004','exact current source Team participant';
 perform pg_temp.notify_bad(pg_temp.notify_request('ARTIFACT_APPROVED',(select id from notify_context where label='RevisionEvent'),'submission',(select id from notify_context where label='PersonalSubmission'),null,'m153-forged-approval'));
end $$;
reset role;
-- Revocation/removal are rechecked even on a known idempotency key.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.revoke_share(jsonb_build_object('shareId',id)) from notify_context where label='Share';
reset role;
set local role service_role;
select pg_temp.notify_bad(pg_temp.notify_request('ARTIFACT_SHARED',(select id from notify_context where label='ShareEvent'),'share',(select id from notify_context where label='Share'),(select id from notify_context where label='Member'),'m153-share'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select id from notify_context where label='TargetTeam'),'00000000-0000-4000-8000-000000006004','Disposable recipient removal');
reset role;
insert into notify_context select 'RemovalEvent',id from public.audit_events where event_type='MEMBER_REMOVED' and entity_id=(select id from notify_context where label='TargetTeam') and metadata->>'userId'='00000000-0000-4000-8000-000000006004' order by created_at desc limit 1;
set local role service_role;
select pg_temp.notify_bad(pg_temp.notify_request('ARTIFACT_APPROVED',(select id from notify_context where label='ApprovalEvent'),'submission',(select id from notify_context where label='TeamSubmission'),(select id from notify_context where label='Member'),'m153-approval'));
select public.create_domain_notification(pg_temp.notify_request('MEMBER_REMOVED',(select id from notify_context where label='RemovalEvent'),'team',(select id from notify_context where label='TargetTeam'),null,'m153-removal'));
reset role;
update public.role_assignments set ends_at=clock_timestamp() where id=(select id from notify_context where label='MasterAssignment');
set local role service_role;
select pg_temp.notify_bad(pg_temp.notify_request('ARTIFACT_SHARED',(select id from notify_context where label='MasterShareEvent'),'share',(select id from notify_context where label='MasterShare'),null,'m153-master-share'));
reset role;
do $$begin
 assert (select count(*) from public.notifications where idempotency_digest is not null)=(select n+7 from notification_service_before),'six explicit notifications plus one canonical removal; membership retry reuses initial row, no partial rows after denial/conflict';
 assert not exists(select 1 from public.notifications where idempotency_digest is not null and (read_at is not null or created_at is null));
 assert not has_function_privilege('authenticated','public.create_domain_notification(jsonb)','execute');
 assert not has_function_privilege('anon','public.create_domain_notification(jsonb)','execute');
 assert not has_table_privilege('service_role','public.notifications','insert'),'only narrow definer, no broad privileged writes';
end $$;
rollback;
select 'M15.3 canonical notification creation/recipient proof/retry/forgery/privacy PASS';
