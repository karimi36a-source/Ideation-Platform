begin;
alter table public.cohorts add constraint cohorts_id_program_unique unique(id,program_id);
create table public.project_program_links (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.development_projects(id) on delete restrict,
 program_id uuid not null references public.programs(id) on delete restrict,
 cohort_id uuid not null,
 entered_at timestamptz not null default now(),completed_at timestamptz,
 entry_artifact_version_id uuid,exit_artifact_version_id uuid,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 foreign key(cohort_id,program_id) references public.cohorts(id,program_id) on delete restrict on update restrict,
 check(completed_at is null or completed_at>=entered_at)
);
create unique index project_program_links_one_open_context on public.project_program_links(project_id,program_id,cohort_id) where completed_at is null;
create index project_program_links_project_time on public.project_program_links(project_id,entered_at,id);
create index project_program_links_program_cohort on public.project_program_links(program_id,cohort_id);
comment on column public.project_program_links.entry_artifact_version_id is 'Nullable UUID. Artifact Version FK and ownership validation deferred to M8; M6.4 RPC rejects supplied IDs.';
comment on column public.project_program_links.exit_artifact_version_id is 'Nullable UUID. Artifact Version FK and ownership validation deferred to M8; no client write path.';
create function public.preserve_project_program_link_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Participation history must be preserved' using errcode='23514';end if;
 if (new.id,new.project_id,new.program_id,new.cohort_id,new.entered_at,new.created_at) is distinct from
 (old.id,old.project_id,old.program_id,old.cohort_id,old.entered_at,old.created_at)
 or (old.completed_at is not null and new is distinct from old) then raise exception 'Participation history is immutable' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_project_program_link_history() from public,anon,authenticated,service_role;
create trigger project_program_links_preserve_history before update or delete on public.project_program_links for each row execute function public.preserve_project_program_link_history();
-- Scope visibility does not imply private Project visibility. Definer is limited
-- to a caller-bound boolean and avoids exposing enrollments or recursive RLS.
create function public.can_read_project_program_link(target_link uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.project_program_links l join public.cohorts c on c.id=l.cohort_id and c.program_id=l.program_id
 join public.programs p on p.id=c.program_id where l.id=target_link and public.can_read_development_project(l.project_id) and (
 exists(select 1 from public.enrollments e where e.user_id=public.current_platform_user_id() and e.cohort_id=c.id and e.status in ('active','completed'))
 or public.has_active_role_in_cohort('MASTER',c.id) or public.has_active_role_in_organization('ADMIN',p.organization_id)));
$$;
revoke all on function public.can_read_project_program_link(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_project_program_link(uuid) to authenticated;
alter table public.project_program_links enable row level security;
revoke all on public.project_program_links from public,anon,authenticated,service_role;
grant select on public.project_program_links to authenticated;
create policy project_program_links_scoped_read on public.project_program_links for select to authenticated using(public.can_read_project_program_link(id));
create policy project_program_links_read_guard on public.project_program_links as restrictive for select to authenticated using(public.can_read_project_program_link(id));
create policy project_program_links_insert_deny on public.project_program_links as restrictive for insert to authenticated with check(false);
create policy project_program_links_update_deny on public.project_program_links as restrictive for update to authenticated using(false) with check(false);
create policy project_program_links_delete_deny on public.project_program_links as restrictive for delete to authenticated using(false);
create policy project_program_links_anonymous_deny on public.project_program_links as restrictive for all to anon using(false) with check(false);
create function public.link_project_to_program(target_project uuid,target_program uuid,target_cohort uuid,entry_version uuid default null)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;p public.development_projects;w public.workspaces;c public.cohorts;pr public.programs;source_cohort uuid;l public.project_program_links;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 if not public.can_read_development_project(target_project) then raise exception 'Access denied' using errcode='42501';end if;
 select * into p from public.development_projects where id=target_project;
 select * into w from public.workspaces where id=p.primary_workspace_id;
 source_cohort:=w.cohort_id;
 -- Cohort-first lock ordering matches Team/enrollment operations. Lock both
 -- contexts in deterministic order, then preserve current Project eligibility.
 perform 1 from public.cohorts where id in (source_cohort,target_cohort) order by id for share;
 if p.owner_team_id is not null then perform 1 from public.teams where id=p.owner_team_id for share;end if;
 select * into p from public.development_projects where id=target_project for update;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 select * into w from public.workspaces where id=p.primary_workspace_id for share;
 if not found or w.cohort_id is distinct from source_cohort then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 perform 1 from public.enrollments where user_id=actor order by id for share;
 perform 1 from public.project_memberships where project_id=p.id and user_id=actor order by id for share;
 if p.owner_team_id is not null then perform 1 from public.team_memberships where team_id=p.owner_team_id and user_id=actor order by id for share;end if;
 if not public.can_read_development_project(p.id) or public.current_platform_user_id() is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.cohorts where id=target_cohort;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 select * into pr from public.programs where id=c.program_id for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 if p.project_type='individual' then
  if p.owner_user_id is distinct from actor or not exists(select 1 from public.enrollments e where e.user_id=actor and e.cohort_id=c.id and e.status='active' and e.enrollment_role='participant')
  then raise exception 'Access denied' using errcode='42501';end if;
 elsif p.project_type='team' then
  if not public.can_manage_team(p.owner_team_id) or not (public.has_active_role_in_cohort('MASTER',c.id) or public.has_active_role_in_organization('ADMIN',pr.organization_id))
  then raise exception 'Access denied' using errcode='42501';end if;
 else
  if p.owner_user_id is distinct from actor or not public.has_active_role_in_cohort('MASTER',c.id) then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 if c.program_id is distinct from target_program or pr.status<>'active' or c.status not in ('planned','active') then raise exception 'Invalid participation input' using errcode='22023';end if;
 if entry_version is not null then raise exception 'Required Artifact Version dependency unavailable' using errcode='0A000';end if;
 -- Project row lock serializes retries. Reject open duplicates and same-context
 -- completed re-entry until an explicit re-entry policy is approved.
 if exists(select 1 from public.project_program_links where project_id=p.id and program_id=pr.id and cohort_id=c.id)
 then raise exception 'Participation conflict' using errcode='23505';end if;
 insert into public.project_program_links(project_id,program_id,cohort_id,entered_at) values(p.id,pr.id,c.id,clock_timestamp()) returning * into l;
 return to_jsonb(l);
end $$;
revoke all on function public.link_project_to_program(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.link_project_to_program(uuid,uuid,uuid,uuid) to authenticated;
commit;
