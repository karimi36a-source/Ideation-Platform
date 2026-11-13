reset role;
create temporary table mh_text as select $texts${"MEMBER_ADDED":{"title":"Team membership updated","body":"You have been added to a Team."},"MEMBER_REMOVED":{"title":"Team membership updated","body":"Your Team membership has ended."},"MEMBER_MOVED":{"title":"Team membership updated","body":"Your Team assignment has changed."}}$texts$::jsonb data;
create temporary table mh_results(label text,payload jsonb);
create temporary table mh_events(label text,id uuid);
grant select,insert on mh_results,mh_events to authenticated,service_role;
grant select on mh_text to authenticated,service_role;
create function pg_temp.mh_request(e uuid) returns jsonb language sql as $$
 select jsonb_build_object('notificationType',a.event_type,'recipientContext',jsonb_build_object('sourceId',a.id),'formatterInput','{}'::jsonb,
  'entityReference',jsonb_build_object('entityType','team','entityId',a.entity_id),
  'title',(select data from mh_text)->a.event_type->>'title','body',(select data from mh_text)->a.event_type->>'body','recipientStrategy','AFFECTED_MEMBERSHIP_USER') from public.audit_events a where id=e
$$;
-- Trusted test request materialization; service_role intentionally cannot read audits.
create temporary table mh_requests(label text,req jsonb);
grant select on mh_requests to service_role;
insert into public.notifications(recipient_user_id,notification_type,title,body) values('00000000-0000-4000-8000-000000006004','MEMBER_ADDED','Notification','An update is available.');
create temporary table mh_history as select id,to_jsonb(n) data from public.notifications n;
create temporary table mh_before as select (select count(*) from public.notifications) n,(select count(*) from public.audit_events) a;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into mh_results values('destination',public.create_team((select id from acceptance_cohorts where label='Test'),'M15 destination'));
insert into mh_results values('remove',public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004'));
reset role;
insert into mh_events select 'remove',id from public.audit_events where event_type='MEMBER_REMOVED' and metadata->>'membershipId'=(select payload->>'membershipId' from mh_results where label='remove');
insert into mh_requests select 'remove',pg_temp.mh_request(id) from mh_events where label='remove';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from acceptance_teams where label='A')) is null,'removed Team access denied';
 assert exists(select 1 from public.notifications where notification_type='MEMBER_REMOVED' and body='Your Team membership has ended.'),'removed recipient can list own history';
 assert not exists(select 1 from public.notifications where recipient_user_id<>auth.uid()),'recipient isolation';
end $$;
select public.mark_notification_read((select id from public.notifications where notification_type='MEMBER_REMOVED' order by created_at desc limit 1));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into mh_results values('add',public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','member'));
reset role;
insert into mh_events select 'add',id from public.audit_events where event_type='MEMBER_ADDED' and metadata->>'membershipId'=(select payload->>'membershipId' from mh_results where label='add');
insert into mh_requests select 'add',pg_temp.mh_request(id) from mh_events where label='add';
create temporary table mh_retry_before as select count(*) n from public.notifications;
set local role service_role;
do $$declare one jsonb;two jsonb;begin
 one:=public.create_domain_notification((select req from mh_requests where label='add')||'{"idempotencyKey":"retry:first"}');
 two:=public.create_domain_notification((select req from mh_requests where label='add')||'{"idempotencyKey":"retry:second"}');
 assert one->>'id'=two->>'id','event identity independent of caller key';
 begin perform public.create_domain_notification((select req from mh_requests where label='add')||'{"recipientUserId":"00000000-0000-4000-8000-000000006006"}');raise exception 'recipient spoof allowed';exception when invalid_parameter_value then null;end;
end $$;
reset role;
do $$begin assert (select count(*) from public.notifications)=(select n from mh_retry_before),'canonical service retry does not duplicate M5 notification';end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 begin perform public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','member');raise exception 'duplicate add accepted';exception when unique_violation then null;end;
end $$;
insert into mh_results values('move',public.move_team_member('00000000-0000-4000-8000-000000006004',(select (payload->>'teamId')::uuid from acceptance_teams where label='A'),(select (payload->>'teamId')::uuid from mh_results where label='destination'),'PRIVATE REASON NOT FOR NOTIFICATION'));
reset role;
insert into mh_events select 'move',id from public.audit_events where event_type='MEMBER_MOVED' and metadata->>'targetMembershipId'=(select payload->>'targetMembershipId' from mh_results where label='move');
insert into mh_requests select 'move',pg_temp.mh_request(id) from mh_events where label='move';
set local role service_role;
select public.create_domain_notification((select req from mh_requests where label='move'));
select public.create_domain_notification((select req from mh_requests where label='move')||'{"idempotencyKey":"move:retry"}');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from acceptance_teams where label='A')) is null,'old Team denied';
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from mh_results where label='destination')) is not null,'destination canonical membership grants access';
 assert exists(select 1 from public.notifications where notification_type='MEMBER_MOVED' and entity_id=(select (payload->>'teamId')::uuid from mh_results where label='destination')),'move references destination';
end $$;
reset role;
create temporary table mh_failure_before as select (select count(*) from public.notifications) n,(select count(*) from public.audit_events) a;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 begin perform public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');raise exception 'duplicate removal allowed';exception when invalid_parameter_value then null;end;
 begin perform public.move_team_member('00000000-0000-4000-8000-000000006004',(select (payload->>'teamId')::uuid from acceptance_teams where label='A'),(select (payload->>'teamId')::uuid from mh_results where label='destination'));raise exception 'move retry repeated state';exception when invalid_parameter_value then null;end;
 begin perform public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000009999','member');raise exception 'invalid add';exception when invalid_parameter_value then null;end;
 begin perform public.persist_m5_team_event('MEMBER_ADDED',(select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'{}','00000000-0000-4000-8000-000000006006');raise exception 'internal producer accessible';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin
 assert (select count(*) from public.notifications)=(select n from mh_failure_before),'failed commands no success notice';
 assert (select count(*) from public.audit_events)=(select a from mh_failure_before),'failed commands no audit';
 assert (select count(*) from public.notifications where id not in(select id from mh_history))=3,'exactly add/remove/move affected-user rows';
 assert not exists(select 1 from public.notifications where id not in(select id from mh_history) and recipient_user_id<>'00000000-0000-4000-8000-000000006004'),'no peer/role-only fanout';
 assert not exists(select 1 from mh_history h left join public.notifications n using(id) where to_jsonb(n) is distinct from h.data),'legacy history unchanged';
 assert not exists(select 1 from public.notifications n join mh_text t on true where n.id not in(select id from mh_history) and (n.title<>t.data->n.notification_type->>'title' or n.body<>t.data->n.notification_type->>'body')),'registry-only safe text';
 assert not exists(select 1 from realtime.messages r join public.notifications n on r.payload->>'id'=n.id::text where n.id not in(select id from mh_history) and (r.topic<>'notifications:'||n.recipient_user_id::text or not r.private or r.payload-array['id','read_at']<>'{}'::jsonb or not(r.payload ?& array['id','read_at']))),'recipient-only transport';
end $$;
-- Provider transport failure cannot roll back committed membership/notification state.
create function public.mh_transport_fail() returns trigger language plpgsql as $$begin if new.event='notification.changed' then raise exception 'Injected transport failure';end if;return new;end $$;
create trigger mh_transport_fail before insert on realtime.messages for each row execute function public.mh_transport_fail();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into mh_results values('transport-failure',public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','member'));
reset role;
drop trigger mh_transport_fail on realtime.messages;
do $$begin
 assert exists(select 1 from public.team_memberships where id=(select (payload->>'membershipId')::uuid from mh_results where label='transport-failure') and status='active');
 assert (select count(*) from public.notifications)=(select n+1 from mh_failure_before),'canonical notification retained despite transport failure';
end $$;
-- Canonical notification persistence failure still rolls back the entire M5 transaction.
create function public.mh_persistence_fail() returns trigger language plpgsql as $$begin raise exception 'Injected persistence failure' using errcode='23514';end $$;
create trigger mh_persistence_fail before insert on public.notifications for each row execute function public.mh_persistence_fail();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');raise exception 'Persistence failure not injected';exception when check_violation then null;end;end $$;
reset role;
drop trigger mh_persistence_fail on public.notifications;
do $$begin assert exists(select 1 from public.team_memberships where id=(select (payload->>'membershipId')::uuid from mh_results where label='transport-failure') and status='active'),'failed notification leaves no partial membership removal';end $$;
-- Preserve M5 removal of an inactive member without granting inactive access.
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000006004';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into mh_results values('inactive-remove',public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004'));
reset role;
do $$begin
 assert exists(select 1 from public.notifications where notification_type='MEMBER_REMOVED' and idempotency_digest=encode(sha256(convert_to('m5-membership:'||(select id::text from public.audit_events where event_type='MEMBER_REMOVED' and metadata->>'membershipId'=(select payload->>'membershipId' from mh_results where label='inactive-remove')),'UTF8')),'hex')),'inactive removal retains history';
 assert not has_function_privilege('authenticated','private.membership_notification_text(text)','EXECUTE');
 assert not has_function_privilege('service_role','public.persist_m5_team_event(text,uuid,jsonb,uuid)','EXECUTE');
end $$;
set constraints all immediate;
rollback;
\echo M15.8 canonical membership registry/idempotency/affected-recipient/removal/move/realtime/failure isolation PASS
