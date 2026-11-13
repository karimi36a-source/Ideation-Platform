-- M7.2: explicit historical participation, never an independent access grant.
create table public.activity_participants (
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 user_id uuid not null references public.users(id) on delete restrict,
 participant_role text not null default 'participant' check (participant_role = 'participant'),
 joined_at timestamptz not null,
 completed_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint activity_participant_period check (completed_at is null or completed_at >= joined_at)
);
create unique index activity_participants_one_open_period on public.activity_participants(activity_instance_id,user_id) where completed_at is null;
create index activity_participants_user_lookup on public.activity_participants(user_id,activity_instance_id);
create index activity_participants_ordered_history on public.activity_participants(activity_instance_id,joined_at,id);

create function public.preserve_activity_participant_history() returns trigger
language plpgsql set search_path = '' as $$
begin
 if TG_OP = 'DELETE' then raise exception 'Activity participation history is preserved' using errcode = '23514'; end if;
 if (new.id,new.activity_instance_id,new.user_id,new.participant_role,new.joined_at,new.created_at)
    is distinct from (old.id,old.activity_instance_id,old.user_id,old.participant_role,old.joined_at,old.created_at)
    or (old.completed_at is not null and new is distinct from old) then
  raise exception 'Activity participation history is immutable' using errcode = '23514';
 end if;
 if new is not distinct from old then return old; end if;
 new.updated_at := now();
 return new;
end $$;
revoke all on function public.preserve_activity_participant_history() from public,anon,authenticated,service_role;
create trigger activity_participants_preserve_history before update or delete on public.activity_participants
for each row execute function public.preserve_activity_participant_history();

alter table public.activity_participants enable row level security;
revoke all on public.activity_participants from public,anon,authenticated,service_role;
grant select on public.activity_participants to authenticated;
create policy activity_participants_parent_read on public.activity_participants for select to authenticated
using (public.can_read_activity_instance(activity_instance_id));
create policy activity_participants_parent_read_guard on public.activity_participants as restrictive for select to authenticated
using (public.can_read_activity_instance(activity_instance_id));
create policy activity_participants_no_insert on public.activity_participants as restrictive for insert to authenticated with check (false);
create policy activity_participants_no_update on public.activity_participants as restrictive for update to authenticated using (false) with check (false);
create policy activity_participants_no_delete on public.activity_participants as restrictive for delete to authenticated using (false);
create policy activity_participants_no_anonymous on public.activity_participants as restrictive for all to anon using (false) with check (false);
comment on table public.activity_participants is 'Explicit historical participation only. Reads follow current parent Activity authorization. M7.6 owns eligibility validation and participant creation; no auto-add or client mutation path exists in M7.2.';
