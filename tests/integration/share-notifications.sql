reset role;
create temporary table sn_context(label text primary key,payload jsonb);
grant select,insert on sn_context to authenticated,service_role;
create function pg_temp.sn_id(k text) returns uuid language sql as $$select (payload->>'id')::uuid from sn_context where label=k$$;
create function pg_temp.sn_deliver(sid uuid) returns void language plpgsql as $$
declare c jsonb;begin
 for c in select value from jsonb_array_elements(public.artifact_share_notification_contexts(sid)) loop
  perform public.create_domain_notification(jsonb_build_object('notificationType','ARTIFACT_SHARED','recipientContext',c,
   'formatterInput','{}'::jsonb,'entityReference',jsonb_build_object('entityType','share','entityId',sid),
   'title','Artifact shared','body','An Artifact Snapshot has been shared with you.','recipientStrategy','CURRENT_SHARE_DESTINATION'));
 end loop;
end $$;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
insert into sn_context select 'MasterAssignment',jsonb_build_object('id',ra.id) from public.role_assignments ra join public.roles r on r.id=ra.role_id join acceptance_cohorts c on c.id=ra.cohort_id
 where c.label='Test' and ra.user_id='00000000-0000-4000-8000-000000006002' and r.code='MASTER' and ra.status='active' limit 1;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into sn_context select 'V2',public.create_artifact_version((payload->>'artifactId')::uuid,'{"notes":"exact frozen V2"}','V2') from submitted_fixtures where label='Team';
insert into sn_context select 'TeamShare',public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',pg_temp.sn_id('V2'),
 'destinationType','TEAM','destinationId',(select payload->>'teamId' from acceptance_teams where label='B'),'permissionLevel','VIEW','shareMode','SNAPSHOT')) from submitted_fixtures where label='Team';
-- A direct RPC creates no premature success notification in its own transaction.
reset role;
do $$begin
 assert (select count(*) from private.artifact_share_notification_audience x join public.audit_events a on a.id=x.event_id where a.entity_id=pg_temp.sn_id('TeamShare'))=2,'exact creation-time B audience';
 assert not exists(select 1 from public.notifications where entity_type='share' and entity_id=pg_temp.sn_id('TeamShare')),'post-commit delivery only';
end $$;
set local role service_role;
select pg_temp.sn_deliver(pg_temp.sn_id('TeamShare'));
select pg_temp.sn_deliver(pg_temp.sn_id('TeamShare'));
reset role;
do $$begin
 assert (select count(*) from public.notifications where entity_type='share' and entity_id=pg_temp.sn_id('TeamShare'))=2,'one per recipient, retry dedup';
 assert not exists(select 1 from public.notifications where entity_type='share' and entity_id=pg_temp.sn_id('TeamShare') and recipient_user_id not in('00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006007')),'no source/role/Team C fanout';
 assert not exists(select 1 from public.notifications where entity_id=pg_temp.sn_id('TeamShare') and (title<>'Artifact shared' or body<>'An Artifact Snapshot has been shared with you.' or metadata<>'{}')),'safe registry summary only';
 assert (select count(*) from realtime.messages r join public.notifications n on r.payload->>'id'=n.id::text where n.entity_id=pg_temp.sn_id('TeamShare') and r.event='notification.changed' and r.private and r.topic='notifications:'||n.recipient_user_id::text and r.payload=jsonb_build_object('id',n.id,'read_at',null))=2,'private minimal refresh, no duplicate retry broadcast';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
-- Canonical exact Share retry, later source version, and another enabled destination.
select public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',pg_temp.sn_id('V2'),'destinationType','TEAM',
 'destinationId',(select payload->>'teamId' from acceptance_teams where label='B'),'permissionLevel','VIEW','shareMode','SNAPSHOT')) from submitted_fixtures where label='Team';
insert into sn_context select 'V3',public.create_artifact_version((payload->>'artifactId')::uuid,'{"notes":"private newer V3"}','V3') from submitted_fixtures where label='Team';
insert into sn_context select 'MasterShare',public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',pg_temp.sn_id('V2'),
 'destinationType','MASTER','destinationId',pg_temp.sn_id('MasterAssignment'),'permissionLevel','COMMENT','shareMode','SNAPSHOT')) from submitted_fixtures where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into sn_context select 'ObjectShare',public.share_entity(jsonb_build_object('entityType','DEVELOPMENT_OBJECT','entityId',payload->>'id','destinationType','TEAM',
 'destinationId',(select payload->>'teamId' from acceptance_teams where label='A'),'permissionLevel','VIEW','shareMode','SNAPSHOT')) from logged_objects where label='Problem';
reset role;
set local role service_role;
select pg_temp.sn_deliver(pg_temp.sn_id('TeamShare')),pg_temp.sn_deliver(pg_temp.sn_id('MasterShare')),pg_temp.sn_deliver(pg_temp.sn_id('ObjectShare'));
reset role;
do $$begin
 assert (select count(*) from public.notifications where entity_id=pg_temp.sn_id('MasterShare') and recipient_user_id='00000000-0000-4000-8000-000000006002')=1,'exact scoped Master';
 assert not exists(select 1 from public.notifications where entity_id=pg_temp.sn_id('ObjectShare')),'non-Artifact Share emits no Artifact notification';
 assert exists(select 1 from public.shares where id=pg_temp.sn_id('ObjectShare') and revoked_at is null),'non-Artifact Share unchanged';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$declare r jsonb;begin
 r:=public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.sn_id('TeamShare')));
 assert r->>'allowed'='true' and (r->>'sourceVersionId')::uuid=pg_temp.sn_id('V2') and r->'snapshotContent'->'content_snapshot'='{"notes":"exact frozen V2"}'::jsonb,'notification resolves exact frozen V2, never V3';
 assert r->>'canEdit'='false' and r->>'canReshare'='false';
 assert not exists(select 1 from public.artifacts where id in(select (payload->>'artifactId')::uuid from submitted_fixtures where label in('Team','Sibling'))),'source and sibling not exposed';
 assert not exists(select 1 from public.artifact_versions where id in(pg_temp.sn_id('V2'),pg_temp.sn_id('V3'))),'no source Version enumeration';
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from acceptance_teams where label='A')) is null,'source Workspace private';
 assert not public.can_access_team_chat((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A')),'source Chat private';
 begin perform public.artifact_share_notification_contexts(pg_temp.sn_id('TeamShare'));raise exception 'selector bypass';exception when insufficient_privilege then null;end;
 begin perform public.create_domain_notification(jsonb_build_object('notificationType','ARTIFACT_SHARED'));raise exception 'fake notification';exception when insufficient_privilege then null;end;
 begin perform 1 from private.artifact_share_notification_audience;raise exception 'audience leak';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.notifications where recipient_user_id<>auth.uid()),'exact notice ID cannot enumerate other recipients';
end $$;
reset role;
-- Late destination join: M13 dynamically permits Share access, but no historical notification fanout.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006010','m159-late@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006010','active');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006010','participant','active' from acceptance_cohorts where label='Test';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006010','member');
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin
 assert public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.sn_id('TeamShare')))->>'allowed'='false';
 assert exists(select 1 from public.notifications where entity_id=pg_temp.sn_id('TeamShare')),'removed recipient keeps own history, not access';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006010',true);
do $$begin
 assert public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.sn_id('TeamShare')))->>'allowed'='true','existing M13 dynamic destination access unchanged';
 assert not exists(select 1 from public.notifications where entity_id=pg_temp.sn_id('TeamShare')),'late member has no old notification';
end $$;
reset role;
insert into sn_context select 'LateAttack',jsonb_build_object('event',a.id,'mid',m.id) from public.audit_events a
 join public.team_memberships m on m.team_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='B') and m.user_id='00000000-0000-4000-8000-000000006010' and m.status='active'
 where a.entity_id=pg_temp.sn_id('TeamShare') and a.event_type='SHARE_CREATED';
set local role service_role;
do $$declare req jsonb;begin
 req:=jsonb_build_object('notificationType','ARTIFACT_SHARED','recipientContext',jsonb_build_object('sourceId',(select payload->>'event' from sn_context where label='LateAttack'),'teamMembershipId',(select payload->>'mid' from sn_context where label='LateAttack')),
 'formatterInput','{}'::jsonb,'entityReference',jsonb_build_object('entityType','share','entityId',pg_temp.sn_id('TeamShare')),'title','Artifact shared','body','An Artifact Snapshot has been shared with you.','recipientStrategy','CURRENT_SHARE_DESTINATION','idempotencyKey','forged-late-recipient');
 begin perform public.create_domain_notification(req);raise exception 'late recipient bypassed creation audience';exception when insufficient_privilege then null;end;
 begin perform public.create_domain_notification(jsonb_set(req,'{recipientContext,sourceId}',to_jsonb(pg_temp.sn_id('TeamShare'))));raise exception 'Share ID treated as event capability';exception when insufficient_privilege then null;end;
 begin perform public.create_domain_notification(req||'{"recipientUserId":"00000000-0000-4000-8000-000000006010"}');raise exception 'spoofed recipient accepted';exception when invalid_parameter_value then null;end;
end $$;
select pg_temp.sn_deliver(pg_temp.sn_id('TeamShare'));
reset role;
do $$begin assert (select count(*) from public.notifications where entity_id=pg_temp.sn_id('TeamShare'))=2,'no historical fanout after join/removal';end $$;
-- Current MASTER expiry denies delivery/access without removing historical notice.
update public.role_assignments set ends_at=clock_timestamp() where id=pg_temp.sn_id('MasterAssignment');
set local role service_role;
select pg_temp.sn_deliver(pg_temp.sn_id('MasterShare'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.sn_id('MasterShare')))->>'allowed'='false';assert exists(select 1 from public.notifications where entity_id=pg_temp.sn_id('MasterShare'));end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.revoke_share(jsonb_build_object('shareId',pg_temp.sn_id('TeamShare')));
select public.revoke_share(jsonb_build_object('shareId',pg_temp.sn_id('TeamShare')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$begin
 assert exists(select 1 from public.notifications where entity_id=pg_temp.sn_id('TeamShare')),'revocation retains history';
 assert public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.sn_id('TeamShare')))->>'allowed'='false','notice/Share ID cannot preserve revoked access';
end $$;
reset role;
set local role service_role;
select pg_temp.sn_deliver(pg_temp.sn_id('TeamShare'));
reset role;
do $$begin
 assert (select count(*) from public.audit_events where entity_id=pg_temp.sn_id('TeamShare') and event_type='SHARE_REVOKED')=1;
 assert (select count(*) from public.notifications where entity_id=pg_temp.sn_id('TeamShare'))=2;
 assert not exists(select 1 from public.notifications where notification_type='SHARE_REVOKED'),'revocation notifications deferred';
 assert not has_function_privilege('anon','public.artifact_share_notification_contexts(uuid)','execute') and not has_function_privilege('authenticated','public.artifact_share_notification_contexts(uuid)','execute');
 assert not has_table_privilege('service_role','private.artifact_share_notification_audience','select'),'no privileged bulk audience read';
end $$;
-- A failed Snapshot step rolls back the Share, audit and audience together.
create function pg_temp.sn_fail() returns trigger language plpgsql as $$begin raise exception 'Disposable failure' using errcode='23514';end $$;
create trigger sn_fail before insert on public.share_snapshots for each row execute function pg_temp.sn_fail();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 begin perform public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',(select payload->>'artifactId' from submitted_fixtures where label='Team'),
 'sourceVersionId',pg_temp.sn_id('V3'),'destinationType','TEAM','destinationId',(select payload->>'teamId' from acceptance_teams where label='B'),'permissionLevel','COMMENT','shareMode','SNAPSHOT'));raise exception 'failed Snapshot accepted';exception when check_violation then null;end;
end $$;
reset role;
drop trigger sn_fail on public.share_snapshots;
do $$begin
 assert (select count(*) from public.shares where shared_entity_id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'))=2,'failed Share left no row';
 assert (select count(*) from private.artifact_share_notification_audience x join public.audit_events a on a.id=x.event_id where a.entity_id=pg_temp.sn_id('TeamShare'))=2,'audit audience retained';
end $$;
-- A new Share after revocation is a distinct event; post-commit notification
-- failure leaves it intact and retry repairs delivery. Realtime is best effort.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into sn_context select 'NewShare',public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',pg_temp.sn_id('V3'),
 'destinationType','TEAM','destinationId',(select payload->>'teamId' from acceptance_teams where label='B'),'permissionLevel','VIEW','shareMode','SNAPSHOT')) from submitted_fixtures where label='Team';
reset role;
create trigger sn_fail before insert on public.notifications for each row execute function pg_temp.sn_fail();
set local role service_role;
do $$begin begin perform pg_temp.sn_deliver(pg_temp.sn_id('NewShare'));raise exception 'notification failure bypassed';exception when check_violation then null;end;end $$;
reset role;
drop trigger sn_fail on public.notifications;
do $$begin
 assert exists(select 1 from public.shares where id=pg_temp.sn_id('NewShare') and revoked_at is null),'delivery failure does not undo committed Share';
 assert not exists(select 1 from public.notifications where entity_id=pg_temp.sn_id('NewShare')),'failed delivery not fabricated';
end $$;
create trigger sn_fail before insert on realtime.messages for each row execute function pg_temp.sn_fail();
set local role service_role;
select pg_temp.sn_deliver(pg_temp.sn_id('NewShare'));
reset role;
drop trigger sn_fail on realtime.messages;
set local role service_role;
select pg_temp.sn_deliver(pg_temp.sn_id('NewShare'));
reset role;
do $$begin
 assert pg_temp.sn_id('NewShare')<>pg_temp.sn_id('TeamShare');
 assert (select count(*) from public.notifications where entity_id=pg_temp.sn_id('NewShare'))=2,'new event and repaired delivery distinct';
 assert exists(select 1 from public.notifications where entity_id=pg_temp.sn_id('NewShare') and recipient_user_id='00000000-0000-4000-8000-000000006010'),'late joiner receives new event only';
 assert not exists(select 1 from public.notifications where entity_id=pg_temp.sn_id('NewShare') and recipient_user_id='00000000-0000-4000-8000-000000006006'),'removed member excluded from new event';
 assert (select source_version_id from public.share_snapshots where share_id=pg_temp.sn_id('TeamShare'))=pg_temp.sn_id('V2'),'old frozen Snapshot never overwritten';
 assert (select source_version_id from public.share_snapshots where share_id=pg_temp.sn_id('NewShare'))=pg_temp.sn_id('V3');
end $$;
select 'M15.9 Artifact Share committed recipients/frozen target/retry/history/revocation/removal/private realtime/non-Artifact isolation PASS';
rollback;
