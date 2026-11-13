begin;
-- Media mappings only. No grant to Team Workspace, Project, Chat or tool data.
create table public.live_team_breakout_rooms (
 id uuid primary key default gen_random_uuid(),
 live_session_room_id uuid not null references public.live_session_rooms(id) on delete restrict,
 team_id uuid not null references public.teams(id) on delete restrict,
 provider text not null default 'DAILY' check(provider='DAILY'),
 provider_room_ref text not null check(provider_room_ref ~ '^fici-[a-f0-9]{64}$'),
 status text not null default 'ACTIVE' check(status in ('ACTIVE','EXPIRED')),
 created_by uuid not null references public.users(id) on delete restrict,
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),ended_at timestamptz,
 check((status='ACTIVE' and ended_at is null) or (status='EXPIRED' and ended_at is not null and ended_at>=created_at))
);
create unique index live_breakout_one_active on public.live_team_breakout_rooms(live_session_room_id,team_id,provider) where status='ACTIVE';
create unique index live_breakout_provider_ref on public.live_team_breakout_rooms(provider,provider_room_ref);
create index live_breakout_history on public.live_team_breakout_rooms(live_session_room_id,team_id,created_at);
alter table public.live_team_breakout_rooms enable row level security;
revoke all on public.live_team_breakout_rooms from public,anon,authenticated,service_role;

create function private.live_breakout_master_context(parent_room uuid,target_team uuid,actor uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.live_session_rooms;t public.teams;previous uuid;
begin
 select * into p from public.live_session_rooms where id=parent_room and provider='DAILY' and status='ACTIVE' and ended_at is null for share;
 select * into t from public.teams where id=target_team and cohort_id=p.cohort_id and status in ('created','active') and archived_at is null for share;
 if p.id is null or t.id is null or not exists(select 1 from public.users where id=actor and account_status='active') then raise exception 'Access denied' using errcode='42501';end if;
 perform private.master_live_room_context(p.cohort_id,p.session_definition_id,null,actor);
 -- Admin room-management authority alone is not an instructor participation grant.
 if not exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.user_id=actor and r.code='MASTER' and r.is_system_role and a.cohort_id=p.cohort_id and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp()) and num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id)=1) then raise exception 'Access denied' using errcode='42501';end if;
 select id into previous from public.live_team_breakout_rooms where live_session_room_id=p.id and team_id=t.id and provider='DAILY' and status='EXPIRED' order by ended_at desc,id desc limit 1;
 return jsonb_build_object('actorId',actor,'liveSessionRoomId',p.id,'teamId',t.id,'roomKey','fici-'||encode(sha256(convert_to('breakout:'||p.id::text||':'||t.id::text||':'||coalesce(previous::text,'initial'),'UTF8')),'hex'));
end $$;
revoke all on function private.live_breakout_master_context(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function public.authorize_master_live_breakout(parent_room uuid,target_team uuid) returns jsonb
language sql security definer set search_path='' as $$select private.live_breakout_master_context(parent_room,target_team,public.current_platform_user_id())$$;
revoke all on function public.authorize_master_live_breakout(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.authorize_master_live_breakout(uuid,uuid) to authenticated;

create function public.list_live_breakout_teams(parent_room uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.live_session_rooms;actor uuid:=public.current_platform_user_id();
begin
 select * into p from public.live_session_rooms where id=parent_room and status='ACTIVE';
 if p.id is null or not public.has_active_role_in_cohort('MASTER',p.cohort_id) then raise exception 'Access denied' using errcode='42501';end if;
 perform private.master_live_room_context(p.cohort_id,p.session_definition_id,null,actor);
 return coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id) from public.teams where cohort_id=p.cohort_id and status in ('created','active') and archived_at is null),'[]'::jsonb);
end $$;
revoke all on function public.list_live_breakout_teams(uuid) from public,anon,authenticated,service_role;
grant execute on function public.list_live_breakout_teams(uuid) to authenticated;

create function public.manage_live_breakout_mapping(command text,parent_room uuid,target_team uuid,actor uuid,room_reference text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare ctx jsonb;r public.live_team_breakout_rooms;
begin
 if command is null or command not in ('FIND_ACTIVE','REUSE_OR_CREATE','EXPIRE') then raise exception 'Invalid operation' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('breakout:'||parent_room::text||':'||target_team::text,0));
 ctx:=private.live_breakout_master_context(parent_room,target_team,actor);
 select * into r from public.live_team_breakout_rooms where live_session_room_id=parent_room and team_id=target_team and provider='DAILY' and status='ACTIVE' for update;
 if command='EXPIRE' then
  if r.id is not null then update public.live_team_breakout_rooms set status='EXPIRED' where id=r.id returning * into r;end if;
 elsif command='REUSE_OR_CREATE' and r.id is null then
  if room_reference is distinct from ctx->>'roomKey' then raise exception 'Invalid room reference' using errcode='22023';end if;
  insert into public.live_team_breakout_rooms(live_session_room_id,team_id,provider_room_ref,created_by) values(parent_room,target_team,room_reference,actor) returning * into r;
 end if;
 return case when r.id is null then null else to_jsonb(r) end;
end $$;
revoke all on function public.manage_live_breakout_mapping(text,uuid,uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.manage_live_breakout_mapping(text,uuid,uuid,uuid,text) to service_role;

create function private.guard_live_breakout_mapping() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Breakout history retained' using errcode='23514';end if;
 if tg_op='INSERT' then
  if new.status<>'ACTIVE' or new.ended_at is not null or not exists(select 1 from public.live_session_rooms p join public.teams t on t.cohort_id=p.cohort_id where p.id=new.live_session_room_id and t.id=new.team_id and p.status='ACTIVE' and t.status in ('created','active') and t.archived_at is null) then raise exception 'Invalid breakout context' using errcode='23514';end if;
  new.created_at:=clock_timestamp();new.updated_at:=new.created_at;
 else
  if (new.id,new.live_session_room_id,new.team_id,new.provider,new.provider_room_ref,new.created_by,new.created_at) is distinct from (old.id,old.live_session_room_id,old.team_id,old.provider,old.provider_room_ref,old.created_by,old.created_at) or old.status<>'ACTIVE' or new.status<>'EXPIRED' then raise exception 'Immutable breakout history' using errcode='23514';end if;
  new.updated_at:=clock_timestamp();new.ended_at:=new.updated_at;
 end if;return new;
end $$;
revoke all on function private.guard_live_breakout_mapping() from public,anon,authenticated,service_role;
create trigger guard_live_breakout before insert or update or delete on public.live_team_breakout_rooms for each row execute function private.guard_live_breakout_mapping();

create function private.expire_child_live_breakouts() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='EXPIRED' and old.status='ACTIVE' then update public.live_team_breakout_rooms set status='EXPIRED' where live_session_room_id=new.id and status='ACTIVE';end if;return new;
end $$;
revoke all on function private.expire_child_live_breakouts() from public,anon,authenticated,service_role;
create trigger expire_child_live_breakouts after update on public.live_session_rooms for each row execute function private.expire_child_live_breakouts();

create function public.authorize_live_breakout_join(target_breakout uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare b public.live_team_breakout_rooms;p public.live_session_rooms;t public.teams;actor uuid:=public.current_platform_user_id();kind text;display text;
begin
 select * into b from public.live_team_breakout_rooms where id=target_breakout and status='ACTIVE' and provider='DAILY';
 select * into p from public.live_session_rooms where id=b.live_session_room_id and status='ACTIVE' and provider='DAILY' and ended_at is null;
 select * into t from public.teams where id=b.team_id and cohort_id=p.cohort_id and status in ('created','active') and archived_at is null;
 if actor is null or b.id is null or p.id is null or t.id is null then raise exception 'Access denied' using errcode='42501';end if;
 if public.can_join_live_session(p.id) and public.get_team_workspace_access(t.workspace_id) in ('member','team_lead') then kind:='STUDENT';
 else perform private.live_breakout_master_context(p.id,t.id,actor);kind:='MASTER';end if;
 select coalesce(nullif(btrim(display_name),''),'FICI participant') into display from public.users where id=actor and account_status='active';
 if display is null then raise exception 'Access denied' using errcode='42501';end if;
 return jsonb_build_object('breakoutRoomId',b.id,'liveSessionRoomId',p.id,'teamId',t.id,'cohortId',p.cohort_id,'sessionDefinitionId',p.session_definition_id,'providerRoomRef',b.provider_room_ref,'userId',actor,'displayName',left(display,255),'participantRole',kind);
end $$;
revoke all on function public.authorize_live_breakout_join(uuid) from public,anon,authenticated,service_role;
grant execute on function public.authorize_live_breakout_join(uuid) to authenticated;
create function public.find_team_live_breakout(parent_room uuid,target_team uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare t public.teams;result uuid;
begin
 select t0.* into t from public.teams t0 join public.live_session_rooms p on p.cohort_id=t0.cohort_id where p.id=parent_room and p.status='ACTIVE' and t0.id=target_team and t0.status in ('created','active') and t0.archived_at is null;
 if t.id is null then raise exception 'Access denied' using errcode='42501';end if;
 if (public.can_join_live_session(parent_room) and public.get_team_workspace_access(t.workspace_id) in ('member','team_lead')) is not true then perform private.live_breakout_master_context(parent_room,target_team,public.current_platform_user_id());end if;
 select id into result from public.live_team_breakout_rooms where live_session_room_id=parent_room and team_id=target_team and status='ACTIVE';
 if result is not null then perform public.authorize_live_breakout_join(result);end if;return result;
end $$;
revoke all on function public.find_team_live_breakout(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.find_team_live_breakout(uuid,uuid) to authenticated;
commit;
