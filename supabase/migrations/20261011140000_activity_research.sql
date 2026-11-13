begin;
-- References only: all research remains in its canonical Project tables.
create table public.activity_research_links(
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 entity_type text not null check(entity_type in ('PATENT_RECORD','PATENT_SEARCH_LOG')),
 entity_id uuid not null,
 relationship_type text not null default 'OUTPUT_REFERENCE' check(relationship_type='OUTPUT_REFERENCE'),
 created_by uuid not null references public.users(id) on delete restrict,
 created_at timestamptz not null default statement_timestamp(),
 unique(activity_instance_id,entity_type,entity_id,relationship_type)
);
create index activity_research_links_entity on public.activity_research_links(entity_type,entity_id);
create function private.guard_activity_research_link() returns trigger language plpgsql set search_path='' as $$
declare a public.activity_instances;p uuid;w uuid;begin
 if tg_op<>'INSERT' then raise exception 'Research reference history is immutable' using errcode='55000';end if;
 select * into a from public.activity_instances where id=new.activity_instance_id for share;
 if new.entity_type='PATENT_RECORD' then select project_id,workspace_id into p,w from public.patent_records where id=new.entity_id for share;
 elsif new.entity_type='PATENT_SEARCH_LOG' then select project_id,workspace_id into p,w from public.patent_search_logs where id=new.entity_id for share;end if;
 if p is null or a.id is null or p<>a.project_id or w<>a.workspace_id then raise exception 'Invalid research reference' using errcode='23514';end if;
 if new.created_by is distinct from public.current_platform_user_id() then raise exception 'Resource unavailable' using errcode='42501';end if;
 new.created_at:=statement_timestamp();return new;
end$$;
revoke all on function private.guard_activity_research_link() from public,anon,authenticated,service_role;
create trigger activity_research_links_history before insert or update or delete on public.activity_research_links for each row execute function private.guard_activity_research_link();
alter table public.activity_research_links enable row level security;
revoke all on public.activity_research_links from public,anon,authenticated,service_role;
grant select on public.activity_research_links to authenticated;
create policy activity_research_links_read on public.activity_research_links for select to authenticated using(
 public.can_read_activity_instance(activity_instance_id) and (
 (entity_type='PATENT_RECORD' and exists(select 1 from public.patent_records p join public.activity_instances a on a.id=activity_research_links.activity_instance_id where p.id=entity_id and p.project_id=a.project_id and p.workspace_id=a.workspace_id)) or
 (entity_type='PATENT_SEARCH_LOG' and exists(select 1 from public.patent_search_logs p join public.activity_instances a on a.id=activity_research_links.activity_instance_id where p.id=entity_id and p.project_id=a.project_id and p.workspace_id=a.workspace_id))));
create function public.add_activity_research_reference(target_instance uuid,target_type text,target_entity uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;p uuid;w uuid;source_activity uuid;r public.activity_research_links;begin
 a:=public.lock_activity_artifact_contribution(target_instance);
 if target_type not in ('PATENT_RECORD','PATENT_SEARCH_LOG') or target_type is null or target_entity is null then raise exception 'Invalid input' using errcode='22023';end if;
 if target_type='PATENT_RECORD' then select project_id,workspace_id into p,w from public.patent_records where id=target_entity for share;
 else select project_id,workspace_id,activity_instance_id into p,w,source_activity from public.patent_search_logs where id=target_entity for share;end if;
 if p is null or p<>a.project_id or w<>a.workspace_id or not public.can_read_development_project(p)
 or (source_activity is not null and not public.can_read_activity_instance(source_activity)) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fici-research-output:'||a.id::text||':'||target_type||':'||target_entity::text,1219));
 a:=public.lock_activity_artifact_contribution(target_instance);
 if source_activity is not null and not public.can_read_activity_instance(source_activity) then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into r from public.activity_research_links where activity_instance_id=a.id and entity_type=target_type and entity_id=target_entity and relationship_type='OUTPUT_REFERENCE';
 if r.id is not null then return to_jsonb(r);end if;
 insert into public.activity_research_links(activity_instance_id,entity_type,entity_id,created_by) values(a.id,target_type,target_entity,public.current_platform_user_id()) returning * into r;
 return to_jsonb(r);
end$$;
revoke all on function public.add_activity_research_reference(uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.add_activity_research_reference(uuid,text,uuid) to authenticated;

alter table public.activity_inputs drop constraint activity_inputs_supported_target;
alter table public.activity_outputs drop constraint activity_outputs_supported_target;
alter table public.activity_inputs add constraint activity_inputs_supported_target check (
 (input_type='development_object' and development_object_id is not null and artifact_id is null and artifact_version_id is null and evidence_id is null)
 or (input_type='artifact' and artifact_id is not null and artifact_version_id is null and development_object_id is null and evidence_id is null)
 or (input_type='artifact_version' and artifact_id is not null and artifact_version_id is not null and development_object_id is null and evidence_id is null) or (input_type='evidence' and evidence_id is not null and development_object_id is null and artifact_id is null and artifact_version_id is null));
alter table public.activity_inputs add foreign key(evidence_id) references public.evidence(id) on delete restrict;
create unique index activity_inputs_evidence_unique on public.activity_inputs(activity_instance_id,evidence_id) where evidence_id is not null;
drop policy activity_inputs_read on public.activity_inputs;
create policy activity_inputs_read on public.activity_inputs for select to authenticated using(public.can_read_activity_instance(activity_instance_id) and (
 (development_object_id is not null and exists(select 1 from public.development_objects o join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where o.id=activity_inputs.development_object_id and o.project_id=ai.project_id and o.workspace_id=ai.workspace_id))
 or (artifact_id is not null and exists(select 1 from public.artifacts a join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where a.id=activity_inputs.artifact_id and a.project_id=ai.project_id and a.workspace_id=ai.workspace_id) and (artifact_version_id is null or exists(select 1 from public.artifact_versions v where v.id=activity_inputs.artifact_version_id and v.artifact_id=activity_inputs.artifact_id))) or (evidence_id is not null and exists(select 1 from public.evidence e join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where e.id=activity_inputs.evidence_id and e.project_id=ai.project_id and e.workspace_id=ai.workspace_id))));
drop policy activity_inputs_read_guard on public.activity_inputs;
create policy activity_inputs_read_guard on public.activity_inputs as restrictive for select to authenticated using(public.can_read_activity_instance(activity_instance_id) and (
 (development_object_id is not null and exists(select 1 from public.development_objects o join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where o.id=activity_inputs.development_object_id and o.project_id=ai.project_id and o.workspace_id=ai.workspace_id))
 or (artifact_id is not null and exists(select 1 from public.artifacts a join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where a.id=activity_inputs.artifact_id and a.project_id=ai.project_id and a.workspace_id=ai.workspace_id) and (artifact_version_id is null or exists(select 1 from public.artifact_versions v where v.id=activity_inputs.artifact_version_id and v.artifact_id=activity_inputs.artifact_id))) or (evidence_id is not null and exists(select 1 from public.evidence e join public.activity_instances ai on ai.id=activity_inputs.activity_instance_id where e.id=activity_inputs.evidence_id and e.project_id=ai.project_id and e.workspace_id=ai.workspace_id))));
alter table public.activity_outputs add constraint activity_outputs_supported_target check (
 (output_type='development_object' and development_object_id is not null and artifact_id is null and decision_id is null and evidence_id is null)
 or (output_type='artifact' and artifact_id is not null and development_object_id is null and decision_id is null and evidence_id is null) or (output_type='evidence' and evidence_id is not null and development_object_id is null and artifact_id is null and decision_id is null));
alter table public.activity_outputs add foreign key(evidence_id) references public.evidence(id) on delete restrict;
create unique index activity_outputs_evidence_unique on public.activity_outputs(activity_instance_id,evidence_id) where evidence_id is not null;
drop policy activity_outputs_read on public.activity_outputs;
create policy activity_outputs_read on public.activity_outputs for select to authenticated using(public.can_read_activity_instance(activity_instance_id) and (
 (development_object_id is not null and exists(select 1 from public.development_objects o join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where o.id=activity_outputs.development_object_id and o.project_id=ai.project_id and o.workspace_id=ai.workspace_id))
 or (artifact_id is not null and exists(select 1 from public.artifacts a join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where a.id=activity_outputs.artifact_id and a.activity_instance_id=ai.id and a.project_id=ai.project_id and a.workspace_id=ai.workspace_id)) or (evidence_id is not null and exists(select 1 from public.evidence e join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where e.id=activity_outputs.evidence_id and e.project_id=ai.project_id and e.workspace_id=ai.workspace_id))));
drop policy activity_outputs_read_guard on public.activity_outputs;
create policy activity_outputs_read_guard on public.activity_outputs as restrictive for select to authenticated using(public.can_read_activity_instance(activity_instance_id) and (
 (development_object_id is not null and exists(select 1 from public.development_objects o join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where o.id=activity_outputs.development_object_id and o.project_id=ai.project_id and o.workspace_id=ai.workspace_id))
 or (artifact_id is not null and exists(select 1 from public.artifacts a join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where a.id=activity_outputs.artifact_id and a.activity_instance_id=ai.id and a.project_id=ai.project_id and a.workspace_id=ai.workspace_id)) or (evidence_id is not null and exists(select 1 from public.evidence e join public.activity_instances ai on ai.id=activity_outputs.activity_instance_id where e.id=activity_outputs.evidence_id and e.project_id=ai.project_id and e.workspace_id=ai.workspace_id))));

create function private.guard_activity_evidence_link() returns trigger language plpgsql set search_path='' as $$
declare a public.activity_instances;e public.evidence;begin
 if tg_op<>'INSERT' then
  if old.evidence_id is not null then raise exception 'Evidence handoff history is immutable' using errcode='55000';end if;
  if tg_op='DELETE' then return old;end if;
 end if;
 if new.evidence_id is not null then
  select * into a from public.activity_instances where id=new.activity_instance_id for share;
  select * into e from public.evidence where id=new.evidence_id for share;
  if a.id is null or e.id is null or e.project_id<>a.project_id or e.workspace_id<>a.workspace_id then raise exception 'Invalid Evidence scope' using errcode='23514';end if;
 end if;return new;
end$$;
revoke all on function private.guard_activity_evidence_link() from public,anon,authenticated,service_role;
create trigger activity_inputs_evidence_history before insert or update or delete on public.activity_inputs for each row execute function private.guard_activity_evidence_link();
create trigger activity_outputs_evidence_history before insert or update or delete on public.activity_outputs for each row execute function private.guard_activity_evidence_link();
create function public.add_activity_evidence_output(target_instance uuid,target_evidence uuid) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;e public.evidence;r public.activity_outputs;begin
 a:=public.lock_activity_artifact_contribution(target_instance);
 
 select * into e from public.evidence where id=target_evidence for share;
 if e.id is null or e.archived_at is not null or e.project_id<>a.project_id or e.workspace_id<>a.workspace_id or not public.can_read_development_project(e.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('activity_outputs-evidence:'||a.id::text||':'||e.id::text,1219));
 a:=public.lock_activity_artifact_contribution(target_instance);
 select * into r from public.activity_outputs where activity_instance_id=a.id and evidence_id=e.id;
 if r.id is not null then return to_jsonb(r);end if;
 insert into public.activity_outputs(activity_instance_id,output_type,evidence_id) values(a.id,'evidence',e.id) returning * into r;
 return to_jsonb(r);end$$;
 revoke all on function public.add_activity_evidence_output(uuid,uuid) from public,anon,authenticated,service_role;
 grant execute on function public.add_activity_evidence_output(uuid,uuid) to authenticated;
create function public.add_activity_evidence_input(target_instance uuid,target_evidence uuid,is_required boolean) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;e public.evidence;r public.activity_inputs;begin
 a:=public.lock_activity_artifact_contribution(target_instance);
 if is_required is null then raise exception 'Invalid input' using errcode='22023';end if;
 select * into e from public.evidence where id=target_evidence for share;
 if e.id is null or e.archived_at is not null or e.project_id<>a.project_id or e.workspace_id<>a.workspace_id or not public.can_read_development_project(e.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('activity_inputs-evidence:'||a.id::text||':'||e.id::text,1219));
 a:=public.lock_activity_artifact_contribution(target_instance);
 select * into r from public.activity_inputs where activity_instance_id=a.id and evidence_id=e.id;
 if r.id is not null then if r.required is distinct from is_required then raise exception 'Input conflict' using errcode='23505';end if;return to_jsonb(r);end if;
 insert into public.activity_inputs(activity_instance_id,input_type,evidence_id,required) values(a.id,'evidence',e.id,is_required) returning * into r;
 return to_jsonb(r);end$$;
 revoke all on function public.add_activity_evidence_input(uuid,uuid,boolean) from public,anon,authenticated,service_role;
 grant execute on function public.add_activity_evidence_input(uuid,uuid,boolean) to authenticated;
comment on table public.activity_research_links is 'M12.19 canonical research IDs only. Reference is not an ACL; no copied metadata, verification or legal conclusion.';
commit;
