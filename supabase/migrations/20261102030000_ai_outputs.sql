begin;
create type public.ai_output_type as enum ('ANALYSIS','SUGGESTION','HYPOTHESIS','DRAFT','COMPARISON','CLASSIFICATION','SUMMARY','CANDIDATE_SOLUTION');
create type public.ai_output_verification_status as enum ('UNVERIFIED','UNDER_REVIEW','PARTIALLY_VERIFIED','VERIFIED_AGAINST_SOURCES','CONTRADICTED','REJECTED');
create type public.ai_output_disposition as enum ('KEEP_FOR_REVIEW','ACCEPT_AS_CANDIDATE','MODIFIED','REJECTED','INVESTIGATE_FURTHER','CONVERTED_TO_PROJECT_OBJECT');
create table public.ai_outputs (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null,
 workspace_id uuid not null references public.workspaces(id) on delete restrict,
 activity_instance_id uuid references public.activity_instances(id) on delete restrict,
 requested_by uuid not null default public.current_platform_user_id() references public.users(id) on delete restrict,
 ai_role text not null check(length(btrim(ai_role))>0),
 task_type text not null check(length(btrim(task_type))>0),
 prompt_text text not null check(length(btrim(prompt_text))>0),
 response_text text not null check(length(btrim(response_text))>0),
 output_type public.ai_output_type not null,
 verification_status public.ai_output_verification_status not null default 'UNVERIFIED',
 disposition public.ai_output_disposition not null default 'KEEP_FOR_REVIEW',
 created_at timestamptz not null default clock_timestamp(),
 model_provider_reference text check(model_provider_reference is null or length(btrim(model_provider_reference))>0),
 metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
 foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id) on delete restrict
);
create index ai_outputs_project_time on public.ai_outputs(project_id,created_at,id);
create index ai_outputs_workspace_time on public.ai_outputs(workspace_id,created_at,id);
create index ai_outputs_activity on public.ai_outputs(activity_instance_id) where activity_instance_id is not null;
create index ai_outputs_requester on public.ai_outputs(requested_by);

-- Invoker integrity guard: no client writer/RPC or provider integration exists.
-- A later narrowly authorized Task Service must supply role/task and safe metadata.
create function private.preserve_ai_output() returns trigger
language plpgsql set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();
begin
 if tg_op<>'INSERT' then raise exception 'Generated AI history is immutable' using errcode='55000';end if;
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 if new.requested_by is distinct from actor then raise exception 'Invalid requester' using errcode='42501';end if;
 perform public.require_development_object_write(new.project_id,new.workspace_id);
 if new.activity_instance_id is not null and not exists(select 1 from public.activity_instances a where a.id=new.activity_instance_id and a.project_id=new.project_id and a.workspace_id=new.workspace_id and public.can_read_activity_instance(a.id)) then
  raise exception 'Incompatible Activity scope' using errcode='23514';end if;
 if new.verification_status<>'UNVERIFIED' then raise exception 'Human verification is deferred' using errcode='23514';end if;
 -- Reject credential-bearing keys at any depth; runtime must additionally avoid
 -- placing secrets in values or in the generated prompt/response themselves.
 if exists(with recursive nodes(body) as (
  select new.metadata union all
  select child.body from nodes n cross join lateral (
   select value body from jsonb_each(case when jsonb_typeof(n.body)='object' then n.body else '{}'::jsonb end)
   union all
   select value body from jsonb_array_elements(case when jsonb_typeof(n.body)='array' then n.body else '[]'::jsonb end)
  ) child
 ) select 1 from nodes n cross join lateral jsonb_each(case when jsonb_typeof(n.body)='object' then n.body else '{}'::jsonb end) e
  where e.key ~* '^(api[_-]?key|provider[_-]?api[_-]?key|secret|password|authorization|access[_-]?token|refresh[_-]?token|service[_-]?role([_-]?key)?|private[_-]?key)$') then
  raise exception 'Credential metadata is forbidden' using errcode='23514';end if;
 new.created_at:=clock_timestamp();
 return new;
end$$;
revoke all on function private.preserve_ai_output() from public,anon,authenticated,service_role;
create trigger ai_outputs_immutable before insert or update or delete on public.ai_outputs for each row execute function private.preserve_ai_output();
alter table public.ai_outputs enable row level security;
revoke all on public.ai_outputs from public,anon,authenticated,service_role;
grant select on public.ai_outputs to authenticated;
create policy ai_outputs_scoped_read on public.ai_outputs for select to authenticated using(public.can_read_development_project(project_id));
create policy ai_outputs_no_client_insert on public.ai_outputs as restrictive for insert to authenticated with check(false);
create policy ai_outputs_no_client_update on public.ai_outputs as restrictive for update to authenticated using(false) with check(false);
create policy ai_outputs_no_client_delete on public.ai_outputs as restrictive for delete to authenticated using(false);
comment on table public.ai_outputs is 'M14.1 immutable generated results, not Evidence or authority. Canonical Project/Workspace reads only. No ordinary writer, provider call, Task Service, context builder, promotion, sharing or disposition workflow.';
comment on column public.ai_outputs.ai_role is 'Trusted runtime provenance; no client input contract or role catalog is introduced by this foundation.';
comment on column public.ai_outputs.task_type is 'Trusted Task Service provenance; no arbitrary client writer is granted.';
comment on column public.ai_outputs.model_provider_reference is 'Optional external provenance only; never the canonical platform identity or a credential.';
commit;
