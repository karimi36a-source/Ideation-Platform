begin;
-- No UPDATE grant or RLS expansion. This is the sole ordinary-client mutation
-- path, with actor/ownership fixed by verified auth and active profile state.
create function public.mark_notification_read(target_notification uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();n public.notifications;
begin
 if actor is null or actor is distinct from auth.uid() then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';
 end if;
 if target_notification is null then raise exception 'Invalid request' using errcode='22023';end if;
 -- Serialize account deactivation with the mutation; never use role authority.
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into n from public.notifications where id=target_notification and recipient_user_id=actor for update;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 if n.read_at is null then
  update public.notifications set read_at=clock_timestamp() where id=n.id and recipient_user_id=actor and read_at is null returning * into n;
 end if;
 -- Return only canonical read state. Never return source/internal metadata.
 return jsonb_build_object('id',n.id,'read_at',n.read_at);
end $$;
revoke all on function public.mark_notification_read(uuid) from public,anon,authenticated,service_role;
grant execute on function public.mark_notification_read(uuid) to authenticated;
comment on function public.mark_notification_read(uuid) is 'M15.5 current authenticated recipient only; locked idempotent first-read timestamp. No unread reset, arbitrary updates, linked entity resolution, delivery, or other side effects.';
commit;
