begin;
create extension if not exists btree_gist;
create type public.project_membership_role as enum ('participant');
create type public.project_membership_status as enum ('active','inactive');
create table public.project_memberships (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.development_projects(id) on delete restrict,
 user_id uuid not null references public.users(id) on delete restrict,
 project_role public.project_membership_role not null default 'participant',
 starts_at timestamptz not null default now(),ends_at timestamptz,
 status public.project_membership_status not null default 'active',
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(ends_at is null or ends_at>=starts_at),check(status<>'inactive' or ends_at is not null),
 constraint project_memberships_no_active_overlap exclude using gist
 (project_id with =,user_id with =,tstzrange(starts_at,ends_at,'[)') with &&) where(status='active')
);
-- A range exclusion is concurrency-safe and permits new, non-overlapping periods
-- after an expired row without rewriting it. No cross-Project exclusivity.
create index project_memberships_project_lookup on public.project_memberships(project_id);
create index project_memberships_user_lookup on public.project_memberships(user_id);
create index project_memberships_active_lookup on public.project_memberships(user_id,project_id,starts_at,ends_at) where status='active';
create function public.preserve_project_membership_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Project participation history must be preserved' using errcode='23514';end if;
 if (new.id,new.project_id,new.user_id,new.starts_at,new.created_at) is distinct from (old.id,old.project_id,old.user_id,old.starts_at,old.created_at)
 then raise exception 'Project membership historical identity is immutable' using errcode='23514';end if;
 if (old.status='inactive' or (old.ends_at is not null and old.ends_at<=statement_timestamp())) and new is distinct from old
 then raise exception 'Ended Project membership history is immutable' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_project_membership_history() from public,anon,authenticated,service_role;
create trigger project_memberships_preserve_history before update or delete on public.project_memberships for each row execute function public.preserve_project_membership_history();
alter table public.project_memberships enable row level security;
revoke all on public.project_memberships from public,anon,authenticated,service_role;
create policy project_memberships_client_deny on public.project_memberships as restrictive for all to anon,authenticated using(false) with check(false);
-- Definer returns a caller-bound boolean only; prevents recursive RLS without
-- exposing membership history or accepting an arbitrary participant identity.
create function public.has_active_project_membership(target_project uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.project_memberships m where m.project_id=target_project and m.user_id=public.current_platform_user_id()
 and m.project_role='participant' and m.status='active' and m.starts_at<=statement_timestamp() and (m.ends_at is null or m.ends_at>statement_timestamp()));
$$;
revoke all on function public.has_active_project_membership(uuid) from public,anon,authenticated,service_role;
grant execute on function public.has_active_project_membership(uuid) to authenticated;
create or replace function public.can_read_development_project(target_project uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.development_projects p join public.workspaces w on w.id=p.primary_workspace_id
 where p.id=target_project and p.status='active' and w.status='active' and w.visibility='private' and public.current_platform_user_id() is not null and (
  (p.project_type='individual' and p.owner_user_id=public.current_platform_user_id() and p.owner_team_id is null
   and w.workspace_type='PERSONAL' and w.owner_user_id=p.owner_user_id and w.team_id is null)
  or (p.project_type='team' and w.workspace_type='TEAM' and w.team_id=p.owner_team_id and public.get_team_workspace_access(w.id) is not null and public.has_active_project_membership(p.id))
  or (p.project_type='instructor_case_study' and p.owner_user_id=public.current_platform_user_id() and p.owner_team_id is null
   and w.workspace_type='CASE_STUDY' and w.owner_user_id=p.owner_user_id and w.team_id is null
   and w.cohort_id is not null and public.has_active_role_in_cohort('MASTER',w.cohort_id))));
$$;
comment on table public.project_memberships is 'M6.2 explicit historical participation. No management API, Team synchronization, extra roles or non-owner Individual/Case Study permissions.';
commit;
