begin;
-- Canonical execution fields only. The instance's existing history trigger freezes
-- this snapshot once started; authorization and dependency results are not copied.
create function public.activity_start_snapshot(target_definition uuid) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('method_type',a.method_type,'workspace_mode',a.workspace_mode,
 'instructions',a.instructions,'ai_role_code',a.ai_role_code,'requires_review',a.requires_review,
 'requires_approval',a.requires_approval,'completion_rule',a.completion_rule,'configuration',a.configuration)
 from public.activity_definitions a where a.id=target_definition;
$$;
revoke all on function public.activity_start_snapshot(uuid) from public,anon,authenticated,service_role;

-- Elevated writes are needed because ordinary clients retain SELECT-only table
-- grants and deny-write RLS. Identity is auth.uid(), never a function argument.
create function public.start_activity(target_definition uuid,target_project uuid,target_workspace uuid,target_team uuid default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx jsonb;eligibility jsonb;actor uuid;started timestamptz;snapshot jsonb;created public.activity_instances;
begin
 ctx:=public.activity_execution_context(target_definition,target_project,target_workspace,target_team);
 if ctx->>'available'<>'true' then return (ctx-'available')||jsonb_build_object('started',false);end if;
 -- READ COMMITTED gives the eligibility SELECT a fresh snapshot after waiting
 -- for the preceding starter to commit. Refuse stale-snapshot isolation rather
 -- than allowing a duplicate. This is the default Supabase/PostgREST isolation.
 if current_setting('transaction_isolation')<>'read committed' then return '{"started":false,"reasonCode":"INVALID_CONTEXT"}'::jsonb;end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
  'fici-activity-start:'||target_definition::text||':'||target_project::text||':'||target_workspace::text||':'||coalesce(target_team::text,'null'),76));
 actor:=public.current_platform_user_id();
 -- Pin canonical state against concurrent scope/lifecycle revocation. Then
 -- re-evaluate centrally; the preliminary context check never authorizes writes.
 perform 1 from public.users where id=actor for share;
 perform 1 from public.development_projects where id=target_project for share;
 perform 1 from public.workspaces where id=target_workspace for share;
 perform 1 from public.teams where id=target_team for share;
 perform 1 from public.cohorts where id=(ctx->>'cohort')::uuid for share;
 perform 1 from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id
 join public.curriculum_versions v on v.id=s.curriculum_version_id join public.programs p on p.id=v.program_id
 where a.id=target_definition for share of a,s,v,p;
 perform 1 from public.enrollments where user_id=actor and cohort_id=(ctx->>'cohort')::uuid for share;
 perform 1 from public.team_memberships where user_id=actor and team_id=target_team for share;
 perform 1 from public.project_memberships where user_id=actor and project_id=target_project for share;
 perform 1 from public.role_assignments where user_id=actor for share;
 perform 1 from public.project_program_links where project_id=target_project for share;
 perform 1 from public.activity_dependencies where activity_definition_id=target_definition for share;
 perform 1 from public.activity_instances i join public.activity_dependencies d on d.required_activity_definition_id=i.activity_definition_id
 where d.activity_definition_id=target_definition and i.project_id=target_project and i.workspace_id=target_workspace
 and i.team_id is not distinct from target_team and i.cohort_id=(ctx->>'cohort')::uuid for share of i;
 eligibility:=public.resolve_activity_availability(target_definition,target_project,target_workspace,target_team);
 if eligibility->>'available'<>'true' then return (eligibility-'available')||jsonb_build_object('started',false);end if;
 ctx:=public.activity_execution_context(target_definition,target_project,target_workspace,target_team);
 if ctx->>'available'<>'true' then return (ctx-'available')||jsonb_build_object('started',false);end if;
 snapshot:=public.activity_start_snapshot(target_definition);
 if snapshot is null or jsonb_typeof(snapshot)<>'object' then raise exception 'Activity start failed' using errcode='22023';end if;
 started:=pg_catalog.clock_timestamp();
 -- Statement-time helpers remain authoritative for eligibility. A start may
 -- wait on its context lock, so also require timed authority to remain valid
 -- at the actual recorded start time; an expired assignment cannot survive a wait.
 if target_team is not null then
  if not exists(select 1 from public.project_memberships m where m.project_id=target_project and m.user_id=actor
   and m.status='active' and m.starts_at<=started and (m.ends_at is null or m.ends_at>started)) then
   return '{"started":false,"reasonCode":"INVALID_CONTEXT"}'::jsonb;
  end if;
  if not exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id
   where m.team_id=target_team and m.user_id=actor and t.team_lead_user_id=actor
   and m.membership_role='team_lead' and m.status='active' and m.left_at is null and m.joined_at<=started)
   and not exists(select 1 from public.role_assignments a join public.roles role0 on role0.id=a.role_id
   where a.user_id=actor and role0.code='MASTER' and a.status='active' and a.starts_at<=started and (a.ends_at is null or a.ends_at>started)
   and a.organization_id is null and a.program_id is null and a.project_id is null
   and ((a.cohort_id=(ctx->>'cohort')::uuid and a.team_id is null) or (a.team_id=target_team and a.cohort_id is null))) then
   return '{"started":false,"reasonCode":"INVALID_CONTEXT"}'::jsonb;
  end if;
 end if;
 insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,completed_at,status,configuration_snapshot)
 values(target_definition,(ctx->>'cohort')::uuid,target_project,target_workspace,target_team,actor,started,null,'active',snapshot) returning * into created;
 insert into public.activity_participants(activity_instance_id,user_id,participant_role,joined_at,completed_at)
 values(created.id,actor,'participant',started,null);
 return jsonb_build_object('started',true,'activity',to_jsonb(created));
end $$;
revoke all on function public.start_activity(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.start_activity(uuid,uuid,uuid,uuid) to authenticated;
comment on function public.start_activity(uuid,uuid,uuid,uuid) is 'M7.6 atomic identity-bound start. READ COMMITTED context lock and transactional availability/dependencies, immutable snapshot, exactly one initiating participant. No resume/bulk enrollment.';
commit;
