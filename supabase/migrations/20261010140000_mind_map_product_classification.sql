begin;
-- Product semantics have an independent CAS token; map positions remain visual.
alter table public.development_objects add column product_classification text
 check(product_classification in ('CORE','SUPPORTING','OPTIONAL_FUTURE')),
 add column classification_revision bigint not null default 0 check(classification_revision between 0 and 9007199254740991);
alter table public.mind_map_nodes add column product_classification text
 check(product_classification in ('CORE','SUPPORTING','OPTIONAL_FUTURE'));
comment on column public.development_objects.product_classification is 'Canonical CURRENT product classification. Null means unclassified. No lifecycle or authorization semantics.';
comment on column public.mind_map_nodes.product_classification is 'Map representation value. Current linked views resolve the canonical Object; saved Artifact snapshots retain captured values.';
create or replace function private.require_mind_map_node_edit(target uuid) returns public.activity_instances
language plpgsql volatile set search_path='' as $$
declare m public.mind_maps;b public.artifacts;v public.artifact_versions;a public.activity_instances;
begin
 select * into m from public.mind_maps where id=target;
 select * into b from public.artifacts where id=m.artifact_id;
 if b.activity_instance_id is null then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('mind-map-product:'||b.project_id::text,0));
 a:=private.require_mind_map_write(b.activity_instance_id);
 -- Serializes visual hierarchy validation, including concurrent cycle attempts.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('mind-map-node-edit:'||target::text,0));
 a:=private.require_mind_map_write(a.id);
 select * into m from public.mind_maps where id=target for share;
 select * into b from public.artifacts where id=m.artifact_id for share;
 select * into v from public.artifact_versions where id=m.artifact_version_id for share;
 if exists(select 1 from public.mind_maps later join public.artifact_versions lv on lv.id=later.artifact_version_id where later.artifact_id=b.id and lv.version_number>v.version_number) or m.id is null or b.artifact_type is distinct from 'MIND_MAP' or b.status is distinct from 'ACTIVE'
 or b.archived_at is not null or v.artifact_id is distinct from b.id or v.status is distinct from 'DRAFT'
 or (b.project_id,b.workspace_id,b.activity_instance_id) is distinct from (a.project_id,a.workspace_id,a.id)
 or not exists(select 1 from public.mind_map_nodes n where n.id=m.root_node_id and n.mind_map_id=m.id
  and n.node_type='CENTRAL_INVENTION' and n.parent_node_id is null and n.development_object_id is null)
 then raise exception 'Map not editable' using errcode='55000';end if;
 return a;
end $$;

-- Linking does not silently overwrite conflicting semantic values. Old maps are
-- never traversed/rewritten when a current Object classification changes.
create function private.mind_map_classification_link() returns trigger
language plpgsql set search_path='' as $$
declare o public.development_objects;
begin
 if tg_op='UPDATE' and new.development_object_id is not distinct from old.development_object_id then return new;end if;
 if new.development_object_id is null then
  if tg_op='UPDATE' and old.development_object_id is not null then
   select product_classification into new.product_classification from public.development_objects where id=old.development_object_id;
  end if;return new;end if;
 select * into o from public.development_objects where id=new.development_object_id for update;
 if not found then return new;end if; -- Leave missing references to the existing FK (23503); RPCs prevalidate access.
 if new.product_classification is not null and o.product_classification is not null and new.product_classification<>o.product_classification
 then raise exception 'Classification reconciliation required' using errcode='40001';end if;
 if o.product_classification is null and new.product_classification is not null then
  if not private.mind_map_scope_allowed(o.workspace_id,true) then raise exception 'Resource unavailable' using errcode='42501';end if;
  update public.development_objects set product_classification=new.product_classification,classification_revision=classification_revision+1,updated_at=clock_timestamp() where id=o.id;
  perform public.append_project_change(o.project_id,'DEVELOPMENT_OBJECT',o.id,'OBJECT_UPDATED');
 else new.product_classification:=o.product_classification;end if;
 return new;
end $$;
revoke all on function private.mind_map_classification_link() from public,anon,authenticated,service_role;
create trigger mind_map_classification_link before insert or update of development_object_id on public.mind_map_nodes
 for each row execute function private.mind_map_classification_link();

create function public.classify_mind_map_node(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;n public.mind_map_nodes;o public.development_objects;expected bigint;object_expected bigint;value0 text;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in('nodeId','expectedRevision','expectedObjectRevision','classification'))
 or jsonb_typeof(input->'nodeId') is distinct from 'string'
 or jsonb_typeof(input->'expectedRevision') is distinct from 'number'
 or (input->>'expectedRevision') !~ '^[0-9]+$' or (input->>'expectedRevision')::numeric>9007199254740991
 or not input ? 'expectedObjectRevision' or jsonb_typeof(input->'expectedObjectRevision') not in('number','null')
 or not input ? 'classification' or jsonb_typeof(input->'classification') not in('string','null')
 or (input->>'classification' is not null and input->>'classification' not in('CORE','SUPPORTING','OPTIONAL_FUTURE'))
 then raise exception 'Invalid classification input' using errcode='22023';end if;
 if input->>'expectedObjectRevision' is not null and ((input->>'expectedObjectRevision') !~ '^[0-9]+$' or (input->>'expectedObjectRevision')::numeric>9007199254740991)
 then raise exception 'Invalid classification revision' using errcode='22023';end if;
 expected:=(input->>'expectedRevision')::bigint;object_expected:=(input->>'expectedObjectRevision')::bigint;value0:=input->>'classification';
 select * into n from public.mind_map_nodes where id=(input->>'nodeId')::uuid;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_mind_map_node_edit(n.mind_map_id);
 select * into n from public.mind_map_nodes where id=n.id for update;
 if n.edit_revision<>expected then raise exception 'Node edit conflict' using errcode='40001';end if;
 if n.development_object_id is not null then
  select * into o from public.development_objects where id=n.development_object_id for update;
  if not found or o.archived_at is not null or (o.project_id,o.workspace_id) is distinct from (a.project_id,a.workspace_id)
  then raise exception 'Resource unavailable' using errcode='42501';end if;
  if object_expected is null or o.classification_revision<>object_expected then raise exception 'Object classification conflict' using errcode='40001';end if;
  if o.product_classification is distinct from value0 then
   update public.development_objects set product_classification=value0,classification_revision=classification_revision+1,updated_at=clock_timestamp() where id=o.id;
   perform public.append_project_change(o.project_id,'DEVELOPMENT_OBJECT',o.id,'OBJECT_UPDATED');
  end if;
 elsif object_expected is not null then raise exception 'Invalid Object revision' using errcode='22023';end if;
 if n.product_classification is distinct from value0 then
  update public.mind_map_nodes set product_classification=value0,edit_revision=edit_revision+1 where id=n.id returning * into n;
 end if;
 perform private.require_mind_map_node_edit(n.mind_map_id);
 return to_jsonb(n);
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Invalid input' using errcode='22023';end $$;
revoke all on function public.classify_mind_map_node(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.classify_mind_map_node(jsonb) to authenticated;
create or replace function private.mind_map_checkpoint_body(input jsonb) returns jsonb
language plpgsql volatile set search_path='' as $$
declare actor uuid:=public.current_platform_user_id(); a public.activity_instances;
 m public.mind_maps; v public.artifact_versions; n public.mind_map_nodes;
 e public.mind_map_edges; init private.mind_map_initializations; expected integer; body jsonb; saved jsonb; source0 jsonb;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in('mindMapId','expectedDraftRevision'))
 or jsonb_typeof(input->'mindMapId') is distinct from 'string'
 or jsonb_typeof(input->'expectedDraftRevision') is distinct from 'number'
 or (input->>'expectedDraftRevision') !~ '^[0-9]+$'
 or (input->>'expectedDraftRevision')::numeric>2147483647
 then raise exception 'Invalid input' using errcode='22023';end if;
 expected:=(input->>'expectedDraftRevision')::integer;
 -- Same scope locks and map advisory lock as every canonical node/edge edit.
 a:=private.require_mind_map_node_edit((input->>'mindMapId')::uuid);
 select * into m from public.mind_maps where id=(input->>'mindMapId')::uuid for share;
 select * into v from public.artifact_versions where id=m.artifact_version_id for share;
 select * into init from private.mind_map_initializations where activity_instance_id=a.id for share;
 if init.mind_map_id is null then raise exception 'Invalid initialization history' using errcode='55000';end if;
 if v.draft_revision<>expected then raise exception 'Stale Draft' using errcode='23505';end if;
 perform 1 from public.mind_map_nodes where mind_map_id=m.id order by id for share;
 perform 1 from public.mind_map_edges where mind_map_id=m.id order by id for share;
 if (select count(*) from public.mind_map_nodes where mind_map_id=m.id and node_type='CENTRAL_INVENTION')<>1
 or not exists(select 1 from public.mind_map_nodes where id=m.root_node_id and mind_map_id=m.id
  and node_type='CENTRAL_INVENTION' and parent_node_id is null and development_object_id is null)
 then raise exception 'Invalid canonical root' using errcode='55000';end if;
 for n in select * from public.mind_map_nodes where mind_map_id=m.id order by id loop
  if n.node_type not in('CENTRAL_INVENTION','SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP')
  or length(private.trim_decision_text(n.label)) not between 1 and 200
  or jsonb_typeof(n.position_data)<>'object' or jsonb_typeof(n.metadata)<>'object'
  then raise exception 'Invalid canonical node' using errcode='55000';end if;
  perform private.validate_mind_map_node_fields(jsonb_build_object('positionData',n.position_data,'label',n.label,'metadata',n.metadata));
  perform private.validate_mind_map_node_links(a,m.id,n.id,n.parent_node_id,n.development_object_id,n.node_type);
 end loop;
 if jsonb_typeof(v.content_snapshot)<>'object' or jsonb_typeof(coalesce(v.content_snapshot->'sources','[]'::jsonb))<>'array'
 then raise exception 'Invalid checkpoint provenance' using errcode='55000';end if;
 for source0 in select value from jsonb_array_elements(coalesce(v.content_snapshot->'sources','[]'::jsonb)) loop
  if jsonb_typeof(source0)<>'object' or exists(select 1 from jsonb_object_keys(source0) k where k not in('artifactType','artifactId','artifactVersionId'))
  or not exists(select 1 from public.artifacts s where s.id=(source0->>'artifactId')::uuid
   and s.artifact_type::text=source0->>'artifactType' and s.artifact_type in('INVENTION_STRUCTURE','GAP_LIST')
   and (s.project_id,s.workspace_id)=(a.project_id,a.workspace_id)
   and public.can_read_development_project(s.project_id)
   and (s.activity_instance_id is null or public.can_read_activity_instance(s.activity_instance_id))
   and (source0->>'artifactVersionId' is null or exists(select 1 from public.artifact_versions sv where sv.id=(source0->>'artifactVersionId')::uuid and sv.artifact_id=s.id)))
  then raise exception 'Invalid checkpoint provenance' using errcode='55000';end if;
 end loop;
 for e in select * from public.mind_map_edges where mind_map_id=m.id order by id loop
  if e.edge_type not in('HIERARCHY','CROSS_CONNECTION') or e.source_node_id=e.target_node_id
  or not exists(select 1 from public.mind_map_nodes where id=e.source_node_id and mind_map_id=m.id)
  or not exists(select 1 from public.mind_map_nodes where id=e.target_node_id and mind_map_id=m.id)
  or (e.edge_type='HIERARCHY' and not exists(select 1 from public.mind_map_nodes where id=e.target_node_id and mind_map_id=m.id and parent_node_id=e.source_node_id))
  or jsonb_typeof(e.metadata)<>'object'
  or (e.label is not null and length(private.trim_decision_text(e.label)) not between 1 and 200)
  then raise exception 'Invalid canonical edge' using errcode='55000';end if;
  -- Reuse M11.10 metadata/vocabulary/CAS checks as an identical no-op, so
  -- revisions and normalized rows stay unchanged while all edit rules apply.
  perform private.mutate_mind_map_edge(jsonb_build_object('edgeId',e.id,'expectedRevision',e.edit_revision,
   'edgeType',e.edge_type,'label',e.label,'metadata',e.metadata),'update');
 end loop;
 -- Preserve initialization/source provenance. Stable ordering and no save-time
 -- timestamp in the body make equivalent canonical state semantically equal.
 body:=jsonb_build_object('activityInstanceId',a.id,'projectId',a.project_id,'workspaceId',a.workspace_id,'teamId',a.team_id,
  'mindMapId',m.id,'rootNodeId',m.root_node_id,'initializedBy',init.initialized_by,
  'initializedAt',to_char(init.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'sources',coalesce(v.content_snapshot->'sources','[]'::jsonb),
  'nodes',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'nodeType',x.node_type,'label',x.label,
   'developmentObjectId',x.development_object_id,'parentNodeId',x.parent_node_id,'positionData',x.position_data,
   'productClassification',case when x.development_object_id is null then x.product_classification else (select o.product_classification from public.development_objects o where o.id=x.development_object_id) end,
   'metadata',x.metadata,'createdBy',x.created_by,'editRevision',x.edit_revision) order by x.id)
   from public.mind_map_nodes x where x.mind_map_id=m.id),'[]'::jsonb),
  'edges',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'sourceNodeId',x.source_node_id,'targetNodeId',x.target_node_id,
   'edgeType',x.edge_type,'label',x.label,'metadata',x.metadata,'editRevision',x.edit_revision) order by x.id)
   from public.mind_map_edges x where x.mind_map_id=m.id),'[]'::jsonb));
 return body;
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Invalid input' using errcode='22023';end $$;
create or replace function public.save_mind_map_draft(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id(); a public.activity_instances;
 m public.mind_maps; v public.artifact_versions; n public.mind_map_nodes;
 e public.mind_map_edges; init private.mind_map_initializations; expected integer; body jsonb; saved jsonb; source0 jsonb;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in('mindMapId','expectedDraftRevision'))
 or jsonb_typeof(input->'mindMapId') is distinct from 'string'
 or jsonb_typeof(input->'expectedDraftRevision') is distinct from 'number'
 or (input->>'expectedDraftRevision') !~ '^[0-9]+$'
 or (input->>'expectedDraftRevision')::numeric>2147483647
 then raise exception 'Invalid input' using errcode='22023';end if;
 expected:=(input->>'expectedDraftRevision')::integer;
 -- Same scope locks and map advisory lock as every canonical node/edge edit.
 a:=private.require_mind_map_node_edit((input->>'mindMapId')::uuid);
 select * into m from public.mind_maps where id=(input->>'mindMapId')::uuid for share;
 select * into v from public.artifact_versions where id=m.artifact_version_id for share;
 select * into init from private.mind_map_initializations where activity_instance_id=a.id for share;
 if init.mind_map_id is null then raise exception 'Invalid initialization history' using errcode='55000';end if;
 if v.draft_revision<>expected then raise exception 'Stale Draft' using errcode='23505';end if;
 update public.mind_map_nodes x set product_classification=o.product_classification,edit_revision=x.edit_revision+1
 from public.development_objects o where x.mind_map_id=m.id and o.id=x.development_object_id
 and x.product_classification is distinct from o.product_classification;
 perform 1 from public.mind_map_nodes where mind_map_id=m.id order by id for share;
 perform 1 from public.mind_map_edges where mind_map_id=m.id order by id for share;
 if (select count(*) from public.mind_map_nodes where mind_map_id=m.id and node_type='CENTRAL_INVENTION')<>1
 or not exists(select 1 from public.mind_map_nodes where id=m.root_node_id and mind_map_id=m.id
  and node_type='CENTRAL_INVENTION' and parent_node_id is null and development_object_id is null)
 then raise exception 'Invalid canonical root' using errcode='55000';end if;
 for n in select * from public.mind_map_nodes where mind_map_id=m.id order by id loop
  if n.node_type not in('CENTRAL_INVENTION','SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP')
  or length(private.trim_decision_text(n.label)) not between 1 and 200
  or jsonb_typeof(n.position_data)<>'object' or jsonb_typeof(n.metadata)<>'object'
  then raise exception 'Invalid canonical node' using errcode='55000';end if;
  perform private.validate_mind_map_node_fields(jsonb_build_object('positionData',n.position_data,'label',n.label,'metadata',n.metadata));
  perform private.validate_mind_map_node_links(a,m.id,n.id,n.parent_node_id,n.development_object_id,n.node_type);
 end loop;
 if jsonb_typeof(v.content_snapshot)<>'object' or jsonb_typeof(coalesce(v.content_snapshot->'sources','[]'::jsonb))<>'array'
 then raise exception 'Invalid checkpoint provenance' using errcode='55000';end if;
 for source0 in select value from jsonb_array_elements(coalesce(v.content_snapshot->'sources','[]'::jsonb)) loop
  if jsonb_typeof(source0)<>'object' or exists(select 1 from jsonb_object_keys(source0) k where k not in('artifactType','artifactId','artifactVersionId'))
  or not exists(select 1 from public.artifacts s where s.id=(source0->>'artifactId')::uuid
   and s.artifact_type::text=source0->>'artifactType' and s.artifact_type in('INVENTION_STRUCTURE','GAP_LIST')
   and (s.project_id,s.workspace_id)=(a.project_id,a.workspace_id)
   and public.can_read_development_project(s.project_id)
   and (s.activity_instance_id is null or public.can_read_activity_instance(s.activity_instance_id))
   and (source0->>'artifactVersionId' is null or exists(select 1 from public.artifact_versions sv where sv.id=(source0->>'artifactVersionId')::uuid and sv.artifact_id=s.id)))
  then raise exception 'Invalid checkpoint provenance' using errcode='55000';end if;
 end loop;
 for e in select * from public.mind_map_edges where mind_map_id=m.id order by id loop
  if e.edge_type not in('HIERARCHY','CROSS_CONNECTION') or e.source_node_id=e.target_node_id
  or not exists(select 1 from public.mind_map_nodes where id=e.source_node_id and mind_map_id=m.id)
  or not exists(select 1 from public.mind_map_nodes where id=e.target_node_id and mind_map_id=m.id)
  or (e.edge_type='HIERARCHY' and not exists(select 1 from public.mind_map_nodes where id=e.target_node_id and mind_map_id=m.id and parent_node_id=e.source_node_id))
  or jsonb_typeof(e.metadata)<>'object'
  or (e.label is not null and length(private.trim_decision_text(e.label)) not between 1 and 200)
  then raise exception 'Invalid canonical edge' using errcode='55000';end if;
  -- Reuse M11.10 metadata/vocabulary/CAS checks as an identical no-op, so
  -- revisions and normalized rows stay unchanged while all edit rules apply.
  perform private.mutate_mind_map_edge(jsonb_build_object('edgeId',e.id,'expectedRevision',e.edit_revision,
   'edgeType',e.edge_type,'label',e.label,'metadata',e.metadata),'update');
 end loop;
 -- Preserve initialization/source provenance. Stable ordering and no save-time
 -- timestamp in the body make equivalent canonical state semantically equal.
 body:=jsonb_build_object('activityInstanceId',a.id,'projectId',a.project_id,'workspaceId',a.workspace_id,'teamId',a.team_id,
  'mindMapId',m.id,'rootNodeId',m.root_node_id,'initializedBy',init.initialized_by,
  'initializedAt',to_char(init.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'sources',coalesce(v.content_snapshot->'sources','[]'::jsonb),
  'nodes',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'nodeType',x.node_type,'label',x.label,
   'developmentObjectId',x.development_object_id,'parentNodeId',x.parent_node_id,'positionData',x.position_data,
   'productClassification',case when x.development_object_id is null then x.product_classification else (select o.product_classification from public.development_objects o where o.id=x.development_object_id) end,
   'metadata',x.metadata,'createdBy',x.created_by,'editRevision',x.edit_revision) order by x.id)
   from public.mind_map_nodes x where x.mind_map_id=m.id),'[]'::jsonb),
  'edges',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'sourceNodeId',x.source_node_id,'targetNodeId',x.target_node_id,
   'edgeType',x.edge_type,'label',x.label,'metadata',x.metadata,'editRevision',x.edit_revision) order by x.id)
   from public.mind_map_edges x where x.mind_map_id=m.id),'[]'::jsonb));
 -- Reuse M8.20's real conditional write, counter and explicit no-op semantics.
 saved:=public.update_artifact_draft(v.id,expected,body);
 perform private.require_mind_map_node_edit(m.id);
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 return jsonb_build_object('mindMapId',m.id,'artifactVersionId',v.id,'draftRevision',(saved->>'draft_revision')::integer);
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Invalid input' using errcode='22023';
end $$;
create or replace function public.get_mind_map_editor(target_activity uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id(); a public.activity_instances;
 b public.artifacts; v public.artifact_versions; m public.mind_maps; editable boolean:=false;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';
 end if;
 if target_activity is null or not public.can_read_activity_instance(target_activity) then
  raise exception 'Resource unavailable' using errcode='42501';
 end if;
 select * into a from public.activity_instances where id=target_activity;
 select * into b from public.artifacts where activity_instance_id=a.id and artifact_type='MIND_MAP';
 select mm.* into m from public.mind_maps mm join public.artifact_versions vv on vv.id=mm.artifact_version_id where mm.artifact_id=b.id order by vv.version_number desc limit 1;
 select * into v from public.artifact_versions where id=m.artifact_version_id and artifact_id=b.id;
 if not private.mind_map_scope_allowed(b.workspace_id,false) or a.id is null or b.id is null or m.id is null or v.id is null or b.status<>'ACTIVE' or b.archived_at is not null
 or (b.project_id,b.workspace_id) is distinct from (a.project_id,a.workspace_id)
 or not exists(select 1 from public.mind_map_nodes n where n.id=m.root_node_id and n.mind_map_id=m.id and n.node_type='CENTRAL_INVENTION')
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 begin perform private.require_mind_map_node_edit(m.id); editable:=true;
 exception when others then editable:=false;end;
 if not public.can_read_activity_instance(a.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 return jsonb_build_object(
  'mindMap',to_jsonb(m),'nodes',coalesce((select jsonb_agg(to_jsonb(n)||jsonb_build_object('product_classification',case when n.development_object_id is null then n.product_classification else (select o.product_classification from public.development_objects o where o.id=n.development_object_id) end) order by n.id) from public.mind_map_nodes n where n.mind_map_id=m.id),'[]'::jsonb),
  'edges',coalesce((select jsonb_agg(to_jsonb(e) order by e.id) from public.mind_map_edges e where e.mind_map_id=m.id),'[]'::jsonb),
  'objects',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'object_type',o.object_type,'title',o.title,'product_classification',o.product_classification,'classification_revision',o.classification_revision) order by o.object_type,o.title,o.id)
   from public.development_objects o where o.project_id=a.project_id and o.workspace_id=a.workspace_id and o.archived_at is null
   and o.object_type::text in('SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP') and public.can_read_development_project(o.project_id)),'[]'::jsonb),
  'editable',editable);
end $$;
create or replace function public.create_mind_map_version(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id(); a public.activity_instances; m public.mind_maps; next_map public.mind_maps;
 v public.artifact_versions; made jsonb; body jsonb; ids jsonb:='{}'; n public.mind_map_nodes; e public.mind_map_edges; expected integer;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in('mindMapId','expectedDraftRevision','changeSummary'))
 or jsonb_typeof(input->'mindMapId') is distinct from 'string' or jsonb_typeof(input->'expectedDraftRevision') is distinct from 'number'
 or (input->>'expectedDraftRevision') !~ '^[0-9]+$' or (input->>'expectedDraftRevision')::numeric>2147483647
 or not input ? 'changeSummary' or jsonb_typeof(input->'changeSummary') not in ('string','null')
 then raise exception 'Invalid input' using errcode='22023';end if;
 expected:=(input->>'expectedDraftRevision')::integer;
 a:=private.require_mind_map_node_edit((input->>'mindMapId')::uuid);
 select * into m from public.mind_maps where id=(input->>'mindMapId')::uuid;
 select * into v from public.artifact_versions where id=m.artifact_version_id;
 body:=private.mind_map_checkpoint_body(jsonb_build_object('mindMapId',m.id,'expectedDraftRevision',expected));
 if body is distinct from v.content_snapshot then raise exception 'Save canonical Draft before checkpoint' using errcode='55000';end if;
 made:=public.create_artifact_version(m.artifact_id,body,input->>'changeSummary');
 insert into public.mind_maps(artifact_id,artifact_version_id) values(m.artifact_id,(made->>'id')::uuid) returning * into next_map;
 for n in select * from public.mind_map_nodes where mind_map_id=m.id order by id loop
  ids:=ids||jsonb_build_object(n.id::text,gen_random_uuid());
 end loop;
 for n in select * from public.mind_map_nodes where mind_map_id=m.id order by id loop
  insert into public.mind_map_nodes(id,mind_map_id,node_type,label,development_object_id,position_data,metadata,created_by,edit_revision,product_classification)
  values((ids->>n.id::text)::uuid,next_map.id,n.node_type,n.label,n.development_object_id,n.position_data,n.metadata,n.created_by,0,case when n.development_object_id is null then n.product_classification else (select o.product_classification from public.development_objects o where o.id=n.development_object_id) end);
 end loop;
 for n in select * from public.mind_map_nodes where mind_map_id=m.id and parent_node_id is not null loop
  update public.mind_map_nodes set parent_node_id=(ids->>n.parent_node_id::text)::uuid where id=(ids->>n.id::text)::uuid;
 end loop;
 update public.mind_maps set root_node_id=(ids->>m.root_node_id::text)::uuid where id=next_map.id returning * into next_map;
 for e in select * from public.mind_map_edges where mind_map_id=m.id order by id loop
  insert into public.mind_map_edges(mind_map_id,source_node_id,target_node_id,edge_type,label,metadata)
  values(next_map.id,(ids->>e.source_node_id::text)::uuid,(ids->>e.target_node_id::text)::uuid,e.edge_type,e.label,e.metadata);
 end loop;
 body:=private.mind_map_checkpoint_body(jsonb_build_object('mindMapId',next_map.id,'expectedDraftRevision',0));
 update public.artifact_versions set content_snapshot=body where id=(made->>'id')::uuid returning to_jsonb(artifact_versions.*) into made;
 perform private.require_mind_map_node_edit(next_map.id);
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 return jsonb_build_object('mindMap',to_jsonb(next_map),'version',made);
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Invalid input' using errcode='22023';
end $$;
commit;
