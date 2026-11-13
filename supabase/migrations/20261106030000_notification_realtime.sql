begin;
-- Private database Broadcast avoids publishing internal notification columns.
-- realtime.send inserts transactionally; provider WAL delivery follows commit.
-- Existing Supabase Broadcast infrastructure is reused, no public table publication.
create function public.can_receive_notification_broadcast(channel_topic text) returns boolean
 language sql stable security definer set search_path='' as $$
 select public.current_platform_user_id() is not null
 and channel_topic='notifications:'||public.current_platform_user_id()::text;
$$;
revoke all on function public.can_receive_notification_broadcast(text) from public,anon,authenticated,service_role;
grant execute on function public.can_receive_notification_broadcast(text) to authenticated;
create policy fici_notification_receive on realtime.messages for select to authenticated
 using(extension='broadcast' and topic=realtime.topic() and public.can_receive_notification_broadcast(realtime.topic()));
create policy fici_notification_private_guard on realtime.messages as restrictive for select to anon,authenticated
 using(case when topic like 'notifications:%' or realtime.topic() like 'notifications:%'
 then case when auth.uid() is null then false else extension='broadcast' and topic=realtime.topic() and public.can_receive_notification_broadcast(realtime.topic()) end
 else true end);
create policy fici_notification_no_client_publish on realtime.messages as restrictive for insert to anon,authenticated
 with check(topic not like 'notifications:%' and coalesce(realtime.topic(),'') not like 'notifications:%');
create function public.broadcast_notification_change() returns trigger
 language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and new.read_at is not distinct from old.read_at then return new;end if;
 -- No Team/role fan-out, and no events for inactive profiles (cached channels).
 if exists(select 1 from public.users where id=new.recipient_user_id and account_status='active') then
  perform realtime.send(jsonb_build_object('id',new.id,'read_at',new.read_at),
   'notification.changed','notifications:'||new.recipient_user_id::text,true);
 end if;
 return new;
end $$;
revoke all on function public.broadcast_notification_change() from public,anon,authenticated,service_role;
create trigger notifications_broadcast_after_change after insert or update of read_at on public.notifications
 for each row execute function public.broadcast_notification_change();
comment on function public.broadcast_notification_change() is 'M15.7 transactional private recipient refresh only. Payload id/read_at, never internal metadata. Canonical reads remain M15.4; no replay or producer service wiring.';
commit;
