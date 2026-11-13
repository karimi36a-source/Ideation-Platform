begin;
-- Extend the existing M5 store; preserve IDs, recipients and retained history.
alter table public.notifications
 add column title text not null default 'Notification',
 add column body text not null default 'An update is available.',
 add column read_at timestamptz;
alter table public.notifications
 drop constraint notifications_notification_type_check,
 drop constraint notifications_entity_type_check,
 drop constraint notifications_entity_id_fkey,
 alter column entity_type drop not null,
 alter column entity_id drop not null,
 add constraint notifications_type_format check(notification_type ~ '^[A-Z][A-Z0-9_]{0,63}$'),
 add constraint notifications_title_length check(char_length(btrim(title)) between 1 and 160),
 add constraint notifications_body_length check(char_length(btrim(body)) between 1 and 500),
 add constraint notifications_entity_pair check((entity_type is null) = (entity_id is null)),
 add constraint notifications_entity_type_format check(entity_type ~ '^[A-Za-z][A-Za-z0-9_]{0,63}$');
-- Existing recipient/time index already supports chronological queries.
create index notifications_recipient_unread on public.notifications(recipient_user_id,created_at,id) where read_at is null;
-- No client mark-read operation yet. A future narrow server operation may update
-- only read_at; informational content, recipient and attribution stay immutable.
drop trigger notifications_immutable on public.notifications;
create function public.guard_notification_history() returns trigger language plpgsql set search_path='' as $$
begin
 if TG_OP='DELETE' then raise exception 'Notification history is retained' using errcode='23514';end if;
 if TG_OP='INSERT' then
  NEW.created_at:=clock_timestamp();
  NEW.read_at:=null;
  return NEW;
 end if;
 if (to_jsonb(NEW)-'read_at') is distinct from (to_jsonb(OLD)-'read_at') then
  raise exception 'Notification history is immutable' using errcode='23514';
 end if;
 return NEW;
end $$;
revoke all on function public.guard_notification_history() from public,anon,authenticated,service_role;
create trigger notifications_history_guard before insert or update or delete on public.notifications for each row execute function public.guard_notification_history();
-- Keep all M5 recipient-only SELECT policies and deny all ordinary mutations.
comment on table public.notifications is 'Recipient-private informational history, never entity authorization. Server producers must use concise safe summaries, never raw source content, credentials or internal errors. Legacy identifier-only metadata retained. No delivery/UI/type registry implemented.';
comment on column public.notifications.entity_id is 'Optional navigation reference only; resolve current target authorization independently. Not a capability or workflow state.';
commit;
