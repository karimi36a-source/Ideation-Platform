begin;
create table public.ai_task_operations (
 id uuid primary key default gen_random_uuid(),requested_by uuid not null references public.users(id),
 idempotency_key text not null check(length(btrim(idempotency_key)) between 1 and 200),
 request_fingerprint text not null check(request_fingerprint ~ '^[a-f0-9]{64}$'),
 project_id uuid not null,workspace_id uuid not null,activity_instance_id uuid not null references public.activity_instances(id),
 task_type text not null,ai_role text not null,model_profile public.ai_usage_model_profile not null,
 status text not null check(status in ('running','retryable','completed')),attempt_id uuid not null unique,
 output_id uuid unique references public.ai_outputs(id),created_at timestamptz not null default clock_timestamp(),
 check((status='completed')=(output_id is not null)),unique(requested_by,idempotency_key),
 foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id)
);
alter table public.ai_task_operations enable row level security;
revoke all on public.ai_task_operations from public,anon,authenticated,service_role;
create policy ai_task_operations_deny on public.ai_task_operations as restrictive for all to authenticated using(false) with check(false);
create function private.ai_task_actor(actor0 uuid) returns void language plpgsql set search_path='' as $$begin
 perform set_config('request.jwt.claim.sub',actor0::text,true);
end$$;
revoke all on function private.ai_task_actor(uuid) from public,anon,authenticated,service_role;
create function public.begin_ai_task_operation(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor0 uuid:=(input->>'actorId')::uuid;o public.ai_task_operations;s jsonb;
begin
 perform private.ai_task_actor(actor0);
 if public.current_platform_user_id() is distinct from actor0 then raise exception 'Task unavailable' using errcode='42501';end if;
 perform public.require_development_object_write((input->>'projectId')::uuid,(input->>'workspaceId')::uuid);
 s:=public.resolve_activity_ai_configuration((input->>'activityInstanceId')::uuid);
 if s is null or (s->>'project_id',s->>'workspace_id') is distinct from (input->>'projectId',input->>'workspaceId')
 or s->>'status' not in ('active','revision_requested') or s->>'definition_status'<>'active'
 or s #>> '{configuration,ai,enabled}' is distinct from 'true' or s #>> '{current_ai,enabled}' is distinct from 'true'
 or s->>'ai_role_code' is distinct from input->>'aiRole' or s->>'current_role' is distinct from input->>'aiRole' then raise exception 'Task unavailable' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('ai-task/'||actor0::text||'/'||(input->>'idempotencyKey'),0));
 select * into o from public.ai_task_operations where requested_by=actor0 and idempotency_key=input->>'idempotencyKey' for update;
 if found then
  if o.request_fingerprint is distinct from input->>'fingerprint' or (o.project_id,o.workspace_id,o.activity_instance_id,o.task_type) is distinct from ((input->>'projectId')::uuid,(input->>'workspaceId')::uuid,(input->>'activityInstanceId')::uuid,input->>'taskType') then raise exception 'Request conflict' using errcode='23505';end if;
  if o.status='running' then raise exception 'Task in progress' using errcode='55P03';end if;
  if o.status='completed' then return jsonb_build_object('operationId',o.id,'attemptId',o.attempt_id,'outputId',o.output_id,'completed',true);end if;
  update public.ai_task_operations set status='running',attempt_id=gen_random_uuid(),ai_role=input->>'aiRole',model_profile=(input->>'modelProfile')::public.ai_usage_model_profile where id=o.id returning * into o;
 else
  insert into public.ai_task_operations(requested_by,idempotency_key,request_fingerprint,project_id,workspace_id,activity_instance_id,task_type,ai_role,model_profile,status,attempt_id)
  values(actor0,input->>'idempotencyKey',input->>'fingerprint',(input->>'projectId')::uuid,(input->>'workspaceId')::uuid,(input->>'activityInstanceId')::uuid,input->>'taskType',input->>'aiRole',(input->>'modelProfile')::public.ai_usage_model_profile,'running',gen_random_uuid()) returning * into o;
 end if;
 return jsonb_build_object('operationId',o.id,'attemptId',o.attempt_id,'outputId',null,'completed',false);
end$$;
-- Operational metrics may be recorded after access revocation, but ONLY for an
-- already-authorized server-owned attempt. This exception grants no source read.
create or replace function private.preserve_ai_usage_event() returns trigger language plpgsql set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();o public.ai_task_operations;
begin
 if tg_op<>'INSERT' then raise exception 'Usage history is append-only' using errcode='55000';end if;
 select * into o from public.ai_task_operations where attempt_id=new.id;
 if o.id is not null and current_user=pg_catalog.pg_get_userbyid((select proowner from pg_catalog.pg_proc where oid='public.record_ai_task_attempt(jsonb)'::regprocedure))
 and new.user_id=o.requested_by and (new.project_id,new.workspace_id,new.activity_instance_id,new.task_type,new.model_profile)=(o.project_id,o.workspace_id,o.activity_instance_id,o.task_type,o.model_profile) then
  new.created_at:=clock_timestamp();return new;
 end if;
 if actor is null or new.user_id is distinct from actor then raise exception 'Usage unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(new.project_id,new.workspace_id);
 if new.activity_instance_id is not null and not exists(select 1 from public.activity_instances a where a.id=new.activity_instance_id and (a.project_id,a.workspace_id)=(new.project_id,new.workspace_id) and public.can_read_activity_instance(a.id)) then raise exception 'Incompatible Activity scope' using errcode='23514';end if;
 new.created_at:=clock_timestamp();return new;
end$$;
create function public.record_ai_task_attempt(input jsonb) returns void language plpgsql security definer set search_path='' as $$
declare o public.ai_task_operations;r public.ai_usage_events;
begin
 select * into o from public.ai_task_operations where id=(input->>'operationId')::uuid and requested_by=(input->>'actorId')::uuid and attempt_id=(input->>'attemptId')::uuid for update;
 if o.id is null then raise exception 'Task unavailable' using errcode='42501';end if;
 perform private.ai_task_actor(o.requested_by);
 select * into r from public.ai_usage_events where id=o.attempt_id;
 if found then
  if (r.user_id,r.project_id,r.workspace_id,r.activity_instance_id,r.task_type,r.model_profile) is distinct from (o.requested_by,o.project_id,o.workspace_id,o.activity_instance_id,o.task_type,o.model_profile) then raise exception 'Attempt conflict' using errcode='23505';end if;
  if (r.input_usage,r.output_usage,r.latency_ms,r.success_failure) is distinct from ((input->>'inputUsage')::bigint,(input->>'outputUsage')::bigint,(input->>'latencyMs')::bigint,(input->>'successFailure')::public.ai_usage_result) then raise exception 'Attempt conflict' using errcode='23505';end if;
  return;
 end if;
 insert into public.ai_usage_events(id,user_id,project_id,workspace_id,activity_instance_id,task_type,model_profile,input_usage,output_usage,latency_ms,success_failure)
 values(o.attempt_id,o.requested_by,o.project_id,o.workspace_id,o.activity_instance_id,o.task_type,o.model_profile,(input->>'inputUsage')::bigint,(input->>'outputUsage')::bigint,(input->>'latencyMs')::bigint,(input->>'successFailure')::public.ai_usage_result);
end$$;
create function public.release_ai_task_operation(input jsonb) returns void language plpgsql security definer set search_path='' as $$begin
 update public.ai_task_operations o set status='retryable' where o.id=(input->>'operationId')::uuid and o.requested_by=(input->>'actorId')::uuid and o.attempt_id=(input->>'attemptId')::uuid and o.status='running' and (exists(select 1 from public.ai_usage_events u where u.id=o.attempt_id) or input->>'beforeProvider'='true');
end$$;
create function public.save_ai_task_result(input jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare o public.ai_task_operations;result0 uuid;r jsonb;saved public.ai_context_references;
begin
 select * into o from public.ai_task_operations where id=(input->>'operationId')::uuid and requested_by=(input->>'actorId')::uuid for update;
 if o.id is null then raise exception 'Task unavailable' using errcode='42501';end if;
 perform private.ai_task_actor(o.requested_by);
 if public.current_platform_user_id() is distinct from o.requested_by then raise exception 'Task unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(o.project_id,o.workspace_id);
 if not public.can_read_activity_instance(o.activity_instance_id) or not exists(select 1 from public.activity_instances a where a.id=o.activity_instance_id and a.status in ('active','revision_requested')) then raise exception 'Task unavailable' using errcode='42501';end if;
 if o.status='completed' then return o.output_id;end if;
 if o.status<>'running' or o.attempt_id is distinct from (input->>'attemptId')::uuid or not exists(select 1 from public.ai_usage_events where id=o.attempt_id and success_failure='SUCCESS') then raise exception 'Attempt unavailable' using errcode='55000';end if;
 if jsonb_typeof(input->'references') is distinct from 'array' or jsonb_array_length(input->'references') not between 1 and 32 then raise exception 'Invalid provenance' using errcode='22023';end if;
 if (select count(*)<>count(distinct value) from jsonb_array_elements(input->'references')) then raise exception 'Duplicate provenance' using errcode='22023';end if;
 insert into public.ai_outputs(project_id,workspace_id,activity_instance_id,requested_by,ai_role,task_type,prompt_text,response_text,output_type,model_provider_reference,metadata)
 values(o.project_id,o.workspace_id,o.activity_instance_id,o.requested_by,o.ai_role,o.task_type,input->>'promptText',input->>'responseText',(input->>'outputType')::public.ai_output_type,input->>'providerReference',input->'metadata') returning id into result0;
 for r in select value from jsonb_array_elements(input->'references') loop
  insert into public.ai_context_references(ai_output_id,entity_type,entity_id,context_role,included_snapshot_hash,permission_scope,share_snapshot_id)
  values(result0,(r->>'entity_type')::public.ai_context_entity_type,(r->>'entity_id')::uuid,(r->>'context_role')::public.ai_context_role,r->>'included_snapshot_hash',r->'permission_scope',(r->>'share_snapshot_id')::uuid) returning * into saved;
  if saved.included_snapshot_hash is distinct from r->>'included_snapshot_hash' then raise exception 'Context changed' using errcode='42501';end if;
 end loop;
 update public.ai_task_operations set status='completed',output_id=result0 where id=o.id;
 return result0;
end$$;
revoke all on function public.begin_ai_task_operation(jsonb),public.record_ai_task_attempt(jsonb),public.release_ai_task_operation(jsonb),public.save_ai_task_result(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.begin_ai_task_operation(jsonb),public.record_ai_task_attempt(jsonb),public.release_ai_task_operation(jsonb),public.save_ai_task_result(jsonb) to service_role;
comment on table public.ai_task_operations is 'M14.11 server-owned operation identity, not an ACL, queue or stored prompt/context. Running attempts fail closed on concurrent retry; no automatic lease takeover.';
commit;


