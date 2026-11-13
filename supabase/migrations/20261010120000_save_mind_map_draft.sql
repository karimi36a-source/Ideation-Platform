begin;
-- Explicit canonical checkpoint only. M11.13 has event-only transient state;
-- coordinates must first pass M11.9 node CAS, never a provider-room dump.
create function public.save_mind_map_draft(input jsonb) returns jsonb
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
 select * into init from private.mind_map_initializations where mind_map_id=m.id for share;
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
revoke all on function public.save_mind_map_draft(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.save_mind_map_draft(jsonb) to authenticated;
comment on function public.save_mind_map_draft(jsonb) is 'M11.14 explicit existing-Draft checkpoint. Current FICI scope and M8 draft_revision CAS; canonical node/edge state only. No new Version, Object/link synchronization, provider dump, autosave, approval or baseline mutation.';
commit;
