begin;
-- Canonical approval notices are part of the approval/audit transaction.
-- Reuse the existing frozen audience, formatter, authorization and retry keys.
-- No provider/email work may execute from this database trigger.
create function private.create_atomic_approval_notifications() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient jsonb;
begin
 for recipient in select value from jsonb_array_elements(public.approval_notification_contexts(new.entity_id)) loop
  perform public.create_domain_notification(jsonb_build_object(
   'notificationType','ARTIFACT_APPROVED','recipientContext',recipient->'recipientContext',
   'formatterInput','{}'::jsonb,'entityReference',jsonb_build_object('entityType','submission','entityId',new.entity_id),
   'idempotencyKey',recipient->>'idempotencyKey','title','Artifact approved',
   'body','An Artifact submission has been approved.',
   'recipientStrategy','CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM'));
 end loop;
 return new;
end $$;
revoke all on function private.create_atomic_approval_notifications() from public,anon,authenticated,service_role;
create trigger atomic_approval_notifications after insert on public.audit_events
 for each row when(new.event_type='ARTIFACT_APPROVED' and new.entity_type='submission')
 execute function private.create_atomic_approval_notifications();
comment on function private.create_atomic_approval_notifications() is 'Canonical approval notifications and private realtime refresh commit or roll back with approval, exact CURRENT pointer and audit. No swallowed persistence failures or email/provider calls. Existing post-commit hook handles idempotent email scheduling.';
commit;
