begin;
-- Only trusted internal publication uses this explicit-recipient eligibility
-- predicate. No RPC accepts a caller-supplied recipient to establish access.
create function public.team_chat_broadcast_recipient(target_channel uuid,recipient uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_channels ch
 join public.teams t on t.id=ch.team_id and t.workspace_id=ch.workspace_id and t.cohort_id=ch.cohort_id
 join public.workspaces w on w.id=t.workspace_id and w.team_id=t.id and w.cohort_id=t.cohort_id
 join public.team_memberships m on m.team_id=t.id and m.user_id=recipient
 join public.users u on u.id=m.user_id
 join public.chat_memberships cm on cm.chat_channel_id=ch.id and cm.user_id=u.id
 where ch.id=target_channel and ch.channel_type='TEAM' and ch.status='active'
 and w.workspace_type='TEAM' and w.status='active' and w.visibility='private'
 and t.status in ('created','active') and u.account_status='active'
 and m.status='active' and m.left_at is null and m.joined_at<=statement_timestamp()
 and cm.left_at is null and cm.joined_at<=statement_timestamp()
 and exists(select 1 from public.enrollments e where e.user_id=u.id and e.cohort_id=t.cohort_id and e.status='active' and e.enrollment_role='participant'));
$$;
revoke all on function public.team_chat_broadcast_recipient(uuid,uuid) from public,anon,authenticated,service_role;
-- Topic knowledge is only a resource selector, never proof of authorization.
create function public.can_receive_team_chat_broadcast(channel_topic text) returns boolean
 language plpgsql stable security definer set search_path='' as $$
declare parts text[];actor uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null or channel_topic is null or channel_topic !~ '^team-chat:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return false;end if;
 parts:=string_to_array(channel_topic,':');
 return parts[3]::uuid=actor and public.get_team_chat_access(parts[2]::uuid) is not null;
end $$;
revoke all on function public.can_receive_team_chat_broadcast(text) from public,anon,authenticated,service_role;
grant execute on function public.can_receive_team_chat_broadcast(text) to authenticated;
alter table realtime.messages enable row level security;
create policy fici_team_chat_broadcast_receive on realtime.messages for select to authenticated
 using(extension='broadcast' and topic=realtime.topic() and public.can_receive_team_chat_broadcast(realtime.topic()));
-- Restrictive Team-topic guards prevent another permissive Realtime policy
-- from accidentally broadening these private receive-only channels.
create policy fici_team_chat_broadcast_private_guard on realtime.messages as restrictive for select to anon,authenticated
 using(case when topic like 'team-chat:%' or realtime.topic() like 'team-chat:%'
 then case when auth.uid() is null then false else extension='broadcast' and topic=realtime.topic() and public.can_receive_team_chat_broadcast(realtime.topic()) end
 else true end);
create policy fici_team_chat_broadcast_no_client_publish on realtime.messages as restrictive for insert to anon,authenticated
 with check(topic not like 'team-chat:%' and coalesce(realtime.topic(),'') not like 'team-chat:%');
-- No client publisher or Presence policy. Guard direct SQL send as well.
revoke execute on function realtime.send(jsonb,text,text,boolean) from public,anon,authenticated;
create function public.broadcast_team_chat_message() returns trigger
 language plpgsql security definer set search_path='' as $$
declare recipient record; sent uuid[]:=array[]::uuid[];
begin
 -- Trigger executes only after canonical insert, in the SAME transaction.
 -- Rollback (including publisher failure) removes both message and notification.
 -- Recipient fan-out avoids cached private-channel authorization leaking future
 -- messages after removal. Removed topics receive no new events.
 for recipient in
  select u.id from public.chat_channels ch
  join public.teams t on t.id=ch.team_id and t.workspace_id=ch.workspace_id and t.cohort_id=ch.cohort_id
  join public.workspaces w on w.id=t.workspace_id and w.team_id=t.id and w.cohort_id=t.cohort_id
  join public.team_memberships m on m.team_id=t.id
  join public.users u on u.id=m.user_id
  join public.chat_memberships cm on cm.chat_channel_id=ch.id and cm.user_id=u.id
  join public.enrollments e on e.cohort_id=t.cohort_id and e.user_id=u.id
  where ch.id=new.chat_channel_id and public.team_chat_broadcast_recipient(ch.id,u.id)
   and ch.channel_type='TEAM' and ch.status='active' and t.status in ('created','active')
   and w.workspace_type='TEAM' and w.status='active' and w.visibility='private'
   and u.account_status='active' and m.status='active' and m.left_at is null and m.joined_at<=statement_timestamp()
   and cm.left_at is null and cm.joined_at<=statement_timestamp()
   and e.status='active' and e.enrollment_role='participant'
  order by u.id for share of ch,t,w,m,u,cm,e
 loop
  if not recipient.id=any(sent) then
   perform realtime.send(jsonb_build_object('chatChannelId',new.chat_channel_id,'messageId',new.id),'team.message.created','team-chat:'||new.chat_channel_id::text||':'||recipient.id::text,true);
   sent:=array_append(sent,recipient.id);
  end if;
 end loop;
 return new;
end $$;
revoke all on function public.broadcast_team_chat_message() from public,anon,authenticated,service_role;
create trigger chat_messages_broadcast_after_insert after insert on public.chat_messages for each row execute function public.broadcast_team_chat_message();
commit;
