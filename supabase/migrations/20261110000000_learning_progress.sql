begin;
-- Counts only. Reuse the exact M15.17 self-scope gate, without changing source RLS
-- or revealing locked curriculum labels/configuration/private execution bodies.
create function public.get_my_learning_progress(target_project uuid,target_workspace uuid,target_cohort uuid,target_team uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare catalog jsonb;d record;required0 boolean;state0 text;required_total integer:=0;
 completed0 integer:=0;progress0 integer:=0;blocked0 integer:=0;not_started0 integer:=0;
 optional_total integer:=0;optional_completed integer:=0;cfg jsonb;
begin
 catalog:=public.get_my_current_work_catalog(target_project,target_workspace,target_cohort,target_team);
 if catalog is null then return null;end if;
 for d in select a.id,a.configuration from public.activity_definitions a
  join public.session_definitions s on s.id=a.session_definition_id
  where s.curriculum_version_id=(catalog->'curriculum'->>'id')::uuid
   and s.status='active' and a.status='active'
   and a.workspace_mode=case when target_team is null then 'Personal Workspace' else 'Team Workspace' end
 loop
  required0:=true;
  if d.configuration ? 'learning_progress' then
   cfg:=d.configuration->'learning_progress';
   if jsonb_typeof(cfg) is distinct from 'object' then raise exception 'Invalid learning progress configuration' using errcode='22023';end if;
   if exists(select 1 from jsonb_object_keys(cfg) k where k<>'required') then raise exception 'Invalid learning progress configuration' using errcode='22023';end if;
   if cfg ? 'required' then
    if jsonb_typeof(cfg->'required') is distinct from 'boolean' then raise exception 'Invalid learning progress configuration' using errcode='22023';end if;
    required0:=(cfg->>'required')::boolean;
   end if;
  end if;
  -- Definition, not instance, is the counting unit. Completion history wins;
  -- otherwise any live execution is in progress, never latest-by-time selection.
  if exists(select 1 from public.activity_instances i where i.activity_definition_id=d.id
   and i.project_id=target_project and i.workspace_id=target_workspace and i.cohort_id=target_cohort
   and i.team_id is not distinct from target_team and i.status='completed' and public.can_read_activity_instance(i.id)) then state0:='completed';
  elsif exists(select 1 from public.activity_instances i where i.activity_definition_id=d.id
   and i.project_id=target_project and i.workspace_id=target_workspace and i.cohort_id=target_cohort
   and i.team_id is not distinct from target_team and i.status in ('active','submitted','under_review','revision_requested') and public.can_read_activity_instance(i.id)) then state0:='in_progress';
  elsif public.activity_dependencies_in_context(d.id,target_project,target_workspace,target_team,target_cohort)->>'satisfied'='false' then state0:='blocked';
  else state0:='not_started';end if;
  if required0 then
   required_total:=required_total+1;
   case state0 when 'completed' then completed0:=completed0+1;
    when 'in_progress' then progress0:=progress0+1;
    when 'blocked' then blocked0:=blocked0+1;
    else not_started0:=not_started0+1;end case;
  else
   optional_total:=optional_total+1;
   if state0='completed' then optional_completed:=optional_completed+1;end if;
  end if;
 end loop;
 return jsonb_build_object('requiredActivitiesTotal',required_total,'completedRequiredActivities',completed0,
  'inProgressActivities',progress0,'blockedActivities',blocked0,'notStartedActivities',not_started0,
  'optionalActivities',jsonb_build_object('total',optional_total,'completed',optional_completed),
  'completionPercentage',case when required_total=0 then null else round(completed0::numeric*100/required_total,1) end);
end $$;
revoke all on function public.get_my_learning_progress(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_my_learning_progress(uuid,uuid,uuid,uuid) to authenticated;
comment on function public.get_my_learning_progress(uuid,uuid,uuid,uuid) is 'M15.24 self-scope counts only, same M15.17 authorization. Active applicable curriculum Definitions; required defaults true; completed history counted once; one decimal rounding. No source content, ranking or persisted progress.';
commit;
