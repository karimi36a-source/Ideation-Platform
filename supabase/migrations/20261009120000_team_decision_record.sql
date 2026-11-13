begin;
-- Keep M8's implementation, but reserve this configured output for the narrow
-- composition operation. A generic Artifact RPC cannot spoof its source/flags.
alter function public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean) set schema private;
alter function private.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean) rename to create_artifact_initial_draft;
revoke all on function private.create_artifact_initial_draft(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean) from public,anon,authenticated,service_role;
create function public.create_artifact(target_project uuid,target_workspace uuid,kind public.artifact_type,artifact_title text,target_activity uuid,needs_review boolean,needs_approval boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if kind='TEAM_DECISION_RECORD' then raise exception 'Configured composition required' using errcode='55000';end if;
 return private.create_artifact_initial_draft(target_project,target_workspace,kind,artifact_title,target_activity,needs_review,needs_approval);
end $$;
revoke all on function public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean) from public,anon,authenticated,service_role;
grant execute on function public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean) to authenticated;
-- Exact initial-Version provenance is also the durable idempotency key. It is
-- never inferred from an editable Draft body or an Activity output list.
create table public.artifact_decision_sources (
 artifact_id uuid primary key references public.artifacts(id) on delete restrict,
 artifact_version_id uuid not null,
 decision_id uuid not null references public.decisions(id) on delete restrict,
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 foreign key(artifact_version_id,artifact_id) references public.artifact_versions(id,artifact_id) on delete restrict,
 unique(decision_id,activity_instance_id)
);
create index artifact_decision_sources_version on public.artifact_decision_sources(artifact_version_id);
alter table public.artifact_decision_sources enable row level security;
revoke all on public.artifact_decision_sources from public,anon,authenticated,service_role;
grant select on public.artifact_decision_sources to authenticated;
create policy artifact_decision_sources_read on public.artifact_decision_sources for select to authenticated using(
 exists(select 1 from public.artifact_versions v where v.id=artifact_version_id and v.artifact_id=artifact_decision_sources.artifact_id));
create policy artifact_decision_sources_read_guard on public.artifact_decision_sources as restrictive for select to authenticated using(
 exists(select 1 from public.artifact_versions v where v.id=artifact_version_id and v.artifact_id=artifact_decision_sources.artifact_id));
create policy artifact_decision_sources_write_deny on public.artifact_decision_sources as restrictive for all to authenticated using(
 exists(select 1 from public.artifact_versions v where v.id=artifact_version_id and v.artifact_id=artifact_decision_sources.artifact_id)) with check(false);
create function private.validate_artifact_decision_source() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op<>'INSERT' then raise exception 'Source history is immutable' using errcode='23514';end if;
 if not exists(select 1 from public.artifacts a join public.artifact_versions v on v.artifact_id=a.id
 join public.decisions d on d.id=new.decision_id
 where a.id=new.artifact_id and v.id=new.artifact_version_id and v.version_number=1
 and a.artifact_type='TEAM_DECISION_RECORD' and a.activity_instance_id=new.activity_instance_id
 and d.activity_instance_id=new.activity_instance_id and d.status='FINALIZED'
 and (a.project_id,a.workspace_id)=(d.project_id,d.workspace_id))
 then raise exception 'Invalid source context' using errcode='23514';end if;
 return new;
end $$;
revoke all on function private.validate_artifact_decision_source() from public,anon,authenticated,service_role;
create trigger artifact_decision_sources_history before insert or update or delete on public.artifact_decision_sources for each row execute function private.validate_artifact_decision_source();
alter table public.audit_events drop constraint audit_events_context_check;
alter table public.audit_events add constraint audit_events_context_check check (
 (event_type in ('TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED') and entity_type='team' and scope_type='team')
 or (event_type in ('REVISION_REQUESTED','ARTIFACT_APPROVED') and entity_type='submission' and scope_type='submission' and metadata='{}'::jsonb)
 or (event_type in ('ARTIFACT_REOPENED','PROBLEM_BANK_COMPOSED','SOLUTION_BANK_COMPOSED','TEAM_DECISION_RECORD_COMPOSED') and entity_type='artifact' and scope_type='artifact' and entity_id=scope_id and metadata='{}'::jsonb)
 or (event_type='BASELINE_UPDATED' and entity_type='project' and scope_type='project' and entity_id=scope_id and metadata='{}'::jsonb));
-- Protected composition only. All identity/scope comes from verified auth and
-- canonical records; fixed empty search_path and no service-role entry point.
create function public.create_team_decision_record_artifact(target_decision uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare d public.decisions;i public.activity_instances;a public.artifacts;v public.artifact_versions;
 s public.artifact_decision_sources;o public.development_objects;actor uuid;types jsonb;body jsonb;
 ids uuid[];object_id uuid;position integer:=0;created jsonb;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if target_decision is null then raise exception 'Invalid input' using errcode='22023';end if;
 -- Same lock order as finalization/supersession: Decision then canonical scope.
 select * into d from public.decisions where id=target_decision for update;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform private.require_decision_finalization(d.project_id,d.workspace_id,d.activity_instance_id,false);
 if not exists(select 1 from public.workspaces w where w.id=d.workspace_id and w.workspace_type='TEAM')
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 if d.status<>'FINALIZED' or d.activity_instance_id is null then raise exception 'Invalid Decision state' using errcode='55000';end if;
 select * into i from public.activity_instances where id=d.activity_instance_id for share;
 types:=i.configuration_snapshot#>'{configuration,outputs,artifact_types}';
 if jsonb_typeof(types) is distinct from 'array' then raise exception 'Output not applicable' using errcode='55000';end if;
 if not types @> '["TEAM_DECISION_RECORD"]'::jsonb
 or exists(select 1 from jsonb_array_elements(types) x where jsonb_typeof(x)<>'string' or not exists(select 1 from unnest(enum_range(null::public.artifact_type)) k where k::text=x#>>'{}'))
 or jsonb_typeof(i.configuration_snapshot->'requires_review') is distinct from 'boolean'
 or jsonb_typeof(i.configuration_snapshot->'requires_approval') is distinct from 'boolean'
 then raise exception 'Output not applicable' using errcode='55000';end if;
 select * into s from public.artifact_decision_sources where decision_id=d.id and activity_instance_id=i.id;
 if found then
  select * into a from public.artifacts where id=s.artifact_id for share;
  select * into v from public.artifact_versions where id=s.artifact_version_id for share;
  if a.status<>'ACTIVE' or a.archived_at is not null then raise exception 'Resource unavailable' using errcode='42501';end if;
  return jsonb_build_object('artifact',to_jsonb(a),'version',to_jsonb(v));
 end if;
 -- Registration is a new contribution: existing M7 lifecycle rules apply.
 i:=public.lock_activity_artifact_contribution(i.id);
 select coalesce(array_agg(distinct development_object_id order by development_object_id),'{}'::uuid[]) into ids
 from public.decision_options where decision_id=d.id and selected and development_object_id is not null;
 foreach object_id in array ids loop
  select * into o from public.development_objects where id=object_id for share;
  if o.id is null or o.archived_at is not null or (o.project_id,o.workspace_id) is distinct from (d.project_id,d.workspace_id)
  or not public.can_read_development_project(o.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 end loop;
 body:=jsonb_build_object('decision',jsonb_build_object('id',d.id,'title',d.title,'question',d.question,'method',d.method,'outcome',d.outcome,'reasoning',d.reasoning,'decidedAt',d.decided_at,'status',d.status),
 'options',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'label',x.label,'description',x.description,'selected',x.selected,'developmentObjectId',x.development_object_id) order by x.id) from public.decision_options x where x.decision_id=d.id),'[]'::jsonb),
 'participants',coalesce((select jsonb_agg(jsonb_build_object('userId',x.user_id,'role',x.role,'position',x.position,'comment',x.comment) order by x.user_id) from public.decision_participants x where x.decision_id=d.id),'[]'::jsonb),
 'references',jsonb_build_object('votingSessionIds',coalesce((select jsonb_agg(x.linked_entity_id order by x.linked_entity_id) from public.decision_links x where x.decision_id=d.id and x.linked_entity_type='VOTING_SESSION' and x.relationship_type='INFORMED_BY'),'[]'::jsonb)));
 created:=private.create_artifact_initial_draft(d.project_id,d.workspace_id,'TEAM_DECISION_RECORD','Team Decision Record — '||private.trim_decision_text(d.title),i.id,
 (i.configuration_snapshot->>'requires_review')::boolean,(i.configuration_snapshot->>'requires_approval')::boolean);
 select * into a from public.artifacts where id=(created->>'artifactId')::uuid;
 -- Initial composition is initialization, not a later Draft save; counter stays 0.
 update public.artifact_versions set content_snapshot=body where id=(created->>'initialVersionId')::uuid returning * into v;
 insert into public.artifact_decision_sources values(a.id,v.id,d.id,i.id);
 foreach object_id in array ids loop
  position:=position+1;
  insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence,role_in_artifact)
  values(a.id,v.id,object_id,position,'SELECTED_DECISION_OBJECT');
 end loop;
 perform public.add_activity_artifact_output(i.id,a.id);
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata)
 values(actor,'TEAM_DECISION_RECORD_COMPOSED','artifact',a.id,'artifact',a.id,'{}');
 return jsonb_build_object('artifact',to_jsonb(a),'version',to_jsonb(v));
end $$;
revoke all on function public.create_team_decision_record_artifact(uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_team_decision_record_artifact(uuid) to authenticated;
comment on table public.artifact_decision_sources is 'M10.13 immutable initial-Version source Decision and exact execution idempotency. Version RLS controls visibility; no Evidence/AI sources or generic client mutation.';
commit;
