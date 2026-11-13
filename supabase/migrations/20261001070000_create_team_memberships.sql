begin;
create type public.team_membership_role as enum ('member','team_lead','mentor');
create type public.team_membership_status as enum ('active','removed');
create table public.team_memberships (
 id uuid primary key default gen_random_uuid(),
 team_id uuid not null references public.teams(id) on delete restrict,
 user_id uuid not null references public.users(id) on delete restrict,
 membership_role public.team_membership_role not null,
 joined_at timestamptz not null,
 left_at timestamptz,
 status public.team_membership_status not null default 'active',
 added_by uuid not null references public.users(id) on delete restrict,
 removed_by uuid references public.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 constraint team_memberships_lifecycle check (
  (status='active' and left_at is null and removed_by is null)
  or (status='removed' and left_at is not null and removed_by is not null and left_at>=joined_at)
 )
);
create unique index team_memberships_one_active_user_team on public.team_memberships(team_id,user_id) where status='active';
create index team_memberships_team_lookup on public.team_memberships(team_id);
create index team_memberships_user_active_lookup on public.team_memberships(user_id,team_id,joined_at) where status='active';
-- No cross-Team exclusivity: Program/Cohort eligibility policy remains deferred.
create function public.preserve_team_membership_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Membership history must be preserved' using errcode='23514';end if;
 if new.joined_at is distinct from old.joined_at or new.id is distinct from old.id
  or new.team_id is distinct from old.team_id or new.user_id is distinct from old.user_id
  or new.added_by is distinct from old.added_by or new.created_at is distinct from old.created_at
 then raise exception 'Membership historical identity is immutable' using errcode='23514';end if;
 if old.status='removed' and new is distinct from old then
  raise exception 'Removed membership history is immutable' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_team_membership_history() from public,anon,authenticated,service_role;
create trigger team_memberships_preserve_history before update or delete on public.team_memberships
 for each row execute function public.preserve_team_membership_history();
alter table public.team_memberships enable row level security;
revoke all on public.team_memberships from public,anon,authenticated,service_role;
comment on table public.team_memberships is 'M5.2 historical membership schema only. No client access, business operations, Workspace/Chat authorization or cross-Team exclusivity introduced.';
commit;
