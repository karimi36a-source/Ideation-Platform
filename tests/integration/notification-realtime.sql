reset role;
create temporary table realtime_notice(id uuid);
insert into public.notifications(recipient_user_id,notification_type,title,body,metadata)
 values('00000000-0000-4000-8000-000000006004','MEMBER_ADDED','M1526_PRIVATE_ENTITY_NAME','M1526_PRIVATE_BODY','{"internal":"must-not-broadcast","email":"fixture@example.test","claims":{"role":"ADMIN"}}') returning id \gset notice_
insert into realtime_notice values(:'notice_id');
grant select on realtime_notice to authenticated,anon;
do $$ declare row0 record;begin
 select * into row0 from realtime.messages where event='notification.changed' and payload->>'id'=(select id::text from realtime_notice);
 assert row0.topic='notifications:00000000-0000-4000-8000-000000006004' and row0.private,'private exact recipient';
 assert row0.payload=jsonb_build_object('id',(select id from realtime_notice),'read_at',null),'minimal transport projection';
 assert not exists(select 1 from realtime.messages where event='notification.changed' and topic like 'team-%'),'no Team broadcast';
 assert not has_function_privilege('authenticated','public.broadcast_notification_change()','EXECUTE'),'no client publisher';
 assert not has_function_privilege('anon','public.can_receive_notification_broadcast(text)','EXECUTE');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.broadcast_notification_change()'::regprocedure);
 assert not exists(select 1 from pg_publication_tables where schemaname='public' and tablename='notifications'),'canonical notifications are not publicly published';
end $$;
-- An unrelated permissive policy must not widen this namespace.
create policy fixture_notification_broad on realtime.messages for select to authenticated using(true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select set_config('realtime.topic','notifications:00000000-0000-4000-8000-000000006004',true);
do $$ declare first_read timestamptz;events_before bigint;begin
 assert public.can_receive_notification_broadcast(current_setting('realtime.topic'));
 assert exists(select 1 from realtime.messages where payload->>'id'=(select id::text from realtime_notice));
 perform public.mark_notification_read((select id from realtime_notice));
 select read_at into first_read from public.notifications where id=(select id from realtime_notice);
 select count(*) into events_before from realtime.messages where payload->>'id'=(select id::text from realtime_notice);
 perform public.mark_notification_read((select id from realtime_notice));
 assert (select read_at=first_read from public.notifications where id=(select id from realtime_notice)),'retry preserves first read';
 assert (select count(*) from realtime.messages where payload->>'id'=(select id::text from realtime_notice))=events_before,'read retry emits no duplicate transport event';
 assert exists(select 1 from realtime.messages r join public.notifications n on r.payload->>'id'=n.id::text where n.id=(select id from realtime_notice) and r.payload->>'read_at' is not null and (r.payload->>'read_at')::timestamptz=n.read_at),'read refresh matches canonical state';
 begin perform realtime.send('{}','notification.changed',current_setting('realtime.topic'),true);raise exception 'Client publish allowed';exception when insufficient_privilege then null;end;
end $$;
-- Exact same topic, ID and same-Team peer do not confer recipient access.
do $$ declare who text;begin
 foreach who in array array['6001','6002','6003','6005','6006','6007','6008'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  assert not public.can_receive_notification_broadcast('notifications:00000000-0000-4000-8000-000000006004');
  assert not exists(select 1 from realtime.messages),'cross-user/role-only receive denied';
  assert not exists(select 1 from public.notifications where id=(select id from realtime_notice)),'known event ID cannot read canonical foreign notification';
  begin perform public.mark_notification_read((select id from realtime_notice));raise exception 'Foreign read mutation allowed';exception when insufficient_privilege then null;end;
  begin perform realtime.send('{}','notification.changed','notifications:'||who,true);raise exception 'Client publisher allowed';exception when insufficient_privilege then null;end;
  begin insert into realtime.messages(topic,event,payload,private,extension) values('notifications:00000000-0000-4000-8000-000000006004','notification.changed','{}',false,'broadcast');raise exception 'Forged public event allowed';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
drop policy fixture_notification_broad on realtime.messages;
set local role anon;
do $$ begin
 begin perform 1 from realtime.messages;raise exception 'anonymous read allowed';exception when insufficient_privilege then null;end;
 begin perform 1 from public.notifications where id=(select id from realtime_notice);raise exception 'anonymous exact ID allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Subtransaction rollback removes both the canonical row and transport record.
do $$ declare n uuid;before_count bigint;begin
 select count(*) into before_count from realtime.messages;
 begin
  insert into public.notifications(recipient_user_id,notification_type,title,body) values('00000000-0000-4000-8000-000000006004','MEMBER_ADDED','Rollback','Safe') returning id into n;
  assert exists(select 1 from realtime.messages where payload->>'id'=n::text);
  raise exception 'Forced rollback';
 exception when raise_exception then if sqlerrm<>'Forced rollback' then raise;end if;end;
 assert not exists(select 1 from public.notifications where id=n);
 assert (select count(*) from realtime.messages)=before_count,'rollback emits no committed event';
end $$;
-- Inactive profile cannot join and receives no future signals on cached topic.
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000006004';
do $$ declare n uuid;begin
 insert into public.notifications(recipient_user_id,notification_type,title,body) values('00000000-0000-4000-8000-000000006004','MEMBER_ADDED','Inactive','Safe') returning id into n;
 assert not exists(select 1 from realtime.messages where payload->>'id'=n::text);
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 assert not public.can_receive_notification_broadcast('notifications:00000000-0000-4000-8000-000000006004');
end $$;
set constraints all immediate;
rollback;
\echo M15.7 recipient Broadcast projection/commit/rollback/isolation/read-state PASS
\echo M15.26 recipient isolation/payload/direct-ID/forgery/read-retry database security PASS
