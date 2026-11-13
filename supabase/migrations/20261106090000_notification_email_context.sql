begin;
-- Internal read-only delivery projection. No new tables, client grants, source
-- access, transaction changes, delivery state, queue or recovery infrastructure.
create function public.notification_email_contexts(input jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare nid uuid;mid uuid;kind text;result jsonb;
begin
 if input is null or jsonb_typeof(input)<>'object' then raise exception 'Email context unavailable' using errcode='22023';end if;
 if input?'notificationId' then
  if (select count(*) from jsonb_object_keys(input))<>1 or jsonb_typeof(input->'notificationId')<>'string' then raise exception 'Email context unavailable' using errcode='22023';end if;
  nid:=(input->>'notificationId')::uuid;
 elsif input?'membershipId' then
  if (select count(*) from jsonb_object_keys(input))<>2 or not input?'membershipType'
   or jsonb_typeof(input->'membershipId')<>'string' or jsonb_typeof(input->'membershipType')<>'string'
   or input->>'membershipType' not in ('MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED') then raise exception 'Email context unavailable' using errcode='22023';end if;
  mid:=(input->>'membershipId')::uuid;kind:=input->>'membershipType';
 else raise exception 'Email context unavailable' using errcode='22023';end if;
 if nid is null and mid is null then raise exception 'Email context unavailable' using errcode='22023';end if;
 select coalesce(jsonb_agg(jsonb_build_object('notificationId',n.id,'notificationType',n.notification_type,
  'recipientUserId',u.id,'recipientEmail',u.email,'accountStatus',u.account_status) order by n.id),'[]'::jsonb) into result
 from public.notifications n join public.users u on u.id=n.recipient_user_id
 where u.account_status='active' and u.email is not null and (
  (nid is not null and n.id=nid) or (mid is not null and n.notification_type=kind and exists(
   select 1 from public.audit_events ev where ev.event_type=kind and ev.entity_type='team' and ev.entity_id=n.entity_id
    and ev.metadata->>'userId'=n.recipient_user_id::text
    and ((kind in ('MEMBER_ADDED','MEMBER_REMOVED') and ev.metadata->>'membershipId'=mid::text)
      or (kind='MEMBER_MOVED' and ev.metadata->>'targetMembershipId'=mid::text))
    and n.idempotency_digest=encode(sha256(convert_to('m5-membership:'||ev.id::text,'UTF8')),'hex')
  )));
 return result;
end $$;
revoke all on function public.notification_email_contexts(jsonb) from public,anon,authenticated;
grant execute on function public.notification_email_contexts(jsonb) to service_role;
comment on function public.notification_email_contexts(jsonb) is 'M15.16 internal committed-notification/account projection only; no source authorization, writes, dispatch or queue.';
commit;
