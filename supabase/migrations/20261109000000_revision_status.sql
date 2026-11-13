begin;
-- Shared canonical state derivation. Internal only: references never grant source access.
create function private.revision_state(target_submission uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with recursive base as (
  select s.*,a.artifact_type,r.id review_action_id,r.created_at requested_at,f.id feedback_id
  from public.submissions s join public.artifacts a on a.id=s.artifact_id
  join public.artifact_versions v on v.id=s.artifact_version_id and v.artifact_id=a.id and v.status='REVISION_REQUESTED'
  join public.review_actions r on r.submission_id=s.id and r.action_type='REQUESTED_REVISION' and r.reviewer_user_id=s.reviewer_user_id
  join public.feedback_items f on f.submission_id=s.id and f.feedback_type='REVISION_REQUEST' and f.target_entity_type='ARTIFACT'
   and f.target_entity_id=a.id and f.target_version_id=v.id and f.project_id=a.project_id and f.author_user_id=s.reviewer_user_id
  where s.id=target_submission and s.status='REVISION_REQUESTED'
 ), descendants as (
  select v.id,v.version_number,v.status from public.artifact_versions v join base b on v.artifact_id=b.artifact_id and v.previous_version_id=b.artifact_version_id
  union select v.id,v.version_number,v.status from public.artifact_versions v join descendants d on v.previous_version_id=d.id join base b on v.artifact_id=b.artifact_id
 )
 select jsonb_build_object('requestedAt',b.requested_at,'reviewActionId',b.review_action_id,'feedbackId',b.feedback_id,
  'hasSuccessor',exists(select 1 from descendants d join public.submissions s on s.artifact_version_id=d.id and s.artifact_id=b.artifact_id and s.activity_instance_id=b.activity_instance_id),
  'drafts',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'versionNumber',d.version_number) order by d.version_number,d.id) from descendants d where d.status='DRAFT'
   and (b.artifact_type<>'MIND_MAP' or not exists(select 1 from public.artifact_versions newer where newer.artifact_id=b.artifact_id and newer.version_number>d.version_number))),'[]'),
  'successors',coalesce((select jsonb_agg(jsonb_build_object('submissionId',s.id,'versionId',d.id,'versionNumber',d.version_number,'status',s.status) order by s.submitted_at,s.id)
   from descendants d join public.submissions s on s.artifact_version_id=d.id and s.artifact_id=b.artifact_id and s.activity_instance_id=b.activity_instance_id),'[]')) from base b;
$$;
create function private.revision_is_outstanding(target_submission uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((private.revision_state(target_submission)->>'hasSuccessor')='false',false);
$$;
revoke all on function private.revision_state(uuid),private.revision_is_outstanding(uuid) from public,anon,authenticated,service_role;
create function public.get_revision_status(target_cohort uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid;org uuid;result jsonb;
begin
 actor:=public.current_platform_user_id();if actor is null then raise exception 'Access denied' using errcode='42501';end if;
 if target_cohort is not null then
  select p.organization_id into org from public.cohorts c join public.programs p on p.id=c.program_id where c.id=target_cohort;
  if org is null or not (public.has_active_role_in_cohort('MASTER',target_cohort) or public.has_active_role_in_organization('ADMIN',org)) then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 with authorized as (
  select s.id,s.artifact_id,s.artifact_version_id,i.id activity_id,i.cohort_id,p.id project_id,p.name project_name,a.title,a.artifact_type,v.version_number,
   d.name activity_name,t.id team_id,t.name team_name,u.id owner_id,u.display_name
  from public.submissions s join public.artifacts a on a.id=s.artifact_id and a.status='ACTIVE' and a.archived_at is null
  join public.artifact_versions v on v.id=s.artifact_version_id and v.artifact_id=a.id and v.status='REVISION_REQUESTED'
  join public.activity_instances i on i.id=s.activity_instance_id and i.project_id=a.project_id and i.workspace_id=a.workspace_id and i.status<>'archived'
  join public.activity_definitions d on d.id=i.activity_definition_id
  join public.development_projects p on p.id=a.project_id and p.primary_workspace_id=a.workspace_id and p.owner_team_id is not distinct from i.team_id and p.status='active' and p.archived_at is null
  join public.workspaces w on w.id=a.workspace_id and w.status='active' and w.archived_at is null
  left join public.teams t on t.id=i.team_id and t.cohort_id=i.cohort_id and t.workspace_id=w.id and w.team_id=t.id and t.status in ('created','active') and t.archived_at is null
  left join public.users u on u.id=p.owner_user_id
  where s.status='REVISION_REQUESTED' and case when target_cohort is not null then
   i.cohort_id=target_cohort and public.can_review_submission(s.id)
   else public.can_read_development_project(p.id) and public.can_read_activity_instance(i.id) and (
    p.project_type='individual' and p.owner_user_id=actor and w.workspace_type='PERSONAL' and w.owner_user_id=actor and i.team_id is null
    or p.project_type='team' and t.id is not null and w.workspace_type='TEAM' and coalesce(public.get_team_workspace_access(w.id),'') in ('member','team_lead')) end
 ), projected as (
  select a.id,(state->>'requestedAt')::timestamptz requested_at,(state->>'hasSuccessor')::boolean has_successor,
   jsonb_build_object('submissionId',a.id,'cohortId',a.cohort_id,'artifact',jsonb_build_object('id',a.artifact_id,'title',a.title,'artifactType',a.artifact_type),
    'version',jsonb_build_object('id',a.artifact_version_id,'versionNumber',a.version_number),'status','REVISION_REQUESTED','requestedAt',state->>'requestedAt',
    'feedbackTarget',jsonb_build_object('feedbackId',state->>'feedbackId','reviewActionId',state->>'reviewActionId'),
    'activity',jsonb_build_object('id',a.activity_id,'name',a.activity_name),'project',jsonb_build_object('id',a.project_id,'name',a.project_name),
    'teamOrStudent',case when a.team_id is not null then jsonb_build_object('type','TEAM','id',a.team_id,'name',a.team_name) else jsonb_build_object('type','USER','id',a.owner_id,'name',coalesce(a.display_name,'Student')) end,
    'hasSuccessor',(state->>'hasSuccessor')::boolean,
    'drafts',case when target_cohort is null then state->'drafts' else '[]'::jsonb end,
    'successors',case when target_cohort is null then state->'successors' else coalesce((select jsonb_agg(x) from jsonb_array_elements(state->'successors') x where public.can_review_submission((x->>'submissionId')::uuid)),'[]') end) item
  from authorized a cross join lateral (select private.revision_state(a.id) as state) derived where state is not null
 )
 select jsonb_build_object('outstanding',coalesce(jsonb_agg(item order by requested_at,id) filter(where not has_successor),'[]'),
  'history',coalesce(jsonb_agg(item order by requested_at,id) filter(where has_successor),'[]')) into result from projected;
 return result;
end $$;
revoke all on function public.get_revision_status(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_revision_status(uuid) to authenticated;
commit;


begin;
create or replace function public.get_master_cohort_overview(target_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid;c public.cohorts;org uuid;t record;p record;d record;av jsonb;inst jsonb;
 teams jsonb:='[]';projects jsonb;activities jsonb;pending jsonb;revision jsonb;approved jsonb;stamp timestamptz;
begin
 actor:=public.current_platform_user_id();
 if actor is null then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.cohorts where id=target_cohort;
 select organization_id into org from public.programs where id=c.program_id;
 -- Same exact scope predicates as the canonical Cohort read/management policy.
 if c.id is null or not (public.has_active_role_in_cohort('MASTER',c.id)
  or public.has_active_role_in_organization('ADMIN',org)) then
  raise exception 'Access denied' using errcode='42501';
 end if;
 for t in select x.id,x.name,x.workspace_id,x.status from public.teams x
  join public.workspaces w on w.id=x.workspace_id and w.team_id=x.id and w.workspace_type='TEAM' and w.cohort_id=c.id
  where c.status in ('planned','active','completed') and x.cohort_id=c.id and x.status in ('created','active','completed') and x.archived_at is null
   and w.status='active' and w.archived_at is null order by x.id
 loop
  projects:='[]';
  for p in select x.id,x.name,x.status from public.development_projects x
   where x.owner_team_id=t.id and x.owner_user_id is null and x.project_type='team'
    and x.primary_workspace_id=t.workspace_id and x.archived_at is null and x.status in ('active','completed')
    and exists(select 1 from public.project_program_links l where l.project_id=x.id and l.cohort_id=c.id and l.program_id=c.program_id)
   order by x.id
  loop
   activities:='[]';
   for d in select a.id,a.name,a.sequence,s.id session_id,s.title,s.session_number,s.sequence session_sequence
    from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id
    join public.curriculum_versions cv on cv.id=s.curriculum_version_id and cv.program_id=c.program_id and cv.status='approved'
    where s.curriculum_version_id=c.curriculum_version_id and s.status='active' and a.status='active' and a.workspace_mode='Team Workspace'
    order by s.sequence,a.sequence
   loop
    av:=public.resolve_activity_availability(d.id,p.id,t.workspace_id,t.id);
    select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'status',i.status) order by i.created_at,i.id),'[]') into inst
     from public.activity_instances i where i.activity_definition_id=d.id and i.project_id=p.id and i.workspace_id=t.workspace_id and i.team_id=t.id and i.cohort_id=c.id and i.status<>'archived';
    if inst<>'[]'::jsonb or (p.status='active' and t.status='active' and av->>'available'='true') then
     activities:=activities||jsonb_build_array(jsonb_build_object('definition',jsonb_build_object('id',d.id,'name',d.name,'sequence',d.sequence),
      'session',jsonb_build_object('id',d.session_id,'title',d.title,'sessionNumber',d.session_number,'sequence',d.session_sequence),
      'instances',inst,'availableToStart',p.status='active' and t.status='active' and av->>'available'='true'));
    end if;
   end loop;
   -- Scope joins are repeated deliberately at each independent endpoint. No link is an ACL.
   select coalesce(jsonb_agg(jsonb_build_object('submissionId',s.id,'artifactId',a.id,'versionId',v.id,'versionNumber',v.version_number,'status',s.status) order by s.submitted_at,s.id),'[]') into pending
    from public.submissions s join public.artifacts a on a.id=s.artifact_id and a.project_id=p.id and a.workspace_id=t.workspace_id and a.archived_at is null
    join public.artifact_versions v on v.id=s.artifact_version_id and v.artifact_id=a.id
    join public.activity_instances i on i.id=s.activity_instance_id and i.project_id=p.id and i.workspace_id=t.workspace_id and i.team_id=t.id and i.cohort_id=c.id and i.status<>'archived'
    where s.status in ('SUBMITTED','UNDER_REVIEW') and public.can_review_submission(s.id);
   select coalesce(jsonb_agg(jsonb_build_object('submissionId',s.id,'artifactId',a.id,'versionId',v.id,'versionNumber',v.version_number,'status',s.status) order by s.submitted_at,s.id),'[]') into revision
    from public.submissions s join public.artifacts a on a.id=s.artifact_id and a.project_id=p.id and a.workspace_id=t.workspace_id and a.archived_at is null
    join public.artifact_versions v on v.id=s.artifact_version_id and v.artifact_id=a.id
    join public.activity_instances i on i.id=s.activity_instance_id and i.project_id=p.id and i.workspace_id=t.workspace_id and i.team_id=t.id and i.cohort_id=c.id and i.status<>'archived'
    where p.status='active' and t.status in ('created','active') and public.can_review_submission(s.id) and private.revision_is_outstanding(s.id);
   select coalesce(jsonb_agg(jsonb_build_object('artifactId',a.id,'artifactType',a.artifact_type,'versionId',v.id,'versionNumber',v.version_number,'status',v.status) order by a.id),'[]') into approved
    from public.artifacts a join public.artifact_versions v on v.id=a.current_version_id and v.artifact_id=a.id
    where a.project_id=p.id and a.workspace_id=t.workspace_id and a.archived_at is null and a.status='ACTIVE'
     and v.status in ('APPROVED','CURRENT') and v.approved_at is not null;
   select max(x.ts) into stamp from (
    select i.updated_at ts from public.activity_instances i where i.project_id=p.id and i.workspace_id=t.workspace_id and i.team_id=t.id and i.cohort_id=c.id and i.status<>'archived'
    union all select s.submitted_at from public.submissions s join public.artifacts a on a.id=s.artifact_id and a.project_id=p.id and a.workspace_id=t.workspace_id
     join public.activity_instances i on i.id=s.activity_instance_id and i.cohort_id=c.id and i.team_id=t.id and i.project_id=p.id and i.workspace_id=t.workspace_id
    union all select r.created_at from public.review_actions r join public.submissions s on s.id=r.submission_id
     join public.artifacts a on a.id=s.artifact_id and a.project_id=p.id and a.workspace_id=t.workspace_id
     join public.activity_instances i on i.id=s.activity_instance_id and i.cohort_id=c.id and i.team_id=t.id and i.project_id=p.id and i.workspace_id=t.workspace_id
    union all select v.approved_at from public.artifact_versions v join public.artifacts a on a.id=v.artifact_id where a.project_id=p.id and a.workspace_id=t.workspace_id and v.approved_at is not null
   ) x;
   projects:=projects||jsonb_build_array(jsonb_build_object('project',jsonb_build_object('id',p.id,'name',p.name,'status',p.status),
    'activities',activities,'pendingReview',jsonb_build_object('count',jsonb_array_length(pending),'targets',pending),
    'revisionRequested',jsonb_build_object('pending',jsonb_array_length(revision)>0,'targets',revision),
    'approvedOutputs',approved,'lastMeaningfulWorkflowUpdateAt',stamp));
  end loop;
  teams:=teams||jsonb_build_array(jsonb_build_object('team',jsonb_build_object('id',t.id,'name',t.name,'status',t.status),
   'activeMemberCount',(select count(*) from public.team_memberships m join public.users u on u.id=m.user_id and u.account_status='active'
    where m.team_id=t.id and m.status='active' and m.left_at is null and m.joined_at<=statement_timestamp()),
   'projects',projects));
 end loop;
 return jsonb_build_object('cohort',jsonb_build_object('id',c.id,'name',c.name,'status',c.status),'teams',teams);
end $$;

commit;

