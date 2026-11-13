begin;
create function public.activity_execution_context(target_definition uuid,target_project uuid,target_workspace uuid,target_team uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
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
 return jsonb_build_object('available',true,'cohort',c.id);
end $$;
revoke all on function public.activity_execution_context(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;

-- Private evaluator consumes only context validated by the common identity-bound preflight.
-- No runtime IDs or timestamps are returned. Completion never implies approval.
create function public.activity_dependencies_in_context(target_definition uuid,target_project uuid,target_workspace uuid,target_team uuid,target_cohort uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare d record;ok boolean;missing jsonb:='[]';optional jsonb:='[]';requirement jsonb;
begin
 for d in select * from public.activity_dependencies where activity_definition_id=target_definition order by id loop
  ok:=false;
  case d.dependency_type::text
   when 'completion' then
    select exists(select 1 from public.activity_instances i where i.activity_definition_id=d.required_activity_definition_id
     and i.project_id=target_project and i.workspace_id=target_workspace and i.team_id is not distinct from target_team
     and i.cohort_id=target_cohort and i.status='completed' and i.completed_at is not null
     and public.can_read_activity_instance(i.id)) into ok;
   when 'approved_output' then ok:=false; -- M8 formal approval.
   when 'artifact_available' then ok:=false; -- M8 canonical Artifacts.
   when 'gate_passed' then ok:=false; -- Gate owning milestone.
   else ok:=false;
  end case;
  if not ok then
   requirement:=jsonb_build_object('dependencyId',d.id,'requiredActivityDefinitionId',d.required_activity_definition_id);
   if d.is_mandatory then missing:=missing||jsonb_build_array(requirement);else optional:=optional||jsonb_build_array(requirement);end if;
  end if;
 end loop;
 if jsonb_array_length(missing)>0 then return jsonb_build_object('satisfied',false,'blockingReason','DEPENDENCY_NOT_MET','missingRequiredDependencies',missing,'optionalUnsatisfiedDependencies',optional);end if;
 return jsonb_build_object('satisfied',true,'missingRequiredDependencies',missing,'optionalUnsatisfiedDependencies',optional);
end $$;
revoke all on function public.activity_dependencies_in_context(uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;

-- SECURITY DEFINER is restricted to authenticated callers and gated before reading
-- restricted curriculum/runtime facts. Private routines are not client callable.
create function public.evaluate_activity_dependencies(target_definition uuid,target_project uuid,target_workspace uuid,target_team uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare ctx jsonb;
begin
 ctx:=public.activity_execution_context(target_definition,target_project,target_workspace,target_team);
 if ctx->>'available'<>'true' then return jsonb_build_object('satisfied',false,'blockingReason',ctx->>'reasonCode','missingRequiredDependencies','[]'::jsonb,'optionalUnsatisfiedDependencies','[]'::jsonb);end if;
 return public.activity_dependencies_in_context(target_definition,target_project,target_workspace,target_team,(ctx->>'cohort')::uuid);
end $$;
revoke all on function public.evaluate_activity_dependencies(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.evaluate_activity_dependencies(uuid,uuid,uuid,uuid) to authenticated;

create or replace function public.resolve_activity_availability(target_definition uuid,target_project uuid,target_workspace uuid,target_team uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare ctx jsonb;deps jsonb;duplicate_id uuid;
begin
 ctx:=public.activity_execution_context(target_definition,target_project,target_workspace,target_team);
 if ctx->>'available'<>'true' then return ctx;end if;
 deps:=public.activity_dependencies_in_context(target_definition,target_project,target_workspace,target_team,(ctx->>'cohort')::uuid);
 if deps->>'satisfied'<>'true' then return '{"available":false,"reasonCode":"DEPENDENCY_NOT_MET"}'::jsonb;end if;
 select i.id into duplicate_id from public.activity_instances i
 where i.activity_definition_id=target_definition and i.project_id=target_project and i.workspace_id=target_workspace and i.team_id is not distinct from target_team
 and i.status in ('not_started','active','submitted','under_review','revision_requested') order by i.created_at,i.id limit 1;
 if duplicate_id is not null then
  if not public.can_read_activity_instance(duplicate_id) then return '{"available":false,"reasonCode":"INVALID_CONTEXT"}'::jsonb;end if;
  return jsonb_build_object('available',false,'reasonCode','ACTIVE_INSTANCE_EXISTS','existingActiveInstanceId',duplicate_id);
 end if;
 return '{"available":true}'::jsonb;
end $$;
comment on function public.resolve_activity_availability(uuid,uuid,uuid,uuid) is 'Read-only identity-bound availability with centralized canonical dependency evaluation. No launch/state mutation.';
drop function public.activity_required_dependency_blocked(uuid);

commit;
