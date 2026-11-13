begin;
-- Technical Architecture profile names only. No provider/model resolver or
-- pricing configuration is introduced by the observability foundation.
create type public.ai_usage_model_profile as enum ('AI_FAST','AI_STANDARD','AI_DEEP');
create type public.ai_usage_result as enum ('SUCCESS','FAILURE');
create table public.ai_usage_events (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null default public.current_platform_user_id() references public.users(id) on delete restrict,
 project_id uuid not null,
 workspace_id uuid not null references public.workspaces(id) on delete restrict,
 activity_instance_id uuid references public.activity_instances(id) on delete restrict,
 task_type text not null check(task_type ~ '^[A-Z][A-Z0-9_]{0,63}$'),
 model_profile public.ai_usage_model_profile not null,
 input_usage bigint check(input_usage between 0 and 9007199254740991),
 output_usage bigint check(output_usage between 0 and 9007199254740991),
 estimated_cost numeric check(estimated_cost>=0 and estimated_cost::text not in ('NaN','Infinity','-Infinity')),
 latency_ms bigint not null check(latency_ms between 0 and 9007199254740991),
 success_failure public.ai_usage_result not null,
 created_at timestamptz not null default clock_timestamp(),
 foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id) on delete restrict
);
create index ai_usage_events_user_time on public.ai_usage_events(user_id,created_at,id);
create index ai_usage_events_project_time on public.ai_usage_events(project_id,created_at,id);
create index ai_usage_events_workspace_time on public.ai_usage_events(workspace_id,created_at,id);
create index ai_usage_events_activity on public.ai_usage_events(activity_instance_id) where activity_instance_id is not null;
create function private.preserve_ai_usage_event() returns trigger
language plpgsql set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();
begin
 if tg_op<>'INSERT' then raise exception 'Usage history is append-only' using errcode='55000';end if;
 if actor is null or new.user_id is distinct from actor then raise exception 'Usage unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(new.project_id,new.workspace_id);
 if new.activity_instance_id is not null and not exists(select 1 from public.activity_instances a
  where a.id=new.activity_instance_id and (a.project_id,a.workspace_id)=(new.project_id,new.workspace_id) and public.can_read_activity_instance(a.id)) then
  raise exception 'Incompatible Activity scope' using errcode='23514';end if;
 new.created_at:=clock_timestamp();
 return new;
end$$;
revoke all on function private.preserve_ai_usage_event() from public,anon,authenticated,service_role;
create trigger ai_usage_events_preserve before insert or update or delete on public.ai_usage_events for each row execute function private.preserve_ai_usage_event();
alter table public.ai_usage_events enable row level security;
revoke all on public.ai_usage_events from public,anon,authenticated,service_role;
grant select on public.ai_usage_events to authenticated;
-- Initial observability is self-only AND current canonical Project/Workspace
-- access. No organization dashboard, role-only grant, or Team-wide enumeration.
create policy ai_usage_events_self_scope_read on public.ai_usage_events for select to authenticated using(user_id=public.current_platform_user_id() and public.can_read_development_project(project_id));
create policy ai_usage_events_no_insert on public.ai_usage_events as restrictive for insert to authenticated with check(false);
create policy ai_usage_events_no_update on public.ai_usage_events as restrictive for update to authenticated using(false) with check(false);
create policy ai_usage_events_no_delete on public.ai_usage_events as restrictive for delete to authenticated using(false);

-- Server runtime only. The server assigns one UUID per actual attempt and
-- reuses it only for logging retries; a provider retry receives a new UUID.
-- No browser RPC/grant, caller-supplied user, free metadata, provider error/body,
-- prompt, response, source payload or File/reference field exists here.
create function private.record_ai_usage_event(input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();r public.ai_usage_events;prior public.ai_usage_events;k text;v jsonb;
begin
 if actor is null then raise exception 'Usage unavailable' using errcode='42501';end if;
 if jsonb_typeof(input) is distinct from 'object'
 or exists(select 1 from jsonb_object_keys(input) key where key not in ('attemptId','projectId','workspaceId','activityInstanceId','taskType','modelProfile','inputUsage','outputUsage','estimatedCost','latencyMs','successFailure'))
 or not (input ?& array['attemptId','projectId','workspaceId','taskType','modelProfile','latencyMs','successFailure']) then
  raise exception 'Invalid usage metrics' using errcode='22023';end if;
 foreach k in array array['attemptId','projectId','workspaceId','taskType','modelProfile','successFailure'] loop
  if jsonb_typeof(input->k) is distinct from 'string' then raise exception 'Invalid usage metrics' using errcode='22023';end if;
 end loop;
 if input?'activityInstanceId' and jsonb_typeof(input->'activityInstanceId') not in ('string','null') then raise exception 'Invalid usage metrics' using errcode='22023';end if;
 foreach k in array array['inputUsage','outputUsage','latencyMs','estimatedCost'] loop
  v:=input->k;
  if v is null or v='null'::jsonb then
   if k='latencyMs' then raise exception 'Invalid usage metrics' using errcode='22023';end if;
  elsif jsonb_typeof(v)<>'number' or (k<>'estimatedCost' and (v#>>'{}')::numeric<>trunc((v#>>'{}')::numeric)) then
   raise exception 'Invalid usage metrics' using errcode='22023';
  end if;
 end loop;
 insert into public.ai_usage_events(id,user_id,project_id,workspace_id,activity_instance_id,task_type,model_profile,input_usage,output_usage,estimated_cost,latency_ms,success_failure)
 values((input->>'attemptId')::uuid,actor,(input->>'projectId')::uuid,(input->>'workspaceId')::uuid,(input->>'activityInstanceId')::uuid,
  input->>'taskType',(input->>'modelProfile')::public.ai_usage_model_profile,(input->>'inputUsage')::numeric::bigint,(input->>'outputUsage')::numeric::bigint,
  (input->>'estimatedCost')::numeric,(input->>'latencyMs')::numeric::bigint,(input->>'successFailure')::public.ai_usage_result)
 on conflict(id) do nothing returning * into r;
 if r.id is null then
  select * into prior from public.ai_usage_events where id=(input->>'attemptId')::uuid;
  if prior.user_id is distinct from actor or prior.project_id is distinct from (input->>'projectId')::uuid
   or prior.workspace_id is distinct from (input->>'workspaceId')::uuid or prior.activity_instance_id is distinct from (input->>'activityInstanceId')::uuid
   or prior.task_type is distinct from input->>'taskType' or prior.model_profile::text is distinct from input->>'modelProfile'
   or prior.input_usage is distinct from (input->>'inputUsage')::numeric::bigint or prior.output_usage is distinct from (input->>'outputUsage')::numeric::bigint
   or prior.estimated_cost is distinct from (input->>'estimatedCost')::numeric or prior.latency_ms is distinct from (input->>'latencyMs')::numeric::bigint
   or prior.success_failure::text is distinct from input->>'successFailure' then raise exception 'Usage attempt conflict' using errcode='23505';end if;
  return to_jsonb(prior);
 end if;
 return to_jsonb(r);
end$$;
revoke all on function private.record_ai_usage_event(jsonb) from public,anon,authenticated,service_role;
comment on table public.ai_usage_events is 'M14.4 append-only self-scoped operational metrics. No confidential context/output/provider payloads, organization-wide reader, provider calls, model resolver or authorization capabilities.';
comment on column public.ai_usage_events.id is 'Canonical event identity; trusted runtime reuses its server-assigned attempt UUID for exact logging retries only.';
comment on column public.ai_usage_events.input_usage is 'Provider-reported nonnegative count; NULL means unavailable, not an invented zero.';
comment on column public.ai_usage_events.output_usage is 'Provider-reported nonnegative count; NULL means unavailable, including failed attempts.';
comment on column public.ai_usage_events.estimated_cost is 'Nullable server-reported estimate. No provider prices, currency conversion or cost calculation is introduced.';
comment on column public.ai_usage_events.task_type is 'Bounded operational code supplied by future trusted runtime, not confidential free text or a client writable task catalog.';
commit;
