begin;
-- One stable Bank identity, including archived history; applies to every write path.
create unique index artifacts_solution_bank_activity_unique on public.artifacts(activity_instance_id)
 where artifact_type='SOLUTION_BANK' and activity_instance_id is not null;
-- Minimal composition event in the existing immutable audit foundation.
alter table public.audit_events drop constraint audit_events_context_check;
alter table public.audit_events add constraint audit_events_context_check check (
 (event_type in ('TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED') and entity_type='team' and scope_type='team')
 or (event_type in ('REVISION_REQUESTED','ARTIFACT_APPROVED') and entity_type='submission' and scope_type='submission' and metadata='{}'::jsonb)
 or (event_type in ('ARTIFACT_REOPENED','PROBLEM_BANK_COMPOSED','SOLUTION_BANK_COMPOSED') and entity_type='artifact' and scope_type='artifact' and entity_id=scope_id and metadata='{}'::jsonb)
 or (event_type='BASELINE_UPDATED' and entity_type='project' and scope_type='project' and entity_id=scope_id and metadata='{}'::jsonb));
-- Definer only to compose protected rows atomically. Caller-bound M7/M8 locks
-- establish identity and current contribution; no supplied identity or service key.
create function public.compose_solution_bank(target_instance uuid,solution_ids uuid[],bank_title text default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;bank public.artifacts;v public.artifact_versions;o public.development_objects;
 result jsonb;solution_id uuid;position integer:=0;actor uuid;
begin
 a:=public.lock_activity_artifact_contribution(target_instance);
 if a.configuration_snapshot->>'method_type' is distinct from 'brainstorming'
 or not exists(select 1 from public.activity_definitions ad where ad.id=a.activity_definition_id and ad.method_type='brainstorming')
 then raise exception 'Invalid Activity method' using errcode='22023';end if;
 if not exists(select 1 from public.workspaces w where w.id=a.workspace_id and w.workspace_type in('PERSONAL','TEAM')) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if solution_ids is null or cardinality(solution_ids)=0 or array_ndims(solution_ids)<>1
 or array_position(solution_ids,null) is not null
 or (select count(distinct x) from unnest(solution_ids) x)<>cardinality(solution_ids)
 or (bank_title is not null and length(btrim(bank_title))=0)
 then raise exception 'Invalid input' using errcode='22023';end if;
 -- Serialize first creation and all subsequent compositions; recheck after waiting.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fici-solution-bank:'||a.id::text,913));
 a:=public.lock_activity_artifact_contribution(target_instance);
 actor:=public.current_platform_user_id();
 -- Lock canonical source rows in deterministic order; retain caller presentation order.
 for solution_id in select x from unnest(solution_ids) x order by x loop
  select * into o from public.development_objects where id=solution_id for share;
  if o.id is null or o.object_type<>'SOLUTION' or o.archived_at is not null
  or (o.project_id,o.workspace_id) is distinct from (a.project_id,a.workspace_id)
  or not public.can_read_development_project(o.project_id)
  or not exists(select 1 from public.activity_outputs ao where ao.activity_instance_id=a.id and ao.output_type='development_object' and ao.development_object_id=o.id)
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 end loop;
 select * into bank from public.artifacts where activity_instance_id=a.id and artifact_type='SOLUTION_BANK' for update;
 if bank.id is null then
  insert into public.artifacts(project_id,workspace_id,artifact_type,title,status,created_by,activity_instance_id,review_required,approval_required)
  values(a.project_id,a.workspace_id,'SOLUTION_BANK',btrim(coalesce(bank_title,'Solution Bank')),'ACTIVE',actor,a.id,
   (a.configuration_snapshot->>'requires_review')::boolean,(a.configuration_snapshot->>'requires_approval')::boolean) returning * into bank;
 else
  if bank.status<>'ACTIVE' or bank.archived_at is not null or (bank.project_id,bank.workspace_id) is distinct from(a.project_id,a.workspace_id)
  or bank.review_required is distinct from (a.configuration_snapshot->>'requires_review')::boolean
  or bank.approval_required is distinct from (a.configuration_snapshot->>'requires_approval')::boolean
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 result:=public.create_artifact_version(bank.id,jsonb_build_object('solution_count',cardinality(solution_ids)),null);
 select * into v from public.artifact_versions where id=(result->>'id')::uuid;
 foreach solution_id in array solution_ids loop
  position:=position+1;
  insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence,role_in_artifact)
  values(bank.id,v.id,solution_id,position,'solution');
 end loop;
 perform public.add_activity_artifact_output(a.id,bank.id);
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata)
 values(actor,'SOLUTION_BANK_COMPOSED','artifact',bank.id,'artifact',bank.id,'{}');
 return jsonb_build_object('artifact',to_jsonb(bank),'version',to_jsonb(v));
end $$;
revoke all on function public.compose_solution_bank(uuid,uuid[],text) from public,anon,authenticated,service_role;
grant execute on function public.compose_solution_bank(uuid,uuid[],text) to authenticated;
comment on function public.compose_solution_bank(uuid,uuid[],text) is 'M9.13 explicit ordered selection of exact Activity Problem outputs; stable Bank, next Draft per command, immutable prior Versions, minimal audit, current contribution only. No content deduplication, voting or sharing.';
commit;
