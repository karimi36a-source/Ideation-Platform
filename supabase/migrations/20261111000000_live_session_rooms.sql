begin;
create table public.live_session_rooms (
 id uuid primary key default gen_random_uuid(),
 cohort_id uuid not null references public.cohorts(id) on delete restrict,
 session_definition_id uuid not null references public.session_definitions(id) on delete restrict,
 provider text not null check(provider='DAILY'),
 provider_room_ref text not null check(provider_room_ref ~ '^[A-Za-z0-9_-]{1,128}$'),
 status text not null default 'ACTIVE' check(status in ('ACTIVE','EXPIRED')),
 created_by uuid not null references public.users(id) on delete restrict,
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 ended_at timestamptz,
 check((status='ACTIVE' and ended_at is null) or (status='EXPIRED' and ended_at is not null and ended_at>=created_at))
);
create unique index live_session_rooms_one_active on public.live_session_rooms(cohort_id,session_definition_id,provider) where status='ACTIVE';
-- A provider reference cannot be reassigned to another context or resurrected.
create unique index live_session_rooms_provider_reference on public.live_session_rooms(provider,provider_room_ref);
create index live_session_rooms_history on public.live_session_rooms(cohort_id,session_definition_id,provider,created_at);
create function private.guard_live_session_room() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Live room history retained' using errcode='23514';end if;
 if not exists(select 1 from public.cohorts c join public.session_definitions s on s.curriculum_version_id=c.curriculum_version_id where c.id=new.cohort_id and s.id=new.session_definition_id) then
  raise exception 'Invalid live room context' using errcode='23514';end if;
 if tg_op='INSERT' then
  if new.status<>'ACTIVE' or new.ended_at is not null then raise exception 'Invalid initial room state' using errcode='23514';end if;
  new.created_at:=clock_timestamp();new.updated_at:=new.created_at;
 else
  if (new.id,new.cohort_id,new.session_definition_id,new.provider,new.provider_room_ref,new.created_by,new.created_at)
   is distinct from (old.id,old.cohort_id,old.session_definition_id,old.provider,old.provider_room_ref,old.created_by,old.created_at)
   or old.status='EXPIRED' or new.status<>'EXPIRED' then raise exception 'Immutable live room history' using errcode='23514';end if;
  new.updated_at:=clock_timestamp();new.ended_at:=new.updated_at;
 end if;
 return new;
end $$;
revoke all on function private.guard_live_session_room() from public,anon,authenticated,service_role;
create trigger live_session_rooms_guard before insert or update or delete on public.live_session_rooms for each row execute function private.guard_live_session_room();
alter table public.live_session_rooms enable row level security;
revoke all on public.live_session_rooms from public,anon,authenticated,service_role;
-- No recipient read policy: mapping is internal metadata, never a capability.
create function public.manage_live_room_mapping(command text,target_cohort uuid,target_session uuid,target_provider text,room_reference text,actor uuid,expected_room uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare current_room public.live_session_rooms; result public.live_session_rooms;
begin
 if command is null or command not in ('FIND_ACTIVE','REUSE_OR_CREATE','EXPIRE','REPLACE') or target_provider is distinct from 'DAILY'
 or target_cohort is null or target_session is null or actor is null
 or not exists(select 1 from public.users where id=actor and account_status='active') then raise exception 'Invalid room mapping command' using errcode='22023';end if;
 if not exists(select 1 from public.cohorts c join public.session_definitions s on s.curriculum_version_id=c.curriculum_version_id where c.id=target_cohort and s.id=target_session) then raise exception 'Invalid live room context' using errcode='23514';end if;
 if (command in ('FIND_ACTIVE','REUSE_OR_CREATE') and expected_room is not null) or (command in ('EXPIRE','REPLACE') and expected_room is null)
 or (command in ('EXPIRE','FIND_ACTIVE') and room_reference is not null) or (command in ('REUSE_OR_CREATE','REPLACE') and (room_reference is null or room_reference !~ '^[A-Za-z0-9_-]{1,128}$')) then raise exception 'Invalid room mapping command' using errcode='22023';end if;
 -- Serialize the canonical context; the partial unique index is a second guard.
 perform pg_advisory_xact_lock(hashtextextended(target_cohort::text||':'||target_session::text||':'||target_provider,0));
 select * into current_room from public.live_session_rooms where cohort_id=target_cohort and session_definition_id=target_session and provider=target_provider and status='ACTIVE' for update;
 if command='FIND_ACTIVE' then return case when current_room.id is null then null else to_jsonb(current_room) end;end if;
 if command='REUSE_OR_CREATE' and current_room.id is not null then return to_jsonb(current_room);end if;
 if command='EXPIRE' then
  select * into result from public.live_session_rooms where id=expected_room and cohort_id=target_cohort and session_definition_id=target_session and provider=target_provider for update;
  if result.id is null then raise exception 'Room mapping conflict' using errcode='40001';end if;
  if result.status='ACTIVE' then update public.live_session_rooms set status='EXPIRED' where id=result.id returning * into result;end if;
  return to_jsonb(result);
 end if;
 if command='REPLACE' then
  -- An explicit replacement retry may reuse its result, never an unrelated row.
  if current_room.provider_room_ref=room_reference and exists(select 1 from public.live_session_rooms where id=expected_room and cohort_id=target_cohort and session_definition_id=target_session and provider=target_provider and status='EXPIRED') then return to_jsonb(current_room);end if;
  if current_room.id is not null and current_room.id<>expected_room then raise exception 'Room mapping conflict' using errcode='40001';end if;
  if not exists(select 1 from public.live_session_rooms where id=expected_room and cohort_id=target_cohort and session_definition_id=target_session and provider=target_provider) then raise exception 'Room mapping conflict' using errcode='40001';end if;
  if current_room.id is not null then update public.live_session_rooms set status='EXPIRED' where id=current_room.id;end if;
 end if;
 insert into public.live_session_rooms(cohort_id,session_definition_id,provider,provider_room_ref,created_by)
 values(target_cohort,target_session,target_provider,room_reference,actor) returning * into result;
 return to_jsonb(result);
end $$;
revoke all on function public.manage_live_room_mapping(text,uuid,uuid,text,text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.manage_live_room_mapping(text,uuid,uuid,text,text,uuid,uuid) to service_role;
comment on function public.manage_live_room_mapping(text,uuid,uuid,text,text,uuid,uuid) is 'Internal M16.2 persistence only. Trusted server supplies verified actor after operation authorization. No room opening/join authorization or provider calls.';
commit;
