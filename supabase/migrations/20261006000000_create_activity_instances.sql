begin;
create type public.activity_instance_status as enum ('not_started','active','submitted','under_review','revision_requested','completed','archived');
create table public.activity_instances (
 id uuid primary key default gen_random_uuid(),
 activity_definition_id uuid not null references public.activity_definitions(id) on delete restrict,
 cohort_id uuid not null references public.cohorts(id) on delete restrict,
 project_id uuid not null references public.development_projects(id) on delete restrict,
 workspace_id uuid not null references public.workspaces(id) on delete restrict,
 team_id uuid references public.teams(id) on delete restrict,
 started_by uuid references public.users(id) on delete restrict,
 started_at timestamptz,completed_at timestamptz,
 status public.activity_instance_status not null default 'not_started',
 configuration_snapshot jsonb not null default '{}'::jsonb check(jsonb_typeof(configuration_snapshot)='object'),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint activity_instances_timestamps check (
  (status='not_started' and started_by is null and started_at is null and completed_at is null)
  or (status in ('active','submitted','under_review','revision_requested') and started_by is not null and started_at is not null and completed_at is null)
  or (status='completed' and started_by is not null and started_at is not null and completed_at is not null and completed_at>=started_at)
  or (status='archived' and started_by is not null and started_at is not null and (completed_at is null or completed_at>=started_at)))
);
create index activity_instances_definition_lookup on public.activity_instances(activity_definition_id);
create index activity_instances_cohort_lookup on public.activity_instances(cohort_id);
create index activity_instances_project_lookup on public.activity_instances(project_id);
create index activity_instances_workspace_lookup on public.activity_instances(workspace_id);
create index activity_instances_team_lookup on public.activity_instances(team_id);
create index activity_instances_status_lookup on public.activity_instances(status);
create index activity_instances_actor_lookup on public.activity_instances(started_by);
-- Invoker trigger validates trusted writes. Normal clients have no write grants.
-- It does not provision resources, start an Activity, or derive a snapshot.
create function public.validate_activity_instance_context() returns trigger language plpgsql set search_path='' as $$
declare p public.development_projects;w public.workspaces;c public.cohorts;t public.teams;cv uuid;begin
 if tg_op='DELETE' then raise exception 'Activity history must be preserved' using errcode='23514';end if;
 if tg_op='UPDATE' then
  if (new.id,new.activity_definition_id,new.cohort_id,new.project_id,new.workspace_id,new.team_id,new.created_at) is distinct from
   (old.id,old.activity_definition_id,old.cohort_id,old.project_id,old.workspace_id,old.team_id,old.created_at) then raise exception 'Activity context is immutable' using errcode='23514';end if;
  if old.started_at is not null and (new.started_by,new.started_at,new.configuration_snapshot) is distinct from (old.started_by,old.started_at,old.configuration_snapshot) then raise exception 'Started Activity history is immutable' using errcode='23514';end if;
  if old.completed_at is not null and new.completed_at is distinct from old.completed_at then raise exception 'Completion history is immutable' using errcode='23514';end if;
  if old.status='archived' and new is distinct from old then raise exception 'Archived Activity history is immutable' using errcode='23514';end if;
  if old.status='not_started' and new.status='archived' then raise exception 'Unstarted archive is not supported' using errcode='23514';end if;
  -- Preserve existing execution even after enrollment/participation ends.
  if not (old.status='not_started' and new.status<>'not_started') then return new;end if;
 end if;
 select * into p from public.development_projects where id=new.project_id for share;
 select * into w from public.workspaces where id=new.workspace_id for share;
 select * into c from public.cohorts where id=new.cohort_id for share;
 select s.curriculum_version_id into cv from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id where a.id=new.activity_definition_id;
 if p.id is null or w.id is null or c.id is null or cv is null then raise exception 'Invalid Activity reference' using errcode='23503';end if;
 if p.primary_workspace_id<>w.id or p.status<>'active' or p.archived_at is not null or w.status<>'active' or w.visibility<>'private' or cv<>c.curriculum_version_id then raise exception 'Invalid Activity context' using errcode='23514';end if;
 if p.project_type='team' then
  select * into t from public.teams where id=new.team_id for share;
  if t.id is null or t.id is distinct from p.owner_team_id or t.cohort_id<>c.id or t.workspace_id<>w.id or w.team_id is distinct from t.id or w.cohort_id is distinct from c.id or w.workspace_type<>'TEAM' or t.status not in ('created','active') then raise exception 'Invalid Activity Team context' using errcode='23514';end if;
 else
  if new.team_id is not null or w.team_id is not null or w.owner_user_id is distinct from p.owner_user_id or w.workspace_type<>p.required_workspace_type then raise exception 'Invalid Activity owner context' using errcode='23514';end if;
  if p.project_type='instructor_case_study' and (w.cohort_id is distinct from c.id or not exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.user_id=p.owner_user_id and r.code='MASTER' and a.cohort_id=c.id and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp()))) then raise exception 'Invalid Activity Master context' using errcode='23514';end if;
 end if;
 perform 1 from public.project_program_links l where l.project_id=p.id and l.program_id=c.program_id and l.cohort_id=c.id and l.completed_at is null for share;
 if not found then raise exception 'Active Project participation required' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.validate_activity_instance_context() from public,anon,authenticated,service_role;
create trigger activity_instances_validate before insert or update or delete on public.activity_instances for each row execute function public.validate_activity_instance_context();
-- Caller-bound boolean only. Definer avoids protected enrollment/Project-link
-- RLS recursion; fixed empty path, no supplied actor, no private row returned.
create function public.can_read_activity_instance(target_instance uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.activity_instances i join public.development_projects p on p.id=i.project_id and p.primary_workspace_id=i.workspace_id
 join public.workspaces w on w.id=i.workspace_id join public.cohorts c on c.id=i.cohort_id
 join public.activity_definitions a on a.id=i.activity_definition_id join public.session_definitions s on s.id=a.session_definition_id
 where i.id=target_instance and s.curriculum_version_id=c.curriculum_version_id and public.can_read_development_project(p.id)
 and w.status='active' and w.visibility='private'
 and ((p.project_type='team' and i.team_id=p.owner_team_id and w.team_id=i.team_id and w.cohort_id=c.id and public.get_team_workspace_access(w.id) is not null)
  or (p.project_type='individual' and i.team_id is null and w.workspace_type='PERSONAL' and w.owner_user_id=public.current_platform_user_id())
  or (p.project_type='instructor_case_study' and i.team_id is null and w.cohort_id=c.id and w.owner_user_id=public.current_platform_user_id() and public.has_active_role_in_cohort('MASTER',c.id)))
 and exists(select 1 from public.project_program_links l where l.project_id=p.id and l.program_id=c.program_id and l.cohort_id=c.id and l.completed_at is null)
 and (exists(select 1 from public.enrollments e where e.user_id=public.current_platform_user_id() and e.cohort_id=c.id and e.status='active')
  or public.has_active_role_in_cohort('MASTER',c.id)
  or (i.team_id is not null and public.has_active_role_in_team('MASTER',i.team_id))));
$$;
revoke all on function public.can_read_activity_instance(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_activity_instance(uuid) to authenticated;
alter table public.activity_instances enable row level security;
revoke all on public.activity_instances from public,anon,authenticated,service_role;
grant select on public.activity_instances to authenticated;
create policy activity_instances_scoped_read on public.activity_instances for select to authenticated using(public.can_read_activity_instance(id));
create policy activity_instances_read_guard on public.activity_instances as restrictive for select to authenticated using(public.can_read_activity_instance(id));
create policy activity_instances_insert_deny on public.activity_instances as restrictive for insert to authenticated with check(false);
create policy activity_instances_update_deny on public.activity_instances as restrictive for update to authenticated using(false) with check(false);
create policy activity_instances_delete_deny on public.activity_instances as restrictive for delete to authenticated using(false);
create policy activity_instances_anonymous_deny on public.activity_instances as restrictive for all to anon using(false) with check(false);
comment on table public.activity_instances is 'M7.1 schema only. New execution requires open exact Project/Program/Cohort participation. No start/archive/review/participant operations.';
comment on column public.activity_instances.started_by is 'Null before start. Later start RPC must bind to verified server identity; direct client mutations denied.';
comment on column public.activity_instances.configuration_snapshot is 'Relevant canonical Definition configuration only. Empty schema default, populated at future start; immutable after start, never authorizes.';
commit;
