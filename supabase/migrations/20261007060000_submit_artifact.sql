begin;
create type public.submission_status as enum ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED','APPROVED','REJECTED');
create table public.submissions (
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 artifact_id uuid not null references public.artifacts(id) on delete restrict,
 artifact_version_id uuid not null,
 submitted_by uuid not null references public.users(id) on delete restrict,
 submitted_at timestamptz not null default clock_timestamp(),
 status public.submission_status not null default 'SUBMITTED',
 reviewer_user_id uuid not null references public.users(id) on delete restrict,
 foreign key(artifact_version_id,artifact_id) references public.artifact_versions(id,artifact_id) on delete restrict,
 check(submitted_by<>reviewer_user_id)
);
create unique index submissions_active_version on public.submissions(artifact_version_id) where status in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED');
create index submissions_reviewer on public.submissions(reviewer_user_id);
create index submissions_artifact on public.submissions(artifact_id);
create function public.validate_submission_scope() returns trigger language plpgsql set search_path='' as $$
begin
 if not exists(select 1 from public.artifacts a join public.activity_instances i on i.id=new.activity_instance_id
 join public.development_projects p on p.id=a.project_id
 where a.id=new.artifact_id and i.project_id=a.project_id and i.workspace_id=a.workspace_id
 and i.team_id is not distinct from p.owner_team_id) then
 raise exception 'Invalid submission scope' using errcode='23514';end if;
 return new;
end $$;
create trigger submissions_validate_scope before insert or update on public.submissions for each row execute function public.validate_submission_scope();
-- Definer avoids recursive RLS; identity is always the current caller. These
-- predicates grant only committed exact targets, never Project/Workspace access.
create function public.can_review_submission(target_submission uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.submissions s
 join public.artifacts a on a.id=s.artifact_id
 join public.artifact_versions v on v.id=s.artifact_version_id and v.artifact_id=a.id
 join public.activity_instances i on i.id=s.activity_instance_id and i.project_id=a.project_id and i.workspace_id=a.workspace_id
 join public.development_projects p on p.id=a.project_id and p.primary_workspace_id=a.workspace_id and p.owner_team_id is not distinct from i.team_id
 join public.workspaces w on w.id=a.workspace_id
 join public.cohorts c on c.id=i.cohort_id
 where s.reviewer_user_id=public.current_platform_user_id() and c.primary_master_id=s.reviewer_user_id
 and s.id=target_submission and s.status in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED')
 and p.status='active' and p.archived_at is null and w.status='active'
 and (i.team_id is null or exists(select 1 from public.teams t where t.id=i.team_id and t.cohort_id=c.id and t.workspace_id=w.id and t.status in ('created','active')))
 and exists(select 1 from public.project_program_links l where l.project_id=p.id and l.cohort_id=c.id and l.program_id=c.program_id)
 and public.has_active_role_in_cohort('MASTER',c.id));
$$;
create function public.can_review_artifact_version(target_version uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.submissions s where s.artifact_version_id=target_version and public.can_review_submission(s.id));
$$;
create function public.can_review_linked_object(target_object uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.artifact_object_links l join public.development_objects o on o.id=l.development_object_id
 join public.artifacts a on a.id=l.artifact_id and a.project_id=o.project_id and a.workspace_id=o.workspace_id
 where l.development_object_id=target_object and public.can_review_artifact_version(l.artifact_version_id));
$$;
-- Metadata RPC avoids revealing an unrelated current pointer, creator-private
-- metadata or a whole Artifact history through a submitted target entitlement.
create function public.get_submitted_artifact_metadata(target_artifact uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',a.id,'artifactType',a.artifact_type,'title',a.title,'status',a.status,
 'projectId',a.project_id,'workspaceId',a.workspace_id,'activityInstanceId',a.activity_instance_id,
 'reviewRequired',a.review_required,'approvalRequired',a.approval_required)
 from public.artifacts a where a.id=target_artifact and exists(select 1 from public.submissions s where s.artifact_id=a.id and public.can_review_submission(s.id));
$$;
alter table public.submissions enable row level security;
revoke all on public.submissions from public,anon,authenticated,service_role;
grant select on public.submissions to authenticated;
create policy submissions_read on public.submissions for select to authenticated using(
 exists(select 1 from public.artifacts a where a.id=submissions.artifact_id) or public.can_review_submission(id));
create policy submissions_read_guard on public.submissions as restrictive for select to authenticated using(
 exists(select 1 from public.artifacts a where a.id=submissions.artifact_id) or public.can_review_submission(id));
-- Version baseline must remain Project-authorized, not inherit review access to
-- its sibling Artifact and accidentally expose every historical/future Version.
alter policy artifact_versions_parent_read on public.artifact_versions using(
 exists(select 1 from public.artifacts a where a.id=artifact_versions.artifact_id) or public.can_review_artifact_version(id));
alter policy artifact_versions_read_guard on public.artifact_versions using(
 exists(select 1 from public.artifacts a where a.id=artifact_versions.artifact_id) or public.can_review_artifact_version(id));
alter policy development_objects_read on public.development_objects using(
 (exists(select 1 from public.development_projects p where p.id=project_id and p.primary_workspace_id=workspace_id) and exists(select 1 from public.workspaces w where w.id=workspace_id)) or public.can_review_linked_object(id));
alter policy development_objects_read_guard on public.development_objects using(
 (exists(select 1 from public.development_projects p where p.id=project_id and p.primary_workspace_id=workspace_id) and exists(select 1 from public.workspaces w where w.id=workspace_id)) or public.can_review_linked_object(id));
-- Freeze submitted snapshots without introducing review transitions.
create function public.freeze_submitted_version() returns trigger language plpgsql set search_path='' as $$
begin
 if old.status in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED') and
 (new.content_snapshot,new.version_label,new.change_summary,new.previous_version_id,new.created_by,new.created_at,new.approved_by,new.approved_at,new.approval_note)
 is distinct from (old.content_snapshot,old.version_label,old.change_summary,old.previous_version_id,old.created_by,old.created_at,old.approved_by,old.approved_at,old.approval_note)
 then raise exception 'Submitted snapshot is immutable' using errcode='23514';end if;
 if old.status in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED') and new.status='DRAFT' then raise exception 'Submitted Version cannot reopen' using errcode='23514';end if;
 return new;
end $$;
create trigger artifact_versions_freeze_submitted before update on public.artifact_versions for each row execute function public.freeze_submitted_version();
create function public.submit_artifact(target_artifact uuid,target_version uuid,target_activity uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;a public.artifacts;v public.artifact_versions;i public.activity_instances;c public.cohorts;p public.development_projects;s public.submissions;reviewer uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 raise exception 'Access denied' using errcode='42501';end if;
 select * into a from public.artifacts where id=target_artifact;
 if a.id is null then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 select * into a from public.artifacts where id=target_artifact for update;
 select * into p from public.development_projects where id=a.project_id;
 if a.status<>'ACTIVE' or a.archived_at is not null then raise exception 'Access denied' using errcode='42501';end if;
 if p.project_type='team' then
 perform 1 from public.teams t join public.team_memberships m on m.team_id=t.id
 where t.id=p.owner_team_id and t.team_lead_user_id=actor and m.user_id=actor and m.status='active' and m.membership_role='team_lead' for share of t,m;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 elsif p.project_type<>'individual' or p.owner_user_id is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 select * into i from public.activity_instances where id=target_activity for share;
 if i.id is null or (i.project_id,i.workspace_id,i.team_id) is distinct from (a.project_id,a.workspace_id,p.owner_team_id)
 or i.status not in ('active','completed') or not public.can_read_activity_instance(i.id) then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.cohorts where id=i.cohort_id for share;
 reviewer:=c.primary_master_id;
 perform 1 from public.project_program_links l where l.project_id=p.id and l.cohort_id=c.id and l.program_id=c.program_id and l.completed_at is null for share;
 if not found or reviewer is null or reviewer=actor then raise exception 'Reviewer unavailable' using errcode='42501';end if;
 perform 1 from public.users u where u.id=reviewer and u.account_status='active' for share;
 if not found then raise exception 'Reviewer unavailable' using errcode='42501';end if;
 perform 1 from public.role_assignments r join public.roles code on code.id=r.role_id
 where r.user_id=reviewer and code.code='MASTER' and code.is_system_role and r.cohort_id=c.id
 and num_nonnulls(r.organization_id,r.program_id,r.cohort_id,r.team_id,r.project_id)=1
 and r.status='active' and r.starts_at<=statement_timestamp() and (r.ends_at is null or r.ends_at>statement_timestamp()) for share of r;
 if not found then raise exception 'Reviewer unavailable' using errcode='42501';end if;
 select * into v from public.artifact_versions where id=target_version and artifact_id=a.id for update;
 if v.id is null then raise exception 'Access denied' using errcode='42501';end if;
 if v.status<>'DRAFT' or exists(select 1 from public.submissions where artifact_version_id=v.id and status in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED')) then raise exception 'Submission state conflict' using errcode='23505';end if;
 if actor is distinct from public.current_platform_user_id() then raise exception 'Access denied' using errcode='42501';end if;
 update public.artifact_versions set status='SUBMITTED' where id=v.id;
 insert into public.submissions(activity_instance_id,artifact_id,artifact_version_id,submitted_by,reviewer_user_id)
 values(i.id,a.id,v.id,actor,reviewer) returning * into s;
 return to_jsonb(s);
end $$;
revoke all on function public.freeze_submitted_version() from public,anon,authenticated,service_role;
revoke all on function public.validate_submission_scope() from public,anon,authenticated,service_role;
revoke all on function public.can_review_submission(uuid),public.can_review_artifact_version(uuid),public.can_review_linked_object(uuid),public.get_submitted_artifact_metadata(uuid),public.submit_artifact(uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_review_submission(uuid),public.can_review_artifact_version(uuid),public.can_review_linked_object(uuid),public.get_submitted_artifact_metadata(uuid),public.submit_artifact(uuid,uuid,uuid) to authenticated;
comment on table public.submissions is 'M8.7 exact Version submission; current reviewer entitlement only. Audit deferred; notifications M15. No review mutations.';
commit;
