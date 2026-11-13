begin;
create type public.artifact_type as enum ('DEVELOPED_CONCEPT','PROBLEM_BANK','SOLUTION_BANK','TEAM_DECISION_RECORD','INVENTION_STRUCTURE','GAP_LIST','MIND_MAP','MINIMUM_ESSENTIAL_STRUCTURE','INVENTION_CONCEPT','PATENT_LANDSCAPE','VALIDATION_PLAN','RISK_MAP','PRODUCT_ROADMAP','BUSINESS_FEASIBILITY_ASSESSMENT','TEAM_DEVELOPMENT_MAP','PITCH_DECK_RECORD');
create type public.artifact_status as enum ('ACTIVE','ARCHIVED');
-- Composite provenance FK preserves canonical execution scope without authorization bypass.
alter table public.activity_instances add constraint activity_instances_id_project_workspace_unique unique(id,project_id,workspace_id);
create table public.artifacts (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null,
 workspace_id uuid not null references public.workspaces(id) on delete restrict,
 artifact_type public.artifact_type not null,
 title text not null check(length(btrim(title))>0),
 status public.artifact_status not null default 'ACTIVE',
 current_version_id uuid,
 created_by uuid not null references public.users(id) on delete restrict,
 activity_instance_id uuid,
 review_required boolean not null default false,
 approval_required boolean not null default false,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 archived_at timestamptz,
 constraint artifacts_project_workspace foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id) on update restrict on delete restrict,
 constraint artifacts_activity_scope foreign key(activity_instance_id,project_id,workspace_id) references public.activity_instances(id,project_id,workspace_id) on update restrict on delete restrict,
 constraint artifacts_archive_state check((status='ACTIVE' and archived_at is null) or (status='ARCHIVED' and archived_at is not null))
);
create index artifacts_project_lookup on public.artifacts(project_id);
create index artifacts_workspace_lookup on public.artifacts(workspace_id);
create index artifacts_type_lookup on public.artifacts(artifact_type);
create index artifacts_activity_lookup on public.artifacts(activity_instance_id) where activity_instance_id is not null;
-- Invoker trigger: preservation only, no elevated write path or supplied auth identity.
create function public.preserve_artifact_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Artifact history must be preserved' using errcode='23514';end if;
 if (new.id,new.project_id,new.workspace_id,new.created_by,new.activity_instance_id,new.created_at)
  is distinct from (old.id,old.project_id,old.workspace_id,old.created_by,old.activity_instance_id,old.created_at) then
  raise exception 'Artifact identity and provenance are immutable' using errcode='23514';end if;
 if old.status='ARCHIVED' and new is distinct from old then raise exception 'Archived Artifact history is immutable' using errcode='23514';end if;
 if new is not distinct from old then return old;end if;
 new.updated_at:=pg_catalog.clock_timestamp();return new;
end $$;
revoke all on function public.preserve_artifact_history() from public,anon,authenticated,service_role;
create trigger artifacts_preserve_history before update or delete on public.artifacts for each row execute function public.preserve_artifact_history();
alter table public.artifacts enable row level security;
revoke all on public.artifacts from public,anon,authenticated,service_role;
grant select on public.artifacts to authenticated;
-- Canonical Project authorization already includes active Workspace and exact Team/owner context.
-- Archived reads/restoration remain deferred; no normal access is inferred from history.
create policy artifacts_scoped_read on public.artifacts for select to authenticated using(status='ACTIVE' and public.can_read_development_project(project_id) and exists(select 1 from public.development_projects p where p.id=artifacts.project_id and p.primary_workspace_id=artifacts.workspace_id));
create policy artifacts_read_guard on public.artifacts as restrictive for select to authenticated using(status='ACTIVE' and public.can_read_development_project(project_id) and exists(select 1 from public.development_projects p where p.id=artifacts.project_id and p.primary_workspace_id=artifacts.workspace_id));
create policy artifacts_insert_deny on public.artifacts as restrictive for insert to authenticated with check(false);
create policy artifacts_update_deny on public.artifacts as restrictive for update to authenticated using(false) with check(false);
create policy artifacts_delete_deny on public.artifacts as restrictive for delete to authenticated using(false);
create policy artifacts_anon_deny on public.artifacts as restrictive for all to anon using(false) with check(false);
comment on table public.artifacts is 'M8.1 stable identity, canonical Project/Workspace scope and workflow requirements only. No version body, business creation RPC, review, approval, restore or baseline behavior.';
comment on column public.artifacts.current_version_id is 'Nullable future pointer. Artifact Version FK, same-Artifact validation and pointer lifecycle deferred to M8.2+. No placeholder Version or mutation operation in M8.1.';
comment on column public.artifacts.created_by is 'Canonical platform identity. Future business creation must derive actor from verified auth; ordinary client writes denied.';
comment on column public.artifacts.review_required is 'Requirement only, never reviewed/submitted/approved state.';
comment on column public.artifacts.approval_required is 'Requirement only, never approved/current/verified state.';
commit;
