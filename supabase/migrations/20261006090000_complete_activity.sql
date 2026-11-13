begin;
-- Narrow elevated update because ordinary clients retain deny-write grants/RLS.
create function public.complete_activity(target_instance uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid;a public.activity_instances;checked_at timestamptz;rule0 jsonb;minimum_inputs numeric:=0;minimum_outputs numeric:=0;input_count bigint;output_count bigint;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';
 end if;
 if target_instance is null then raise exception 'Invalid input' using errcode='22023';end if;
 if current_setting('transaction_isolation')<>'read committed' then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Gate before locking or revealing lifecycle/duplicate information.
 if not public.can_read_activity_instance(target_instance) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fici-activity-complete:'||target_instance::text,710));
 select * into a from public.activity_instances where id=target_instance;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Reuse exact existing contribution authority; Mentor read access is insufficient.
 -- Validator locks parent and identity/membership state against revocation.
 -- Lock Cohort before profile/enrollment rows, matching canonical parent-first order.
 perform 1 from public.cohorts where id=a.cohort_id and status in ('planned','active') for share;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 perform 1 from public.project_program_links where project_id=a.project_id for share;
 select * into a from public.activity_instances where id=target_instance for update;
 if not public.can_read_activity_instance(a.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 checked_at:=pg_catalog.clock_timestamp();
 -- Statement-time helpers must not preserve authority that expired while waiting.
 if a.team_id is not null and not exists(select 1 from public.project_memberships m where m.project_id=a.project_id and m.user_id=actor and m.status='active' and m.starts_at<=checked_at and (m.ends_at is null or m.ends_at>checked_at)) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if not exists(select 1 from public.enrollments e where e.user_id=actor and e.cohort_id=a.cohort_id and e.status='active')
  and not exists(select 1 from public.role_assignments ra join public.roles role0 on role0.id=ra.role_id
   where ra.user_id=actor and role0.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.cohort_id=a.cohort_id and ra.team_id is null) or (ra.team_id=a.team_id and ra.cohort_id is null))) then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- M7 completion has only Personal and Team authority, like current start.
 if a.team_id is null then
  if not exists(select 1 from public.development_projects p join public.workspaces w on w.id=p.primary_workspace_id
   where p.id=a.project_id and p.project_type='individual' and p.owner_user_id=actor and w.workspace_type='PERSONAL' and w.owner_user_id=actor)
   or not exists(select 1 from public.enrollments e where e.user_id=actor and e.cohort_id=a.cohort_id and e.status='active') then raise exception 'Resource unavailable' using errcode='42501';end if;
 else
  if not exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id
    where m.team_id=a.team_id and m.user_id=actor and t.team_lead_user_id=actor and m.membership_role='team_lead'
    and m.status='active' and m.left_at is null and m.joined_at<=checked_at)
   and not exists(select 1 from public.role_assignments ra join public.roles rr on rr.id=ra.role_id
    where ra.user_id=actor and rr.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
    and ra.organization_id is null and ra.program_id is null and ra.project_id is null
    and ((ra.cohort_id=a.cohort_id and ra.team_id is null) or (ra.team_id=a.team_id and ra.cohort_id is null))) then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 -- Re-authorize retries, then preserve the original completion without side effects.
 if a.status='completed' then return to_jsonb(a);end if;
 if a.status<>'active' then raise exception 'Activity not writable' using errcode='55000';end if;
 -- Snapshot is historical execution truth. TEXT definitions are serialized JSON.
 rule0:=a.configuration_snapshot->'completion_rule';
 if jsonb_typeof(rule0)='string' then
  if btrim(rule0#>>'{}')='' then rule0:=null;
  else begin rule0:=(rule0#>>'{}')::jsonb;exception when invalid_text_representation or numeric_value_out_of_range or program_limit_exceeded then raise exception 'Completion rule unsupported' using errcode='P7010';end;end if;
 end if;
 if rule0 is not null and rule0<>'null'::jsonb and rule0<>'{}'::jsonb then
  if jsonb_typeof(rule0)<>'object' then raise exception 'Completion rule unsupported' using errcode='P7010';end if;
  if not (rule0 ?& array['min_required_inputs','min_outputs']) or exists(select 1 from jsonb_object_keys(rule0) k where k not in ('min_required_inputs','min_outputs'))
   or jsonb_typeof(rule0->'min_required_inputs')<>'number' or jsonb_typeof(rule0->'min_outputs')<>'number' then raise exception 'Completion rule unsupported' using errcode='P7010';end if;
  minimum_inputs:=(rule0->>'min_required_inputs')::numeric;minimum_outputs:=(rule0->>'min_outputs')::numeric;
  if minimum_inputs<0 or minimum_outputs<0 or minimum_inputs<>floor(minimum_inputs) or minimum_outputs<>floor(minimum_outputs) then raise exception 'Completion rule unsupported' using errcode='P7010';end if;
 end if;
 -- Activity UPDATE lock excludes new input/output registration (which holds SHARE).
 -- Count only exact, canonical, currently authorized Object references; never row presence alone.
 perform 1 from public.development_objects o where o.id in (
  select development_object_id from public.activity_inputs where activity_instance_id=a.id
  union select development_object_id from public.activity_outputs where activity_instance_id=a.id) order by o.id for share;
 select count(*) into input_count from public.activity_inputs i join public.development_objects o on o.id=i.development_object_id
  where i.activity_instance_id=a.id and i.input_type='development_object' and i.required
  and o.project_id=a.project_id and o.workspace_id=a.workspace_id and public.can_read_development_project(o.project_id)
  and i.artifact_id is null and i.artifact_version_id is null and i.evidence_id is null;
 select count(*) into output_count from public.activity_outputs i join public.development_objects o on o.id=i.development_object_id
  where i.activity_instance_id=a.id and i.output_type='development_object'
  and o.project_id=a.project_id and o.workspace_id=a.workspace_id and public.can_read_development_project(o.project_id)
  and i.artifact_id is null and i.decision_id is null and i.evidence_id is null;
 if input_count<minimum_inputs or output_count<minimum_outputs then raise exception 'Completion requirements not met' using errcode='P7011';end if;
 -- Timed authority cannot expire during Object locking either. Recheck at write time.
 checked_at:=clock_timestamp();
 if a.team_id is not null then
  if not exists(select 1 from public.project_memberships m where m.project_id=a.project_id and m.user_id=actor and m.status='active' and m.starts_at<=checked_at and (m.ends_at is null or m.ends_at>checked_at)) then raise exception 'Resource unavailable' using errcode='42501';end if;
  if not exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id where m.team_id=a.team_id and m.user_id=actor and t.team_lead_user_id=actor and m.membership_role='team_lead' and m.status='active' and m.left_at is null and m.joined_at<=checked_at)
   and not exists(select 1 from public.role_assignments ra join public.roles rr on rr.id=ra.role_id where ra.user_id=actor and rr.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at) and ra.organization_id is null and ra.program_id is null and ra.project_id is null and ((ra.cohort_id=a.cohort_id and ra.team_id is null) or (ra.team_id=a.team_id and ra.cohort_id is null))) then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 update public.activity_instances set status='completed',completed_at=checked_at,updated_at=checked_at where id=a.id returning * into a;
 return to_jsonb(a);
end $$;
revoke all on function public.complete_activity(uuid) from public,anon,authenticated,service_role;
grant execute on function public.complete_activity(uuid) to authenticated;
comment on function public.complete_activity(uuid) is 'M7.10 collective Activity completion only. Verified current owner/Lead/exact scoped Master, locked canonical context, snapshot V1 counts, READ COMMITTED, reauthorized idempotent retry. No participant, approval, Object, baseline or downstream writes.';
commit;
