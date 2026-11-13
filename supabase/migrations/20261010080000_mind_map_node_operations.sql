begin;
alter table public.mind_map_nodes add column edit_revision bigint not null default 0
 check(edit_revision between 0 and 9007199254740991);
-- Invoker helpers are reachable only through the two controlled RPCs below.
create function private.require_mind_map_node_edit(target uuid) returns public.activity_instances
language plpgsql volatile set search_path='' as $$
declare m public.mind_maps;b public.artifacts;v public.artifact_versions;a public.activity_instances;
begin
 select * into m from public.mind_maps where id=target;
 select * into b from public.artifacts where id=m.artifact_id;
 if b.activity_instance_id is null then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_mind_map_write(b.activity_instance_id);
 -- Serializes visual hierarchy validation, including concurrent cycle attempts.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('mind-map-node-edit:'||target::text,0));
 a:=private.require_mind_map_write(a.id);
 select * into m from public.mind_maps where id=target for share;
 select * into b from public.artifacts where id=m.artifact_id for share;
 select * into v from public.artifact_versions where id=m.artifact_version_id for share;
 if m.id is null or b.artifact_type is distinct from 'MIND_MAP' or b.status is distinct from 'ACTIVE'
 or b.archived_at is not null or v.artifact_id is distinct from b.id or v.status is distinct from 'DRAFT'
 or (b.project_id,b.workspace_id,b.activity_instance_id) is distinct from (a.project_id,a.workspace_id,a.id)
 or not exists(select 1 from public.mind_map_nodes n where n.id=m.root_node_id and n.mind_map_id=m.id
  and n.node_type='CENTRAL_INVENTION' and n.parent_node_id is null and n.development_object_id is null)
 then raise exception 'Map not editable' using errcode='55000';end if;
 return a;
end $$;
create function private.validate_mind_map_node_fields(input jsonb) returns void
language plpgsql immutable set search_path='' as $$
begin
 if (input ? 'label' and (jsonb_typeof(input->'label') is distinct from 'string' or length(private.trim_decision_text(input->>'label')) not between 1 and 200))
 or (input ? 'positionData' and jsonb_typeof(input->'positionData') is distinct from 'object')
 or (input ? 'metadata' and jsonb_typeof(input->'metadata') is distinct from 'object')
 or (input ? 'parentNodeId' and jsonb_typeof(input->'parentNodeId') not in ('string','null'))
 or (input ? 'developmentObjectId' and jsonb_typeof(input->'developmentObjectId') not in ('string','null'))
 then raise exception 'Invalid node fields' using errcode='22023';end if;
 if input ? 'metadata' and exists(select 1 from jsonb_object_keys(input->'metadata') k
 where lower(replace(k,'_','')) in ('projectid','workspaceid','teamid','artifactid','artifactversionid','mindmapid','rootnodeid','nodeid','nodetype','developmentobjectid','createdby','creator','actor','userid','owneruserid','status','approvalstate','approved','authorization','scope','editrevision'))
 then raise exception 'Reserved metadata field' using errcode='22023';end if;
end $$;
create function private.validate_mind_map_node_links(a public.activity_instances,map_id uuid,node_id uuid,parent_id uuid,object_id uuid,kind text) returns void
language plpgsql volatile set search_path='' as $$
declare o public.development_objects;
begin
 if parent_id is not null then
  if parent_id=node_id then raise exception 'Invalid parent' using errcode='22023';end if;
  if not exists(select 1 from public.mind_map_nodes where id=parent_id and mind_map_id=map_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
  if exists(with recursive ancestors as(select id,parent_node_id,array[id] path from public.mind_map_nodes where id=parent_id and mind_map_id=map_id
   union all select p.id,p.parent_node_id,c.path||p.id from public.mind_map_nodes p join ancestors c on p.id=c.parent_node_id where p.mind_map_id=map_id and not p.id=any(c.path))
   select 1 from ancestors where id=node_id) then raise exception 'Invalid hierarchy' using errcode='22023';end if;
 end if;
 if object_id is not null then
  select * into o from public.development_objects where id=object_id for share;
  if not found or o.archived_at is not null or (o.project_id,o.workspace_id) is distinct from (a.project_id,a.workspace_id)
   or not public.can_read_development_project(o.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
  if o.object_type::text<>kind then raise exception 'Incompatible Object type' using errcode='22023';end if;
 end if;
end $$;
create function public.add_mind_map_node(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;n public.mind_map_nodes;map_id uuid;kind text;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in('mindMapId','nodeType','label','parentNodeId','developmentObjectId','positionData','metadata'))
 or jsonb_typeof(input->'mindMapId') is distinct from 'string' or jsonb_typeof(input->'nodeType') is distinct from 'string'
 or not input ? 'label' or not input ? 'positionData'
 then raise exception 'Invalid input' using errcode='22023';end if;
 perform private.validate_mind_map_node_fields(input);
 map_id:=(input->>'mindMapId')::uuid;kind:=input->>'nodeType';
 if kind not in('SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP') then raise exception 'Invalid node type' using errcode='22023';end if;
 a:=private.require_mind_map_node_edit(map_id);
 perform private.validate_mind_map_node_links(a,map_id,null,(input->>'parentNodeId')::uuid,(input->>'developmentObjectId')::uuid,kind);
 insert into public.mind_map_nodes(mind_map_id,node_type,label,parent_node_id,development_object_id,position_data,metadata,created_by)
 values(map_id,kind,private.trim_decision_text(input->>'label'),(input->>'parentNodeId')::uuid,(input->>'developmentObjectId')::uuid,input->'positionData',coalesce(input->'metadata','{}'),actor) returning * into n;
 perform private.require_mind_map_node_edit(map_id);
 return to_jsonb(n);
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Invalid input' using errcode='22023';
end $$;
create function public.update_mind_map_node(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;n public.mind_map_nodes;next0 public.mind_map_nodes;m public.mind_maps;expected bigint;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in('nodeId','expectedRevision','label','parentNodeId','developmentObjectId','positionData','metadata'))
 or jsonb_typeof(input->'nodeId') is distinct from 'string' or jsonb_typeof(input->'expectedRevision') is distinct from 'number'
 or (input->>'expectedRevision') !~ '^[0-9]+$' or (input->>'expectedRevision')::numeric>9007199254740991
 or not (input ?| array['label','parentNodeId','developmentObjectId','positionData','metadata'])
 then raise exception 'Invalid input' using errcode='22023';end if;
 perform private.validate_mind_map_node_fields(input);expected:=(input->>'expectedRevision')::bigint;
 select * into n from public.mind_map_nodes where id=(input->>'nodeId')::uuid;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_mind_map_node_edit(n.mind_map_id);
 select * into n from public.mind_map_nodes where id=n.id for update;
 if n.edit_revision<>expected then raise exception 'Node edit conflict' using errcode='40001';end if;
 next0:=n;
 if input ? 'label' then next0.label:=private.trim_decision_text(input->>'label');end if;
 if input ? 'positionData' then next0.position_data:=input->'positionData';end if;
 if input ? 'metadata' then next0.metadata:=input->'metadata';end if;
 if input ? 'parentNodeId' then next0.parent_node_id:=(input->>'parentNodeId')::uuid;end if;
 if input ? 'developmentObjectId' then next0.development_object_id:=(input->>'developmentObjectId')::uuid;end if;
 select * into m from public.mind_maps where id=n.mind_map_id;
 if n.id=m.root_node_id or n.node_type='CENTRAL_INVENTION' then
  if input ? 'parentNodeId' or n.id is distinct from m.root_node_id or n.node_type<>'CENTRAL_INVENTION' or next0.parent_node_id is not null or next0.development_object_id is not null
   then raise exception 'Invalid root edit' using errcode='22023';end if;
  next0.metadata:=next0.metadata||'{"role":"central_invention"}';
 elsif n.node_type not in('SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP') then raise exception 'Unsupported node type' using errcode='22023';end if;
 perform private.validate_mind_map_node_links(a,n.mind_map_id,n.id,next0.parent_node_id,next0.development_object_id,n.node_type);
 if (next0.label,next0.parent_node_id,next0.development_object_id,next0.position_data,next0.metadata)
 is not distinct from (n.label,n.parent_node_id,n.development_object_id,n.position_data,n.metadata) then perform private.require_mind_map_node_edit(n.mind_map_id);return to_jsonb(n);end if;
 if n.edit_revision>=9007199254740991 then raise exception 'Revision exhausted' using errcode='55000';end if;
 update public.mind_map_nodes set label=next0.label,parent_node_id=next0.parent_node_id,development_object_id=next0.development_object_id,
 position_data=next0.position_data,metadata=next0.metadata,edit_revision=edit_revision+1 where id=n.id and edit_revision=expected returning * into n;
 if not found then raise exception 'Node edit conflict' using errcode='40001';end if;
 perform private.require_mind_map_node_edit(n.mind_map_id);
 return to_jsonb(n);
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Invalid input' using errcode='22023';
end $$;
revoke all on function private.require_mind_map_node_edit(uuid),private.validate_mind_map_node_fields(jsonb),private.validate_mind_map_node_links(public.activity_instances,uuid,uuid,uuid,uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.add_mind_map_node(jsonb),public.update_mind_map_node(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.add_mind_map_node(jsonb),public.update_mind_map_node(jsonb) to authenticated;
comment on column public.mind_map_nodes.edit_revision is 'M11.9 controlled visual-node CAS; unrelated to Artifact Version/Draft revision. No-op preserves revision.';
commit;
