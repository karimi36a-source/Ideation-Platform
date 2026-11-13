begin;
-- Temporary M7.4 branch: every mandatory dependency fails closed. No runtime semantics.
create function public.activity_required_dependency_blocked(target_definition uuid) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from public.activity_dependencies where activity_definition_id=target_definition and is_mandatory);
$$;
revoke all on function public.activity_required_dependency_blocked(uuid) from public,anon,authenticated,service_role;

-- Definer reads restricted definition/scope metadata without broadening table grants.
-- Only a scope-gated eligibility result is returned; no supplied identity, private
-- resource metadata, or side effects. STABLE enforces one read-only statement snapshot.
create function public.resolve_activity_availability(target_definition uuid,target_project uuid,target_workspace uuid,target_team uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;a public.activity_definitions;s public.session_definitions;v public.curriculum_versions;
 p public.development_projects;w public.workspaces;t public.teams;c public.cohorts;program public.programs;
 links integer;duplicate_id uuid;member_role text;master_authority boolean:=false;
 denied jsonb:='{"available":false,"reasonCode":"INVALID_CONTEXT"}'::jsonb;
begin
 if auth.uid() is null then return '{"available":false,"reasonCode":"UNAUTHENTICATED"}'::jsonb;end if;
 actor:=public.current_platform_user_id();if actor is null then return denied;end if;
 -- Load definition facts first, but do not expose specific failures before private context authorization.
 select * into a from public.activity_definitions where id=target_definition;
 select * into p from public.development_projects where id=target_project;
 if not found then return denied;end if;
 select * into w from public.workspaces where id=target_workspace;
 if not found or p.primary_workspace_id<>w.id then return denied;end if;
 if not public.can_read_development_project(p.id) then return denied;end if;
 if p.project_type='individual' then
  if p.owner_user_id is distinct from actor or w.owner_user_id is distinct from actor or w.workspace_type<>'PERSONAL' then return denied;end if;
 elsif p.project_type='team' then
  select * into t from public.teams where id=p.owner_team_id;
  if not found or t.workspace_id<>w.id or w.team_id is distinct from t.id or w.cohort_id is distinct from t.cohort_id
   or (target_team is not null and target_team<>t.id) then return denied;end if;
  member_role:=public.get_team_workspace_access(w.id);
  if member_role is null or member_role='mentor' then return denied;end if;
  master_authority:=public.has_active_role_in_cohort('MASTER',t.cohort_id) or public.has_active_role_in_team('MASTER',t.id);
  if not master_authority and (member_role<>'team_lead' or t.team_lead_user_id is distinct from actor) then return denied;end if;
 elsif p.project_type='instructor_case_study' then return '{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}'::jsonb;
 else return denied;
 end if;
 if a.id is null then return denied;end if;
 select * into s from public.session_definitions where id=a.session_definition_id;
 select * into v from public.curriculum_versions where id=s.curriculum_version_id;
 select * into program from public.programs where id=v.program_id;
 if s.id is null or v.id is null or program.id is null then return denied;end if;
 -- No inferred Cohort and no arbitrary choice among ambiguous open contexts.
 select count(*) into links from public.project_program_links l join public.cohorts c0 on c0.id=l.cohort_id
 where l.project_id=p.id and l.program_id=program.id and c0.program_id=program.id
 and c0.curriculum_version_id=v.id and l.completed_at is null
 and (p.project_type<>'team' or c0.id=t.cohort_id);
 if links<>1 then return denied;end if;
 select c0.* into c from public.project_program_links l join public.cohorts c0 on c0.id=l.cohort_id
 where l.project_id=p.id and l.program_id=program.id and c0.program_id=program.id
 and c0.curriculum_version_id=v.id and l.completed_at is null
 and (p.project_type<>'team' or c0.id=t.cohort_id);
 if not master_authority and not exists(select 1 from public.enrollments e where e.user_id=actor and e.cohort_id=c.id and e.status='active')
 then return '{"available":false,"reasonCode":"NOT_ENROLLED"}'::jsonb;end if;
 if a.status<>'active' or s.status<>'active' or v.status<>'approved' or program.status<>'active'
 then return '{"available":false,"reasonCode":"ACTIVITY_NOT_AVAILABLE"}'::jsonb;end if;
 if a.workspace_mode='Personal Workspace' then
  if p.project_type<>'individual' or w.workspace_type<>'PERSONAL' or target_team is not null then return '{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}'::jsonb;end if;
 elsif a.workspace_mode='Team Workspace' then
  if p.project_type<>'team' or w.workspace_type<>'TEAM' or target_team is null or target_team<>t.id then return '{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}'::jsonb;end if;
 else return '{"available":false,"reasonCode":"WORKSPACE_MODE_MISMATCH"}'::jsonb;
 end if;
 if p.status<>'active' or p.archived_at is not null or w.status<>'active' or w.archived_at is not null
  or c.status not in ('planned','active') or (p.project_type='team' and (t.status<>'active' or t.archived_at is not null))
 then return '{"available":false,"reasonCode":"LIFECYCLE_NOT_AVAILABLE"}'::jsonb;end if;
 if public.activity_required_dependency_blocked(a.id) then return '{"available":false,"reasonCode":"DEPENDENCY_NOT_MET"}'::jsonb;end if;
 select i.id into duplicate_id from public.activity_instances i
 where i.activity_definition_id=a.id and i.project_id=p.id and i.workspace_id=w.id and i.team_id is not distinct from target_team
 and i.status in ('not_started','active','submitted','under_review','revision_requested')
 order by i.created_at,i.id limit 1;
 if duplicate_id is not null then
  if not public.can_read_activity_instance(duplicate_id) then return denied;end if;
  return jsonb_build_object('available',false,'reasonCode','ACTIVE_INSTANCE_EXISTS','existingActiveInstanceId',duplicate_id);
 end if;
 return '{"available":true}'::jsonb;
end $$;
revoke all on function public.resolve_activity_availability(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.resolve_activity_availability(uuid,uuid,uuid,uuid) to authenticated;
comment on function public.resolve_activity_availability(uuid,uuid,uuid,uuid) is 'Read-only identity-bound M7.4 eligibility. Team Lead/exact Master launch authority still requires canonical Project/Workspace access. Mandatory dependencies fail closed; no repeatability, Case Study launch or state mutation.';
commit;

