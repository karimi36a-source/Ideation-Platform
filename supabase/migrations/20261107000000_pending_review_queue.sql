begin;
-- Read-only projection of existing M8 reviewer authority; no queue state or new source grants.
create function public.get_pending_review_queue(target_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid;c public.cohorts;org uuid;items jsonb;
begin
 actor:=public.current_platform_user_id();
 if actor is null then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.cohorts where id=target_cohort;
 select organization_id into org from public.programs where id=c.program_id;
 -- Existing canonical Cohort read scope; Admin scope alone never passes M8 reviewer authority.
 if c.id is null or not (public.has_active_role_in_cohort('MASTER',c.id)
  or public.has_active_role_in_organization('ADMIN',org)) then
  raise exception 'Access denied' using errcode='42501';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'submissionId',s.id,'cohortId',c.id,'submittedAt',s.submitted_at,'reviewState',s.status,
  'teamOrStudent',case when t.id is not null then jsonb_build_object('type','TEAM','id',t.id,'name',t.name)
   else jsonb_build_object('type','USER','id',u.id,'name',coalesce(u.display_name,'Student')) end,
  'artifact',jsonb_build_object('id',a.id,'title',a.title,'artifactType',a.artifact_type),
  'version',jsonb_build_object('id',v.id,'versionNumber',v.version_number),
  'activity',jsonb_build_object('id',i.id,'definitionId',d.id,'name',d.name),
  'project',jsonb_build_object('id',p.id,'name',p.name)
 ) order by s.submitted_at,s.id),'[]') into items
 from public.submissions s
 join public.artifacts a on a.id=s.artifact_id and a.status='ACTIVE' and a.archived_at is null
 join public.artifact_versions v on v.id=s.artifact_version_id and v.artifact_id=a.id and v.status::text=s.status::text
 join public.activity_instances i on i.id=s.activity_instance_id and i.cohort_id=c.id and i.project_id=a.project_id and i.workspace_id=a.workspace_id and i.status<>'archived'
 join public.activity_definitions d on d.id=i.activity_definition_id
 join public.development_projects p on p.id=a.project_id and p.primary_workspace_id=a.workspace_id and p.owner_team_id is not distinct from i.team_id
 join public.workspaces w on w.id=a.workspace_id
 left join public.teams t on t.id=i.team_id and t.cohort_id=c.id and t.workspace_id=w.id and w.team_id=t.id and w.workspace_type='TEAM' and t.archived_at is null
 left join public.users u on u.id=p.owner_user_id
 where s.reviewer_user_id=actor and s.status in ('SUBMITTED','UNDER_REVIEW')
  and public.can_review_submission(s.id)
  and ((i.team_id is not null and t.id is not null) or (i.team_id is null and u.id is not null));
 return jsonb_build_object('items',items);
end $$;
revoke all on function public.get_pending_review_queue(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_pending_review_queue(uuid) to authenticated;
comment on function public.get_pending_review_queue(uuid) is 'M15.21 actionable exact M8 submissions only. Immutable assigned reviewer AND current canonical authority required. Orphaned reviews are excluded, never transferred or mutated. Oldest submitted first then UUID. No bodies, private Workspace data or duplicate queue state.';
commit;
