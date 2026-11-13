begin;
-- Operation-local stable output identities and receipts, not a new product model.
create table private.session7_output_artifacts(
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 artifact_type public.artifact_type not null check(artifact_type in('MINIMUM_ESSENTIAL_STRUCTURE','INVENTION_CONCEPT')),
 artifact_id uuid not null unique references public.artifacts(id) on delete restrict,
 primary key(activity_instance_id,artifact_type)
);
create table private.session7_compositions(
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 mind_map_id uuid not null references public.mind_maps(id) on delete restrict,
 successor_mind_map_id uuid not null references public.mind_maps(id) on delete restrict,
 source_version_id uuid not null references public.artifact_versions(id) on delete restrict,
 source_draft_revision integer not null check(source_draft_revision>=0),
 payload jsonb not null,
 essential_version_id uuid not null references public.artifact_versions(id) on delete restrict,
 concept_version_id uuid not null references public.artifact_versions(id) on delete restrict,
 mind_map_output_id uuid not null references public.activity_outputs(id) on delete restrict,
 essential_output_id uuid not null references public.activity_outputs(id) on delete restrict,
 concept_output_id uuid not null references public.activity_outputs(id) on delete restrict,
 created_by uuid not null references public.users(id) on delete restrict,
 created_at timestamptz not null default clock_timestamp(),
 unique(source_version_id,source_draft_revision)
);
create table private.session7_composition_requests(
 actor_id uuid not null references public.users(id) on delete restrict,
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 idempotency_key text not null check(length(btrim(idempotency_key)) between 1 and 200),
 payload jsonb not null,
 composition_id uuid not null references private.session7_compositions(id) on delete restrict,
 primary key(actor_id,activity_instance_id,idempotency_key)
);
alter table private.session7_output_artifacts enable row level security;
alter table private.session7_compositions enable row level security;
alter table private.session7_composition_requests enable row level security;
revoke all on private.session7_output_artifacts,private.session7_compositions,private.session7_composition_requests from public,anon,authenticated,service_role;

-- Private invention outputs do not inherit instructional role-only content access.
create function public.can_read_session7_output(target_artifact uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.artifacts a where a.id=target_artifact
 and public.can_read_development_project(a.project_id)
 and (not exists(select 1 from private.session7_output_artifacts r where r.artifact_id=a.id)
 or private.mind_map_scope_allowed(a.workspace_id,false)));
$$;
revoke all on function public.can_read_session7_output(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_session7_output(uuid) to authenticated;
create policy session7_artifact_privacy on public.artifacts as restrictive for select to authenticated
 using(artifact_type not in('MINIMUM_ESSENTIAL_STRUCTURE','INVENTION_CONCEPT') or public.can_read_session7_output(id));

-- A later composition freezes prior generated Draft bodies without a new status.
create function private.preserve_session7_history() returns trigger language plpgsql set search_path='' as $$
begin
 if (new.content_snapshot,new.draft_revision) is distinct from (old.content_snapshot,old.draft_revision)
 and exists(select 1 from private.session7_output_artifacts r where r.artifact_id=old.artifact_id)
 and exists(select 1 from public.artifact_versions v where v.artifact_id=old.artifact_id and v.version_number>old.version_number)
 then raise exception 'Historical Session 7 output is immutable' using errcode='55000';end if;
 return new;
end $$;
revoke all on function private.preserve_session7_history() from public,anon,authenticated,service_role;
create trigger session7_output_history before update on public.artifact_versions for each row execute function private.preserve_session7_history();

create function private.session7_composition_result(target uuid,replayed boolean) returns jsonb
language plpgsql stable set search_path='' as $$
declare c private.session7_compositions;result jsonb;entry jsonb;b public.artifacts;v public.artifact_versions;o public.activity_outputs;
begin
 select * into c from private.session7_compositions where id=target;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 result:=jsonb_build_object('mindMapId',c.mind_map_id,'successorMindMapId',c.successor_mind_map_id,'sourceDraftRevision',c.source_draft_revision,'replayed',replayed);
 for entry in select value from jsonb_array_elements(jsonb_build_array(
  jsonb_build_object('key','mindMap','version',c.source_version_id,'output',c.mind_map_output_id,'type','MIND_MAP'),
  jsonb_build_object('key','essentialStructure','version',c.essential_version_id,'output',c.essential_output_id,'type','MINIMUM_ESSENTIAL_STRUCTURE'),
  jsonb_build_object('key','inventionConcept','version',c.concept_version_id,'output',c.concept_output_id,'type','INVENTION_CONCEPT'))) loop
  select * into v from public.artifact_versions where id=(entry->>'version')::uuid;
  select * into b from public.artifacts where id=v.artifact_id;
  select * into o from public.activity_outputs where id=(entry->>'output')::uuid;
  if b.id is null or b.status<>'ACTIVE' or b.archived_at is not null or b.activity_instance_id is distinct from c.activity_instance_id
  or b.artifact_type::text is distinct from entry->>'type' or o.activity_instance_id is distinct from c.activity_instance_id
  or o.artifact_id is distinct from b.id or o.output_type is distinct from 'artifact'
  then raise exception 'Resource unavailable' using errcode='42501';end if;
  result:=result||jsonb_build_object(entry->>'key',jsonb_build_object('artifact',to_jsonb(b),'version',to_jsonb(v),'activityOutputId',o.id));
 end loop;
 return result;
end $$;
revoke all on function private.session7_composition_result(uuid,boolean) from public,anon,authenticated,service_role;

create function public.finalize_session7_outputs(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;m public.mind_maps;v public.artifact_versions;
 c private.session7_compositions;r private.session7_composition_requests;intent jsonb;key text;body jsonb;types jsonb;
 object_ids uuid[];core_ids uuid[];context_ids uuid[];node_ids uuid[];rels jsonb;objects jsonb;essential_objects jsonb;context_objects jsonb;
 essential_body jsonb;concept_body jsonb;source0 jsonb;kind public.artifact_type;b public.artifacts;made jsonb;
 essential_version uuid;concept_version uuid;map_output uuid;essential_output uuid;concept_output uuid;oid uuid;position integer;checkpoint jsonb;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in('activityInstanceId','mindMapId','expectedDraftRevision','changeSummary','idempotencyKey'))
 or jsonb_typeof(input->'activityInstanceId') is distinct from 'string' or jsonb_typeof(input->'mindMapId') is distinct from 'string'
 or jsonb_typeof(input->'expectedDraftRevision') is distinct from 'number' or (input->>'expectedDraftRevision') !~ '^[0-9]+$'
 or (input->>'expectedDraftRevision')::numeric>2147483647 or jsonb_typeof(input->'idempotencyKey') is distinct from 'string'
 or length(private.trim_decision_text(input->>'idempotencyKey')) not between 1 and 200
 or (input ? 'changeSummary' and jsonb_typeof(input->'changeSummary') not in('string','null'))
 then raise exception 'Invalid input' using errcode='22023';end if;
 intent:=jsonb_build_object('activityInstanceId',(input->>'activityInstanceId')::uuid,'mindMapId',(input->>'mindMapId')::uuid,
  'expectedDraftRevision',(input->>'expectedDraftRevision')::integer,'changeSummary',input->>'changeSummary');
 key:=private.trim_decision_text(input->>'idempotencyKey');
 -- Current authority is checked before any receipt can reveal historical results.
 if not public.can_read_activity_instance((intent->>'activityInstanceId')::uuid) then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into m from public.mind_maps where id=(intent->>'mindMapId')::uuid;
 select * into b from public.artifacts where id=m.artifact_id;
 if b.id is null or b.activity_instance_id is distinct from (intent->>'activityInstanceId')::uuid then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Match M11.16 editor ordering: product lock precedes Activity/scope locks.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('mind-map-product:'||b.project_id::text,0));
 a:=private.require_mind_map_write((intent->>'activityInstanceId')::uuid);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('session7-output:'||a.id::text,0));
 a:=private.require_mind_map_write(a.id);
 select * into m from public.mind_maps where id=(intent->>'mindMapId')::uuid;
 -- Generic M8 appends/updates use this parent lock too. Acquire it before
 -- reading the Version token or testing newestness, not after either check.
 perform 1 from public.artifacts where id=m.artifact_id for share;
 select * into v from public.artifact_versions where id=m.artifact_version_id;
 if not exists(select 1 from public.artifacts source_artifact where source_artifact.id=m.artifact_id and source_artifact.artifact_type='MIND_MAP' and source_artifact.status='ACTIVE'
  and source_artifact.archived_at is null and (source_artifact.activity_instance_id,source_artifact.project_id,source_artifact.workspace_id)=(a.id,a.project_id,a.workspace_id))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 types:=a.configuration_snapshot#>'{configuration,outputs,artifact_types}';
 if jsonb_typeof(types) is distinct from 'array' or not types @> '["MIND_MAP","MINIMUM_ESSENTIAL_STRUCTURE","INVENTION_CONCEPT"]'
 then raise exception 'Session 7 outputs not configured' using errcode='55000';end if;
 select * into r from private.session7_composition_requests where actor_id=actor and activity_instance_id=a.id and idempotency_key=key;
 if found then
  if r.payload<>intent then raise exception 'Composition conflict' using errcode='23505';end if;
  return private.session7_composition_result(r.composition_id,true);
 end if;
 select * into c from private.session7_compositions where source_version_id=v.id and source_draft_revision=(intent->>'expectedDraftRevision')::integer;
 if found then
  if c.payload<>intent then raise exception 'Composition conflict' using errcode='23505';end if;
  insert into private.session7_composition_requests values(actor,a.id,key,intent,c.id);
  return private.session7_composition_result(c.id,true);
 end if;
 if exists(select 1 from public.artifact_versions later where later.artifact_id=m.artifact_id and later.version_number>v.version_number)
 then raise exception 'Stale Mind Map Version' using errcode='23505';end if;
 a:=private.require_mind_map_node_edit(m.id);
 body:=private.mind_map_checkpoint_body(jsonb_build_object('mindMapId',m.id,'expectedDraftRevision',(intent->>'expectedDraftRevision')::integer));
 if body is distinct from v.content_snapshot then raise exception 'Save canonical Draft before composition' using errcode='23505';end if;
 -- Freeze the canonical Object values while deriving both representations.
 select coalesce(array_agg(distinct (n->>'developmentObjectId')::uuid order by (n->>'developmentObjectId')::uuid),'{}') into object_ids
 from jsonb_array_elements(body->'nodes') n where n->>'developmentObjectId' is not null;
 perform 1 from public.development_objects where id=any(object_ids) order by id for share;
 if exists(select 1 from unnest(object_ids) x where not exists(select 1 from public.development_objects o where o.id=x
  and (o.project_id,o.workspace_id)=(a.project_id,a.workspace_id) and o.archived_at is null))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Re-evaluate after Object locks, including canonical classification races.
 if private.mind_map_checkpoint_body(jsonb_build_object('mindMapId',m.id,'expectedDraftRevision',v.draft_revision)) is distinct from body
 then raise exception 'Canonical state changed' using errcode='23505';end if;
 select coalesce(array_agg(id order by id),'{}') into core_ids from public.development_objects where id=any(object_ids) and product_classification='CORE';
 perform 1 from public.development_object_relationships where project_id=a.project_id and source_object_id=any(object_ids) and target_object_id=any(object_ids) order by id for share;
 select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'sourceObjectId',x.source_object_id,'targetObjectId',x.target_object_id,'relationshipType',x.relationship_type) order by x.id),'[]') into rels
 from public.development_object_relationships x where x.project_id=a.project_id and x.status='active' and x.source_object_id=any(object_ids) and x.target_object_id=any(object_ids);
 -- Existing CORE-bound canonical connections and their parent paths supply
 -- labeled context only. They never infer CORE membership or expand transitively
 -- across the entire supporting/optional graph. The visual root remains context.
 with recursive ancestry(id,parent) as (
  select (n->>'id')::uuid,(n->>'parentNodeId')::uuid from jsonb_array_elements(body->'nodes') n where (n->>'developmentObjectId')::uuid=any(core_ids)
   or exists(select 1 from jsonb_array_elements(rels) edge where ((edge->>'sourceObjectId')::uuid=any(core_ids) and edge->>'targetObjectId'=n->>'developmentObjectId') or ((edge->>'targetObjectId')::uuid=any(core_ids) and edge->>'sourceObjectId'=n->>'developmentObjectId'))
  union
  select (n->>'id')::uuid,(n->>'parentNodeId')::uuid from jsonb_array_elements(body->'nodes') n join ancestry p on (n->>'id')::uuid=p.parent
 ) select coalesce(array_agg(id order by id),'{}') into node_ids from ancestry;
 node_ids:=array_append(node_ids,m.root_node_id);
 select coalesce(array_agg(distinct (n->>'developmentObjectId')::uuid order by (n->>'developmentObjectId')::uuid),'{}') into context_ids
 from jsonb_array_elements(body->'nodes') n where (n->>'id')::uuid=any(node_ids) and n->>'developmentObjectId' is not null and not (n->>'developmentObjectId')::uuid=any(core_ids);
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'objectType',o.object_type,'title',o.title,'productClassification',o.product_classification) order by o.id),'[]') into objects from public.development_objects o where o.id=any(object_ids);
 select coalesce(jsonb_agg(x order by x->>'id'),'[]') into essential_objects from jsonb_array_elements(objects) x where (x->>'id')::uuid=any(core_ids);
 select coalesce(jsonb_agg(x||'{"essential":false}'::jsonb order by x->>'id'),'[]') into context_objects from jsonb_array_elements(objects) x where (x->>'id')::uuid=any(context_ids);
 source0:=jsonb_build_object('activityInstanceId',a.id,'mindMapId',m.id,'mindMapArtifactId',m.artifact_id,'mindMapVersionId',v.id,'sourceDraftRevision',v.draft_revision);
 essential_body:=source0||jsonb_build_object('rootNodeId',m.root_node_id,'objects',essential_objects,'contextObjects',context_objects,
  'nodes',coalesce((select jsonb_agg(n order by n->>'id') from jsonb_array_elements(body->'nodes') n where (n->>'id')::uuid=any(node_ids)),'[]'::jsonb),
  'edges',coalesce((select jsonb_agg(e order by e->>'id') from jsonb_array_elements(body->'edges') e where (e->>'sourceNodeId')::uuid=any(node_ids) and (e->>'targetNodeId')::uuid=any(node_ids)),'[]'::jsonb),
  'relationships',coalesce((select jsonb_agg(e order by e->>'id') from jsonb_array_elements(rels) e where (e->>'sourceObjectId')::uuid=any(core_ids||context_ids) and (e->>'targetObjectId')::uuid=any(core_ids||context_ids)),'[]'::jsonb));
 concept_body:=source0||jsonb_build_object('objects',objects,'essentialObjectIds',to_jsonb(core_ids),'relationships',rels,'mindMap',body);
 foreach kind in array array['MINIMUM_ESSENTIAL_STRUCTURE'::public.artifact_type,'INVENTION_CONCEPT'::public.artifact_type] loop
  select x.* into b from private.session7_output_artifacts output_registry join public.artifacts x on x.id=output_registry.artifact_id where output_registry.activity_instance_id=a.id and output_registry.artifact_type=kind for update of x;
  if not found then
   insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by,activity_instance_id,review_required,approval_required)
   values(a.project_id,a.workspace_id,kind,case when kind='INVENTION_CONCEPT' then 'Invention Concept' else 'Minimum Essential Invention Structure' end,actor,a.id,(a.configuration_snapshot->>'requires_review')::boolean,(a.configuration_snapshot->>'requires_approval')::boolean) returning * into b;
   insert into private.session7_output_artifacts values(a.id,kind,b.id);
  elsif b.status<>'ACTIVE' or b.archived_at is not null or (b.project_id,b.workspace_id,b.activity_instance_id) is distinct from (a.project_id,a.workspace_id,a.id)
   or b.review_required is distinct from (a.configuration_snapshot->>'requires_review')::boolean or b.approval_required is distinct from (a.configuration_snapshot->>'requires_approval')::boolean
   then raise exception 'Resource unavailable' using errcode='42501';end if;
  made:=public.create_artifact_version(b.id,case when kind='INVENTION_CONCEPT' then concept_body else essential_body end,intent->>'changeSummary');
  position:=0;
  for oid in select id from unnest(case when kind='INVENTION_CONCEPT' then object_ids else core_ids||context_ids end) id order by id loop
   position:=position+1;
   insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence,role_in_artifact,metadata)
   values(b.id,(made->>'id')::uuid,oid,position,case when kind='INVENTION_CONCEPT' then 'concept' when oid=any(core_ids) then 'essential' else 'context' end,
    jsonb_build_object('sourceMindMapId',m.id,'sourceMindMapVersionId',v.id,'essential',kind<>'INVENTION_CONCEPT' and oid=any(core_ids)));
  end loop;
  if kind='INVENTION_CONCEPT' then concept_version:=(made->>'id')::uuid;concept_output:=(public.add_activity_artifact_output(a.id,b.id)->>'id')::uuid;
  else essential_version:=(made->>'id')::uuid;essential_output:=(public.add_activity_artifact_output(a.id,b.id)->>'id')::uuid;end if;
 end loop;
 select coalesce(max(sequence),0) into position from public.artifact_object_links where artifact_version_id=v.id;
 for oid in select refs.id from unnest(object_ids) refs(id) where not exists(select 1 from public.artifact_object_links l where l.artifact_version_id=v.id and l.development_object_id=refs.id) order by refs.id loop
  position:=position+1;
  insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence,role_in_artifact,metadata)
  values(m.artifact_id,v.id,oid,position,'mind_map',jsonb_build_object('sourceMindMapId',m.id));
 end loop;
 map_output:=(public.add_activity_artifact_output(a.id,m.artifact_id)->>'id')::uuid;
 perform private.require_mind_map_node_edit(m.id);
 -- Freeze the captured map through the accepted M11.15 checkpoint operation.
 -- Its successor stays DRAFT/editable; neither Version becomes CURRENT.
 checkpoint:=public.create_mind_map_version(jsonb_build_object('mindMapId',m.id,'expectedDraftRevision',v.draft_revision,'changeSummary',intent->>'changeSummary'));
 perform private.require_mind_map_node_edit((checkpoint#>>'{mindMap,id}')::uuid);
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 insert into private.session7_compositions(activity_instance_id,mind_map_id,successor_mind_map_id,source_version_id,source_draft_revision,payload,essential_version_id,concept_version_id,mind_map_output_id,essential_output_id,concept_output_id,created_by)
 values(a.id,m.id,(checkpoint#>>'{mindMap,id}')::uuid,v.id,v.draft_revision,intent,essential_version,concept_version,map_output,essential_output,concept_output,actor) returning * into c;
 insert into private.session7_composition_requests values(actor,a.id,key,intent,c.id);
 return private.session7_composition_result(c.id,false);
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Invalid input' using errcode='22023';
end $$;
revoke all on function public.finalize_session7_outputs(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.finalize_session7_outputs(jsonb) to authenticated;
create or replace function public.add_activity_artifact_output(target_instance uuid,target_artifact uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare i public.activity_instances;a public.artifacts;result public.activity_outputs;types jsonb;
begin
 i:=public.lock_activity_artifact_contribution(target_instance);
 select * into a from public.artifacts where id=target_artifact for share;
 if a.id is null or a.status<>'ACTIVE' or a.archived_at is not null or a.project_id<>i.project_id or a.workspace_id<>i.workspace_id
 or a.activity_instance_id is distinct from i.id or not public.can_read_development_project(a.project_id)
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fici-artifact-output:'||i.id::text||':'||a.id::text,814));
 i:=public.lock_activity_artifact_contribution(target_instance);
 if i.configuration_snapshot->>'method_type' in('affinity','mind_map') then
  types:=i.configuration_snapshot#>'{configuration,outputs,artifact_types}';
  if types is null or jsonb_typeof(types) is distinct from 'array' then
   raise exception 'Resource unavailable' using errcode='42501';
  end if;
  if exists(select 1 from jsonb_array_elements(types) x where jsonb_typeof(x)<>'string'
   or not exists(select 1 from unnest(enum_range(null::public.artifact_type)) k where k::text=x#>>'{}')) then
   raise exception 'Invalid output configuration' using errcode='55000';
  end if;
  if not types @> jsonb_build_array(a.artifact_type::text) then
   raise exception 'Resource unavailable' using errcode='42501';
  end if;
 end if;
 select * into result from public.activity_outputs where activity_instance_id=i.id and artifact_id=a.id and output_type='artifact';
 if result.id is not null then return to_jsonb(result);end if;
 insert into public.activity_outputs(activity_instance_id,output_type,artifact_id) values(i.id,'artifact',a.id) returning * into result;
 return to_jsonb(result);
end $$;
revoke all on function public.add_activity_artifact_output(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.add_activity_artifact_output(uuid,uuid) to authenticated;
comment on function public.add_activity_artifact_output(uuid,uuid) is 'Canonical scope-bound Artifact output registration. Affinity and Mind Map outputs require the exact Artifact type in the immutable execution snapshot configuration.outputs.artifact_types; retries preserve the stable output identity.';
commit;
