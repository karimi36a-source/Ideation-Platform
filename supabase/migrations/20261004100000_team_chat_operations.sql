begin;
-- Narrow definer provides canonical writes without granting client INSERT.
-- Locks serialize sends with membership removal/moves and lifecycle changes.
create function public.send_team_chat_message(target_team uuid,message_content text,reply_parent uuid default null)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; t public.teams; ch public.chat_channels; c public.cohorts; saved public.chat_messages;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 select * into ch from public.chat_channels where team_id=target_team and channel_type='TEAM' and status='active';
 if not found or public.get_team_chat_access(ch.id) is distinct from 'read_write' then raise exception 'Access denied' using errcode='42501';end if;
 select c0.* into c from public.cohorts c0 join public.teams t0 on t0.cohort_id=c0.id where t0.id=target_team for share of c0;
 select * into t from public.teams where id=target_team for share;
 if not found or t.cohort_id<>c.id then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.enrollments where cohort_id=t.cohort_id and user_id=actor and status='active' and enrollment_role='participant' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.team_memberships where team_id=t.id and user_id=actor and status='active' and left_at is null and joined_at<=statement_timestamp() for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.workspaces where id=t.workspace_id and team_id=t.id and cohort_id=t.cohort_id and workspace_type='TEAM' and status='active' and visibility='private' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 select * into ch from public.chat_channels where id=ch.id and team_id=t.id and workspace_id=t.workspace_id and cohort_id=t.cohort_id and status='active' and channel_type='TEAM' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.chat_memberships where chat_channel_id=ch.id and user_id=actor and left_at is null and joined_at<=statement_timestamp() for share;
 if not found or public.get_team_chat_access(ch.id) is distinct from 'read_write' then raise exception 'Access denied' using errcode='42501';end if;
 if message_content is null or length(btrim(message_content,U&'\0020\0009\000A\000B\000C\000D\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'))=0 then raise exception 'Invalid message' using errcode='22023';end if;
 if reply_parent is not null and not exists(select 1 from public.chat_messages where id=reply_parent and chat_channel_id=ch.id) then raise exception 'Invalid parent' using errcode='22023';end if;
 insert into public.chat_messages(chat_channel_id,sender_user_id,parent_message_id,content,message_type,created_at)
 values(ch.id,actor,reply_parent,message_content,'TEXT',clock_timestamp()) returning * into saved;
 return to_jsonb(saved);
end $$;
-- Invoker read keeps RLS authoritative. Channel identifiers never grant access.
create function public.list_team_chat_messages(target_channel uuid,page_limit integer default 50,after_time timestamptz default null,after_id uuid default null)
 returns jsonb language plpgsql security invoker set search_path='' as $$
declare items jsonb; cursor_value jsonb; last_message public.chat_messages;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 if public.get_team_chat_access(target_channel) is null then raise exception 'Access denied' using errcode='42501';end if;
 if page_limit is null or page_limit<1 or page_limit>100 or (after_time is null)<>(after_id is null) then raise exception 'Invalid page' using errcode='22023';end if;
 select coalesce(jsonb_agg(to_jsonb(m) order by m.created_at,m.id),'[]'::jsonb) into items from
  (select * from public.chat_messages where chat_channel_id=target_channel and (after_time is null or (created_at,id)>(after_time,after_id)) order by created_at,id limit page_limit) m;
 if jsonb_array_length(items)>0 then
  select * into last_message from jsonb_populate_record(null::public.chat_messages,items->(jsonb_array_length(items)-1));
  if exists(select 1 from public.chat_messages where chat_channel_id=target_channel and (created_at,id)>(last_message.created_at,last_message.id)) then
   cursor_value:=jsonb_build_object('createdAt',last_message.created_at,'id',last_message.id);
  end if;
 end if;
 return jsonb_build_object('items',items,'nextCursor',cursor_value);
end $$;
revoke all on function public.send_team_chat_message(uuid,text,uuid),public.list_team_chat_messages(uuid,integer,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.send_team_chat_message(uuid,text,uuid),public.list_team_chat_messages(uuid,integer,timestamptz,uuid) to authenticated;
-- No INSERT/UPDATE/DELETE table grants or new broad policies. No realtime/edit/delete.
commit;
