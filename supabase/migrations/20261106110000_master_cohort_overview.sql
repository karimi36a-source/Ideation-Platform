begin;
-- Operational projection only. Existing private-source RLS/grants are unchanged.
create function public.get_master_cohort_overview(target_cohort uuid) returns jsonb
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
    where p.status='active' and t.status in ('created','active') and s.status='REVISION_REQUESTED' and v.status='REVISION_REQUESTED'
     and not exists(with recursive successors as (
      select x.id from public.artifact_versions x where x.artifact_id=a.id and x.previous_version_id=v.id
      union select x.id from public.artifact_versions x join successors y on x.previous_version_id=y.id where x.artifact_id=a.id
     ) select 1 from successors x join public.submissions next on next.artifact_version_id=x.id and next.artifact_id=a.id);
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
revoke all on function public.get_master_cohort_overview(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_master_cohort_overview(uuid) to authenticated;
comment on function public.get_master_cohort_overview(uuid) is 'M15.19 read-only assigned-Cohort operational metadata. No source content, recipient authority, membership, state writes or changed source RLS. Pending action uses existing M8 reviewer predicate; availability uses existing M7 gate.';
commit;


