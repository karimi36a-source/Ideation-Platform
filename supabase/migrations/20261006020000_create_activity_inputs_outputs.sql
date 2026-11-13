begin;
-- Canonical references only; future target storage remains deferred.
create table public.activity_inputs (
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 input_type text not null check (input_type='development_object'),
 development_object_id uuid references public.development_objects(id) on delete restrict,
 artifact_id uuid,
 artifact_version_id uuid,
 evidence_id uuid,
 required boolean not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint activity_inputs_supported_target check (development_object_id is not null and artifact_id is null and artifact_version_id is null and evidence_id is null)
);
create index activity_inputs_activity on public.activity_inputs(activity_instance_id,created_at,id);
create index activity_inputs_object on public.activity_inputs(development_object_id);
comment on column public.activity_inputs.artifact_id is 'Nullable reserved UUID, constrained null in M7.3. FK and target validation deferred to M8 Artifacts/Versions.';
comment on column public.activity_inputs.artifact_version_id is 'Nullable reserved UUID, constrained null in M7.3. FK and target validation deferred to M8 Artifacts/Versions.';
comment on column public.activity_inputs.evidence_id is 'Nullable reserved UUID, constrained null in M7.3. FK and target validation deferred to M12 Evidence.';
comment on table public.activity_inputs is 'Canonical Object ID references only. No content copy, approval, verification or baseline side effects. M7.8/M7.9 own registration operations.';
create table public.activity_outputs (
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 output_type text not null check (output_type='development_object'),
 development_object_id uuid references public.development_objects(id) on delete restrict,
 artifact_id uuid,
 decision_id uuid,
 evidence_id uuid,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint activity_outputs_supported_target check (development_object_id is not null and artifact_id is null and decision_id is null and evidence_id is null)
);
create index activity_outputs_activity on public.activity_outputs(activity_instance_id,created_at,id);
create index activity_outputs_object on public.activity_outputs(development_object_id);
comment on column public.activity_outputs.artifact_id is 'Nullable reserved UUID, constrained null in M7.3. FK and target validation deferred to M8 Artifacts/Versions.';
comment on column public.activity_outputs.decision_id is 'Nullable reserved UUID, constrained null in M7.3. FK and target validation deferred to Decision milestone.';
comment on column public.activity_outputs.evidence_id is 'Nullable reserved UUID, constrained null in M7.3. FK and target validation deferred to M12 Evidence.';
comment on table public.activity_outputs is 'Canonical Object ID references only. No content copy, approval, verification or baseline side effects. M7.8/M7.9 own registration operations.';
create function public.validate_activity_object_link() returns trigger language plpgsql set search_path='' as $$
declare a public.activity_instances; o public.development_objects;
begin
 select * into a from public.activity_instances where id=new.activity_instance_id for share;
 if not found then raise exception 'Invalid Activity reference' using errcode='23503';end if;
 select * into o from public.development_objects where id=new.development_object_id for share;
 if not found then
  -- Let the target-shape constraint reject an empty target; FK handles missing IDs.
  if new.development_object_id is null then return new;end if;
  raise exception 'Invalid Object reference' using errcode='23503';
 end if;
 if a.project_id<>o.project_id or a.workspace_id<>o.workspace_id then
  raise exception 'Activity/Object scope mismatch' using errcode='23514';
 end if;
 return new;
end $$;
revoke all on function public.validate_activity_object_link() from public,anon,authenticated,service_role;
create trigger activity_inputs_scope before insert or update on public.activity_inputs for each row execute function public.validate_activity_object_link();
alter table public.activity_inputs enable row level security;
revoke all on public.activity_inputs from public,anon,authenticated,service_role;
grant select on public.activity_inputs to authenticated;
create policy activity_inputs_read on public.activity_inputs for select to authenticated using (public.can_read_activity_instance(activity_instance_id) and exists(select 1 from public.development_objects o join public.activity_instances a on a.id=activity_inputs.activity_instance_id where o.id=activity_inputs.development_object_id and o.project_id=a.project_id and o.workspace_id=a.workspace_id));
create policy activity_inputs_read_guard on public.activity_inputs as restrictive for select to authenticated using (public.can_read_activity_instance(activity_instance_id) and exists(select 1 from public.development_objects o join public.activity_instances a on a.id=activity_inputs.activity_instance_id where o.id=activity_inputs.development_object_id and o.project_id=a.project_id and o.workspace_id=a.workspace_id));
create policy activity_inputs_insert_deny on public.activity_inputs as restrictive for insert to authenticated with check(false);
create policy activity_inputs_update_deny on public.activity_inputs as restrictive for update to authenticated using(false) with check(false);
create policy activity_inputs_delete_deny on public.activity_inputs as restrictive for delete to authenticated using(false);
create policy activity_inputs_anon_deny on public.activity_inputs as restrictive for all to anon using(false) with check(false);
create trigger activity_outputs_scope before insert or update on public.activity_outputs for each row execute function public.validate_activity_object_link();
alter table public.activity_outputs enable row level security;
revoke all on public.activity_outputs from public,anon,authenticated,service_role;
grant select on public.activity_outputs to authenticated;
create policy activity_outputs_read on public.activity_outputs for select to authenticated using (public.can_read_activity_instance(activity_instance_id) and exists(select 1 from public.development_objects o join public.activity_instances a on a.id=activity_outputs.activity_instance_id where o.id=activity_outputs.development_object_id and o.project_id=a.project_id and o.workspace_id=a.workspace_id));
create policy activity_outputs_read_guard on public.activity_outputs as restrictive for select to authenticated using (public.can_read_activity_instance(activity_instance_id) and exists(select 1 from public.development_objects o join public.activity_instances a on a.id=activity_outputs.activity_instance_id where o.id=activity_outputs.development_object_id and o.project_id=a.project_id and o.workspace_id=a.workspace_id));
create policy activity_outputs_insert_deny on public.activity_outputs as restrictive for insert to authenticated with check(false);
create policy activity_outputs_update_deny on public.activity_outputs as restrictive for update to authenticated using(false) with check(false);
create policy activity_outputs_delete_deny on public.activity_outputs as restrictive for delete to authenticated using(false);
create policy activity_outputs_anon_deny on public.activity_outputs as restrictive for all to anon using(false) with check(false);
commit;
