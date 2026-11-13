begin;
create unique index artifact_versions_one_current on public.artifact_versions(artifact_id) where status='CURRENT';
alter table public.audit_events drop constraint audit_events_context_check;
alter table public.audit_events add constraint audit_events_context_check check (
 (event_type in ('TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED') and entity_type='team' and scope_type='team')
 or (event_type in ('REVISION_REQUESTED','ARTIFACT_APPROVED') and entity_type='submission' and scope_type='submission' and metadata='{}'::jsonb));
-- Private authorization is independent of workflow status so exact approval
-- retries can revalidate current authority without broadening read policies.
create function public.has_current_submission_reviewer(target_submission uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.submissions s
 join public.artifacts a on a.id=s.artifact_id
 join public.artifact_versions v on v.id=s.artifact_version_id and v.artifact_id=a.id
 join public.activity_instances i on i.id=s.activity_instance_id and i.project_id=a.project_id and i.workspace_id=a.workspace_id
 join public.development_projects p on p.id=a.project_id and p.primary_workspace_id=a.workspace_id and p.owner_team_id is not distinct from i.team_id
 join public.workspaces w on w.id=a.workspace_id
 join public.cohorts c on c.id=i.cohort_id
 where s.reviewer_user_id=public.current_platform_user_id() and c.primary_master_id=s.reviewer_user_id
 and s.id=target_submission
 and p.status='active' and p.archived_at is null and w.status='active'
 and (i.team_id is null or exists(select 1 from public.teams t where t.id=i.team_id and t.cohort_id=c.id and t.workspace_id=w.id and t.status in ('created','active')))
 and exists(select 1 from public.project_program_links l where l.project_id=p.id and l.cohort_id=c.id and l.program_id=c.program_id)
 and public.has_active_role_in_cohort('MASTER',c.id));
$$;
revoke all on function public.has_current_submission_reviewer(uuid) from public,anon,authenticated,service_role;
create or replace function public.can_review_submission(target_submission uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.has_current_submission_reviewer(target_submission) and exists(select 1 from public.submissions where id=target_submission and status in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED'));
$$;
create or replace function public.lock_review_submission(target_submission uuid) returns public.submissions language plpgsql security definer set search_path='' as $$
declare actor uuid;s public.submissions;a public.artifacts;i public.activity_instances;p public.development_projects;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 raise exception 'Access denied' using errcode='42501';end if;
 if not public.has_current_submission_reviewer(target_submission) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.submissions where id=target_submission;
 select * into i from public.activity_instances where id=s.activity_instance_id;
 select * into a from public.artifacts where id=s.artifact_id;
 select * into p from public.development_projects where id=a.project_id;
 perform 1 from public.cohorts where id=i.cohort_id for share;
 if p.owner_team_id is not null then perform 1 from public.teams where id=p.owner_team_id for share;end if;
 perform 1 from public.development_projects where id=p.id for share;
 perform 1 from public.workspaces where id=a.workspace_id for share;
 perform 1 from public.users where id=actor for share;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 perform 1 from public.activity_instances where id=i.id for share;
 select * into a from public.artifacts where id=s.artifact_id for update;
 perform 1 from public.artifact_versions where id=s.artifact_version_id for update;
 select * into s from public.submissions where id=target_submission for update;
 if public.current_platform_user_id() is distinct from actor or not public.has_current_submission_reviewer(s.id) or a.status<>'ACTIVE' or a.archived_at is not null then raise exception 'Access denied' using errcode='42501';end if;
 return s;
end $$;

-- Submitted body remains frozen; allow only the new canonical approval metadata
-- transition for the currently assigned reviewer. Direct clients have no UPDATE.
create or replace function public.freeze_submitted_version() returns trigger language plpgsql set search_path='' as $$
begin
 if old.status in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED') then
 if (new.content_snapshot,new.version_label,new.change_summary,new.previous_version_id,new.created_by,new.created_at)
 is distinct from (old.content_snapshot,old.version_label,old.change_summary,old.previous_version_id,old.created_by,old.created_at)
 then raise exception 'Submitted snapshot is immutable' using errcode='23514';end if;
 if (new.approved_by,new.approved_at,new.approval_note) is distinct from (old.approved_by,old.approved_at,old.approval_note) and not coalesce((
 old.status='UNDER_REVIEW' and new.status='CURRENT' and old.approved_by is null and old.approved_at is null and old.approval_note is null
 and new.approved_by=auth.uid() and new.approved_at is not null
 and exists(select 1 from public.submissions s where s.artifact_version_id=old.id and s.status='UNDER_REVIEW' and s.submitted_by<>auth.uid() and public.has_current_submission_reviewer(s.id))),false)
 then raise exception 'Approval metadata is controlled' using errcode='23514';end if;
 if new.status='DRAFT' then raise exception 'Submitted Version cannot reopen' using errcode='23514';end if;
 end if;
 return new;
end $$;
create function public.approve_artifact(target_submission uuid,approval_note_input text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.submissions;a public.artifacts;v public.artifact_versions;prior public.artifact_versions;body text;stamp timestamptz;begin
 s:=public.lock_review_submission(target_submission);
 if s.submitted_by=auth.uid() then raise exception 'Access denied' using errcode='42501';end if;
 body:=regexp_replace(approval_note_input,'^\s+|\s+$','','g');
 if body is not null and length(body)=0 then raise exception 'Invalid approval note' using errcode='22023';end if;
 select * into a from public.artifacts where id=s.artifact_id;
 select * into v from public.artifact_versions where id=s.artifact_version_id;
 if s.status='APPROVED' and v.status='CURRENT' and a.current_version_id=v.id then
 if v.approved_by is distinct from auth.uid() or v.approved_at is null or v.approval_note is distinct from body
 or (select count(*) from public.review_actions where submission_id=s.id and action_type='APPROVED')<>1
 or (select count(*) from public.audit_events where entity_type='submission' and entity_id=s.id and event_type='ARTIFACT_APPROVED')<>1
 or not exists(select 1 from public.review_actions where submission_id=s.id and action_type='APPROVED' and reviewer_user_id=auth.uid() and note is not distinct from body and created_at=v.approved_at)
 or not exists(select 1 from public.audit_events where entity_type='submission' and entity_id=s.id and event_type='ARTIFACT_APPROVED' and actor_user_id=auth.uid() and created_at=v.approved_at and metadata='{}'::jsonb)
 then raise exception 'Approval state conflict' using errcode='22023';end if;
 return to_jsonb(s);
 end if;
 if s.status<>'UNDER_REVIEW' or v.status<>'UNDER_REVIEW' or v.artifact_id<>a.id
 or v.approved_by is not null or v.approved_at is not null or v.approval_note is not null
 or exists(select 1 from public.review_actions where submission_id=s.id and action_type in ('APPROVED','REQUESTED_REVISION'))
 or exists(select 1 from public.audit_events where entity_type='submission' and entity_id=s.id and event_type in ('ARTIFACT_APPROVED','REVISION_REQUESTED'))
 then raise exception 'Approval state conflict' using errcode='22023';end if;
 if a.current_version_id is not null then
 select * into prior from public.artifact_versions where id=a.current_version_id for update;
 if prior.id is null or prior.id=v.id or prior.artifact_id<>a.id or prior.status<>'CURRENT' then raise exception 'Invalid current pointer' using errcode='22023';end if;
 elsif exists(select 1 from public.artifact_versions where artifact_id=a.id and status='CURRENT') then raise exception 'Invalid current pointer' using errcode='22023';end if;
 stamp:=clock_timestamp();
 if prior.id is not null then update public.artifact_versions set status='SUPERSEDED' where id=prior.id;end if;
 update public.artifact_versions set status='CURRENT',approved_by=auth.uid(),approved_at=stamp,approval_note=body where id=v.id;
 update public.artifacts set current_version_id=v.id where id=a.id;
 update public.submissions set status='APPROVED' where id=s.id returning * into s;
 insert into public.review_actions(submission_id,reviewer_user_id,action_type,note,created_at) values(s.id,auth.uid(),'APPROVED',body,stamp);
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata,created_at)
 values(auth.uid(),'ARTIFACT_APPROVED','submission',s.id,'submission',s.id,'{}',stamp);
 return to_jsonb(s);
end $$;
revoke all on function public.approve_artifact(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.approve_artifact(uuid,text) to authenticated;
comment on function public.approve_artifact(uuid,text) is 'Exact current assigned reviewer approval; shared scope/Artifact/Version/Submission locks serialize approval and revision. CURRENT pointer, supersession, metadata, action and minimal audit commit atomically. No baseline/Activity/Feedback mutation.';
commit;
