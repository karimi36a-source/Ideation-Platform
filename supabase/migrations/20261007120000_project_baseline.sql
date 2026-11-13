begin;

alter table public.artifacts add constraint artifacts_id_project_unique unique(id,project_id);
create table public.project_baseline_items (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.development_projects(id) on update restrict on delete restrict,
 baseline_type text not null check(baseline_type ~ '^[A-Z][A-Z0-9_]*$'),
 artifact_id uuid not null,
 artifact_version_id uuid not null,
 effective_from timestamptz not null default clock_timestamp(),
 effective_to timestamptz,
 set_by uuid not null references public.users(id) on update restrict on delete restrict,
 foreign key(artifact_id,project_id) references public.artifacts(id,project_id) on update restrict on delete restrict,
 foreign key(artifact_version_id,artifact_id) references public.artifact_versions(id,artifact_id) on update restrict on delete restrict,
 check(effective_to is null or effective_to>=effective_from)
);
create unique index project_baseline_one_effective on public.project_baseline_items(project_id,baseline_type) where effective_to is null;
create index project_baseline_history on public.project_baseline_items(project_id,baseline_type,effective_from,id);
alter table public.project_baseline_items enable row level security;
revoke all on public.project_baseline_items from public,anon,authenticated,service_role;
grant select on public.project_baseline_items to authenticated;
create policy project_baseline_read on public.project_baseline_items for select to authenticated using(public.can_read_development_project(project_id));

-- Even trusted ordinary writes cannot overwrite or delete historical references.
create function public.preserve_project_baseline() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Baseline history is immutable' using errcode='23514';end if;
 if old.effective_to is not null or new.effective_to is null
 or (new.id,new.project_id,new.baseline_type,new.artifact_id,new.artifact_version_id,new.effective_from,new.set_by)
 is distinct from (old.id,old.project_id,old.baseline_type,old.artifact_id,old.artifact_version_id,old.effective_from,old.set_by)
 then raise exception 'Baseline history is immutable' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_project_baseline() from public,anon,authenticated,service_role;
create trigger preserve_project_baseline before update or delete on public.project_baseline_items for each row execute function public.preserve_project_baseline();

alter table public.audit_events drop constraint audit_events_context_check;
alter table public.audit_events add constraint audit_events_context_check check (
 (event_type in ('TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED') and entity_type='team' and scope_type='team')
 or (event_type in ('REVISION_REQUESTED','ARTIFACT_APPROVED') and entity_type='submission' and scope_type='submission' and metadata='{}'::jsonb)
 or (event_type='ARTIFACT_REOPENED' and entity_type='artifact' and scope_type='artifact' and entity_id=scope_id and metadata='{}'::jsonb)
 or (event_type='BASELINE_UPDATED' and entity_type='project' and scope_type='project' and entity_id=scope_id and metadata='{}'::jsonb));
alter table public.audit_events add column project_target_id uuid generated always as (case when entity_type='project' then entity_id end) stored references public.development_projects(id) on update restrict on delete restrict;

-- Private exact-target predicate. Historical reviewer and CURRENT Primary Master
-- are deliberately separate identities. It grants no general content access.
create function public.baseline_approval_context(target_project uuid,target_artifact uuid,target_version uuid) returns uuid
language sql stable security definer set search_path='' as $$
 select s.id from public.submissions s
 join public.artifacts a on a.id=s.artifact_id and a.id=target_artifact and a.project_id=target_project
 join public.artifact_versions v on v.id=s.artifact_version_id and v.id=target_version and v.artifact_id=a.id
 join public.activity_instances i on i.id=s.activity_instance_id and i.project_id=a.project_id and i.workspace_id=a.workspace_id
 join public.development_projects p on p.id=a.project_id and p.primary_workspace_id=a.workspace_id and p.owner_team_id is not distinct from i.team_id
 join public.workspaces w on w.id=a.workspace_id
 join public.cohorts c on c.id=i.cohort_id
 where s.status='APPROVED' and v.status='CURRENT' and a.current_version_id=v.id
 and v.approved_by is not null and v.approved_at is not null and s.reviewer_user_id=v.approved_by
 and s.submitted_by<>v.approved_by
 and a.status='ACTIVE' and a.archived_at is null and p.status='active' and p.archived_at is null and w.status='active'
 and c.primary_master_id=public.current_platform_user_id() and public.has_active_role_in_cohort('MASTER',c.id)
 and (i.team_id is null or exists(select 1 from public.teams t where t.id=i.team_id and t.cohort_id=c.id and t.workspace_id=w.id and t.status in ('created','active')))
 and exists(select 1 from public.project_program_links l where l.project_id=p.id and l.cohort_id=c.id and l.program_id=c.program_id)
 and (select count(*) from public.review_actions r where r.submission_id=s.id and r.action_type='APPROVED')=1
 and exists(select 1 from public.review_actions r where r.submission_id=s.id and r.action_type='APPROVED' and r.reviewer_user_id=v.approved_by and r.created_at=v.approved_at and r.note is not distinct from v.approval_note)
 and (select count(*) from public.audit_events e where e.entity_type='submission' and e.entity_id=s.id and e.event_type='ARTIFACT_APPROVED')=1
 and exists(select 1 from public.audit_events e where e.entity_type='submission' and e.entity_id=s.id and e.event_type='ARTIFACT_APPROVED' and e.actor_user_id=v.approved_by and e.created_at=v.approved_at and e.metadata='{}'::jsonb)
 order by s.id limit 1;
$$;
revoke all on function public.baseline_approval_context(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function public.set_project_baseline_item(target_project uuid,baseline_type_input text,target_artifact uuid,target_version uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;sid uuid;i public.activity_instances;a public.artifacts;prior public.project_baseline_items;item public.project_baseline_items;kind text;stamp timestamptz;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 kind:=btrim(baseline_type_input);
 if kind is null or kind !~ '^[A-Z][A-Z0-9_]*$' then raise exception 'Invalid baseline type' using errcode='22023';end if;
 sid:=public.baseline_approval_context(target_project,target_artifact,target_version);
 if sid is null then raise exception 'Access denied' using errcode='42501';end if;
 select ai.* into i from public.activity_instances ai join public.submissions s on s.activity_instance_id=ai.id where s.id=sid;
 -- Match the established review lock order; archive/reassignment/revocation
 -- cannot commit between verification and mutation. No broad Project edit grant.
 perform 1 from public.cohorts where id=i.cohort_id for share;
 if i.team_id is not null then perform 1 from public.teams where id=i.team_id for share;end if;
 perform 1 from public.development_projects where id=target_project for share;
 perform 1 from public.workspaces where id=i.workspace_id for share;
 perform 1 from public.users where id=actor for share;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 perform 1 from public.activity_instances where id=i.id for share;
 select * into a from public.artifacts where id=target_artifact for update;
 perform 1 from public.artifact_versions where id=target_version for share;
 perform 1 from public.submissions where id=sid for share;
 if public.current_platform_user_id() is distinct from actor or public.baseline_approval_context(target_project,target_artifact,target_version) is distinct from sid
 then raise exception 'Access denied' using errcode='42501';end if;
 -- Different Artifacts may compete for the same composite baseline slot.
 -- Advisory locking handles the absent-row case; the unique index is the final
 -- guard. Never lock the old Artifact while holding a new Artifact lock.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target_project::text||':'||kind,0));
 if public.baseline_approval_context(target_project,target_artifact,target_version) is distinct from sid then raise exception 'Access denied' using errcode='42501';end if;
 select * into prior from public.project_baseline_items where project_id=target_project and baseline_type=kind and effective_to is null for update;
 if prior.id is not null and prior.artifact_id=target_artifact and prior.artifact_version_id=target_version then return to_jsonb(prior);end if;
 stamp:=clock_timestamp();
 if prior.id is not null then update public.project_baseline_items set effective_to=stamp where id=prior.id;end if;
 insert into public.project_baseline_items(project_id,baseline_type,artifact_id,artifact_version_id,effective_from,set_by)
 values(target_project,kind,target_artifact,target_version,stamp,actor) returning * into item;
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata,created_at)
 values(actor,'BASELINE_UPDATED','project',target_project,'project',target_project,'{}',stamp);
 return to_jsonb(item);
end $$;
revoke all on function public.set_project_baseline_item(uuid,text,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.set_project_baseline_item(uuid,text,uuid,uuid) to authenticated;
comment on function public.set_project_baseline_item(uuid,text,uuid,uuid) is 'Explicit exact approved-context baseline selection by current scoped Primary Master, independently of general Project editing. Fixed search_path and private predicate prevent content enumeration. No approval/reopen auto-update.';
commit;
