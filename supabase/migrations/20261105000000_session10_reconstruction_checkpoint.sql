begin;
create table public.session10_reconstruction_checkpoints(
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null references public.activity_instances(id),
 project_id uuid not null,workspace_id uuid not null,
 reconstruction_ai_output_id uuid not null references public.ai_outputs(id),
 baseline_item_id uuid not null references public.project_baseline_items(id),
 confirmed_by uuid not null references public.users(id),confirmed_at timestamptz not null default clock_timestamp(),
 foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id),
 unique(activity_instance_id,reconstruction_ai_output_id,confirmed_by)
);
alter table public.session10_reconstruction_checkpoints enable row level security;
revoke all on public.session10_reconstruction_checkpoints from public,anon,authenticated,service_role;
grant select on public.session10_reconstruction_checkpoints to authenticated;
create policy session10_checkpoint_read on public.session10_reconstruction_checkpoints for select to authenticated using(
 public.can_read_development_project(project_id)
 and public.can_read_activity_instance(activity_instance_id) and exists(select 1 from public.ai_outputs o where o.id=reconstruction_ai_output_id));
create policy session10_checkpoint_no_writes on public.session10_reconstruction_checkpoints as restrictive for all to authenticated using(true) with check(false);
create function private.preserve_session10_checkpoint() returns trigger language plpgsql set search_path='' as $$begin
 if tg_op<>'INSERT' then raise exception 'Checkpoint history is immutable' using errcode='55000';end if;
 if new.confirmed_by is distinct from public.current_platform_user_id() then raise exception 'Checkpoint unavailable' using errcode='42501';end if;
 new.confirmed_at:=clock_timestamp();return new;
end$$;
create trigger session10_checkpoint_history before insert or update or delete on public.session10_reconstruction_checkpoints for each row execute function private.preserve_session10_checkpoint();
create function private.require_session10_activity(aid uuid,pid uuid,wid uuid) returns void language plpgsql security definer set search_path='' as $$
declare s jsonb;begin
 perform public.require_development_object_write(pid,wid);
 s:=public.resolve_activity_ai_configuration(aid);
 if s is null or (s->>'project_id',s->>'workspace_id') is distinct from (pid::text,wid::text)
 or s->>'status' not in ('active','revision_requested') or s->>'definition_status'<>'active'
 or s->>'method_type'<>'comparison' or s->>'current_method'<>'comparison'
 or s->>'ai_role_code'<>'COMPARATIVE_CRITICAL_ANALYST' or s->>'current_role'<>'COMPARATIVE_CRITICAL_ANALYST'
 or s#>>'{configuration,ai,enabled}' is distinct from 'true' or s#>>'{current_ai,enabled}' is distinct from 'true'
 or not exists(select 1 from public.activity_instances a join public.activity_definitions d on d.id=a.activity_definition_id join public.session_definitions sd on sd.id=d.session_definition_id join public.curriculum_versions cv on cv.id=sd.curriculum_version_id join public.programs p on p.id=cv.program_id where a.id=aid and sd.session_number=10 and p.code='PROFESSIONAL_COURSE')
 then raise exception 'Session 10 unavailable' using errcode='42501';end if;
end$$;
create function public.validate_session10_reconstruction_scope(target_activity uuid,target_project uuid,target_workspace uuid) returns boolean language plpgsql security definer set search_path='' as $$begin
 perform private.require_session10_activity(target_activity,target_project,target_workspace);return true;
end$$;
create function public.confirm_session10_reconstruction(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();o public.ai_outputs;b public.project_baseline_items;c public.session10_reconstruction_checkpoints;
begin
 if jsonb_typeof(input) is distinct from 'object' or not(input ?& array['activityInstanceId','reconstructionAiOutputId','confirmed'])
 or exists(select 1 from jsonb_object_keys(input) k where k not in ('activityInstanceId','reconstructionAiOutputId','confirmed'))
 or input->'confirmed' is distinct from 'true'::jsonb then raise exception 'Invalid checkpoint' using errcode='22023';end if;
 select * into o from public.ai_outputs where id=(input->>'reconstructionAiOutputId')::uuid;
 if actor is null or o.id is null or o.activity_instance_id is distinct from (input->>'activityInstanceId')::uuid
 or o.task_type<>'COMPARATIVE_ANALYSIS' or o.ai_role<>'COMPARATIVE_CRITICAL_ANALYST' or o.output_type<>'COMPARISON'
 or not public.can_read_brainstorm_derived_ai_output(o.id)
 or not exists(select 1 from public.ai_task_operations op where op.output_id=o.id and op.status='completed' and op.task_type='COMPARATIVE_ANALYSIS')
 then raise exception 'Checkpoint unavailable' using errcode='42501';end if;
 perform private.require_session10_activity(o.activity_instance_id,o.project_id,o.workspace_id);
 select bi.* into b from public.project_baseline_items bi
 join public.artifacts a on a.id=bi.artifact_id and a.project_id=o.project_id and a.workspace_id=o.workspace_id
 join public.artifact_versions v on v.id=bi.artifact_version_id and v.artifact_id=a.id
 join public.ai_context_references r on r.ai_output_id=o.id and r.entity_type='ARTIFACT_VERSION' and r.context_role='CURRENT_ARTIFACT' and r.entity_id=v.id and r.share_snapshot_id is null
 where bi.project_id=o.project_id and bi.baseline_type='CURRENT_INVENTION_CONCEPT' and a.artifact_type='INVENTION_CONCEPT' and bi.effective_to is null and a.current_version_id=v.id and v.status='CURRENT'
 order by bi.id limit 1 for share of bi,a,v;
 if b.id is null
 then raise exception 'Current baseline required' using errcode='42501';end if;
 if public.resolve_ai_context_source(jsonb_build_object('projectId',o.project_id,'workspaceId',o.workspace_id,'activityInstanceId',o.activity_instance_id,'entityType','ARTIFACT_VERSION','entityId',b.artifact_version_id,'contextRole','CURRENT_ARTIFACT')) is null
 then raise exception 'Current baseline unavailable' using errcode='42501';end if;
 insert into public.session10_reconstruction_checkpoints(activity_instance_id,project_id,workspace_id,reconstruction_ai_output_id,baseline_item_id,confirmed_by)
 values(o.activity_instance_id,o.project_id,o.workspace_id,o.id,b.id,actor) on conflict(activity_instance_id,reconstruction_ai_output_id,confirmed_by) do nothing;
 select * into c from public.session10_reconstruction_checkpoints where activity_instance_id=o.activity_instance_id and reconstruction_ai_output_id=o.id and confirmed_by=actor;
 return to_jsonb(c);
end$$;
create function private.require_session10_checkpoint(cid uuid,oid uuid,aid uuid,pid uuid,wid uuid) returns public.session10_reconstruction_checkpoints language plpgsql security definer set search_path='' as $$
declare c public.session10_reconstruction_checkpoints;begin
 perform private.require_session10_activity(aid,pid,wid);
 select * into c from public.session10_reconstruction_checkpoints where id=cid and reconstruction_ai_output_id=oid and activity_instance_id=aid and project_id=pid and workspace_id=wid;
 if c.id is null or not public.can_read_brainstorm_derived_ai_output(oid)
 or not exists(select 1 from public.project_baseline_items b join public.artifacts a on a.id=b.artifact_id join public.artifact_versions v on v.id=b.artifact_version_id where b.id=c.baseline_item_id and b.effective_to is null and a.current_version_id=v.id and v.status='CURRENT')
 then raise exception 'Checkpoint unavailable' using errcode='42501';end if;
 if public.resolve_ai_context_source(jsonb_build_object('projectId',pid,'workspaceId',wid,'activityInstanceId',aid,'entityType','ARTIFACT_VERSION','entityId',(select artifact_version_id from public.project_baseline_items where id=c.baseline_item_id),'contextRole','CURRENT_ARTIFACT')) is null
 then raise exception 'Current baseline unavailable' using errcode='42501';end if;
 return c;
end$$;
create function public.resolve_session10_checkpoint(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.session10_reconstruction_checkpoints;begin
 if jsonb_typeof(input) is distinct from 'object' or not(input ?& array['checkpointId','reconstructionAiOutputId','activityInstanceId','projectId','workspaceId'])
 or (select count(*) from jsonb_object_keys(input))<>5 then raise exception 'Invalid checkpoint' using errcode='22023';end if;
 c:=private.require_session10_checkpoint((input->>'checkpointId')::uuid,(input->>'reconstructionAiOutputId')::uuid,(input->>'activityInstanceId')::uuid,(input->>'projectId')::uuid,(input->>'workspaceId')::uuid);
 return to_jsonb(c)||jsonb_build_object('baseline_version_id',(select artifact_version_id from public.project_baseline_items where id=c.baseline_item_id));
end$$;
alter table public.ai_task_operations add column session10_checkpoint_id uuid references public.session10_reconstruction_checkpoints(id),add column session10_gap_id uuid references public.development_objects(id),add column session10_gap_share_id uuid references public.shares(id);
-- Preserve M14.11 verbatim behind least-privilege wrappers. No new caller can
-- execute the original implementations or bypass the Session 10 guards.
alter function public.begin_ai_task_operation(jsonb) set schema private;
alter function private.begin_ai_task_operation(jsonb) rename to begin_ai_task_operation_m1411;
revoke all on function private.begin_ai_task_operation_m1411(jsonb) from public,anon,authenticated,service_role;
create function public.begin_ai_task_operation(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result0 jsonb;c public.session10_reconstruction_checkpoints;op public.ai_task_operations;gap0 uuid;gap_share0 uuid;
begin
 if input->>'taskType'='SESSION10_GAP_REFINEMENT' then
  perform private.ai_task_actor((input->>'actorId')::uuid);
  c:=private.require_session10_checkpoint((input->>'session10CheckpointId')::uuid,(input->>'reconstructionAiOutputId')::uuid,(input->>'activityInstanceId')::uuid,(input->>'projectId')::uuid,(input->>'workspaceId')::uuid);
  gap0:=(input->>'session10GapId')::uuid;
  gap_share0:=(input->>'session10GapShareId')::uuid;
  if not exists(select 1 from public.development_objects g where g.id=gap0 and g.object_type='GAP' and (gap_share0 is not null or (g.archived_at is null and g.project_id=c.project_id and g.workspace_id=c.workspace_id)))
  or public.resolve_ai_context_source(jsonb_build_object('projectId',c.project_id,'workspaceId',c.workspace_id,'activityInstanceId',c.activity_instance_id,'entityType','DEVELOPMENT_OBJECT','entityId',gap0,'contextRole','GAP')||case when gap_share0 is null then '{}'::jsonb else jsonb_build_object('shareId',gap_share0) end) is null then raise exception 'Gap unavailable' using errcode='42501';end if;
 end if;
 result0:=private.begin_ai_task_operation_m1411(input);
 if c.id is not null then
  select * into op from public.ai_task_operations where id=(result0->>'operationId')::uuid for update;
  if op.session10_checkpoint_id is not null and (op.session10_checkpoint_id,op.session10_gap_id,op.session10_gap_share_id) is distinct from (c.id,gap0,gap_share0) then raise exception 'Request conflict' using errcode='23505';end if;
  update public.ai_task_operations set session10_checkpoint_id=c.id,session10_gap_id=gap0,session10_gap_share_id=gap_share0 where id=op.id and session10_checkpoint_id is null;
 end if;
 return result0;
end$$;
alter function public.save_ai_task_result(jsonb) set schema private;
alter function private.save_ai_task_result(jsonb) rename to save_ai_task_result_m1411;
revoke all on function private.save_ai_task_result_m1411(jsonb) from public,anon,authenticated,service_role;
create function public.save_ai_task_result(input jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare op public.ai_task_operations;c public.session10_reconstruction_checkpoints;begin
 select * into op from public.ai_task_operations where id=(input->>'operationId')::uuid and requested_by=(input->>'actorId')::uuid;
 if op.task_type='SESSION10_GAP_REFINEMENT' then
  perform private.ai_task_actor(op.requested_by);
  select * into c from public.session10_reconstruction_checkpoints where id=op.session10_checkpoint_id;
  perform private.require_session10_checkpoint(c.id,c.reconstruction_ai_output_id,op.activity_instance_id,op.project_id,op.workspace_id);
  if jsonb_typeof(input->'references') is distinct from 'array' then raise exception 'Invalid context' using errcode='22023';end if;
  if (select count(*) from jsonb_array_elements(input->'references') r where r->>'context_role'='GAP')<>1
  or not exists(select 1 from jsonb_array_elements(input->'references') r where r->>'context_role'='GAP' and r->>'entity_type'='DEVELOPMENT_OBJECT' and r->>'entity_id'=op.session10_gap_id::text and (r->>'share_snapshot_id')::uuid is not distinct from (select id from public.share_snapshots where share_id=op.session10_gap_share_id))
  then raise exception 'Exactly one selected Gap required' using errcode='42501';end if;
  if not exists(select 1 from jsonb_array_elements(input->'references') r join public.project_baseline_items b on b.id=c.baseline_item_id where r->>'context_role'='CURRENT_ARTIFACT' and r->>'entity_type'='ARTIFACT_VERSION' and r->>'entity_id'=b.artifact_version_id::text and r->>'share_snapshot_id' is null)
  then raise exception 'Confirmed baseline required' using errcode='42501';end if;
 end if;
 return private.save_ai_task_result_m1411(input);
end$$;
revoke all on function public.validate_session10_reconstruction_scope(uuid,uuid,uuid),public.confirm_session10_reconstruction(jsonb),public.resolve_session10_checkpoint(jsonb),public.begin_ai_task_operation(jsonb),public.save_ai_task_result(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.validate_session10_reconstruction_scope(uuid,uuid,uuid),public.confirm_session10_reconstruction(jsonb),public.resolve_session10_checkpoint(jsonb) to authenticated;
grant execute on function public.begin_ai_task_operation(jsonb),public.save_ai_task_result(jsonb) to service_role;
revoke all on function private.preserve_session10_checkpoint(),private.require_session10_activity(uuid,uuid,uuid),private.require_session10_checkpoint(uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
comment on table public.session10_reconstruction_checkpoints is 'Immutable human review of one exact reconstruction; confirmer is provenance, never authority. Every use requires current canonical scope. Not verification, approval, candidate acceptance or an ACL.';
commit;
