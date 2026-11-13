begin;
alter table public.mind_map_edges add column edit_revision bigint not null default 0 check(edit_revision between 0 and 9007199254740991);
alter table public.mind_map_edges add constraint mind_map_edge_type check(edge_type in ('HIERARCHY','CROSS_CONNECTION'));
alter table public.mind_map_edges add constraint mind_map_edge_not_self check(source_node_id<>target_node_id);
alter table public.mind_map_edges add constraint mind_map_edge_exact_unique unique(mind_map_id,source_node_id,target_node_id,edge_type);
-- Invoker integrity triggers: no new client privileges or authority.
create function private.validate_mind_map_edge_hierarchy() returns trigger language plpgsql set search_path='' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('mind-map-node-edit:'||new.mind_map_id::text,0));
 if new.edge_type='HIERARCHY' and exists(select 1 from public.mind_map_nodes where id=new.source_node_id and mind_map_id=new.mind_map_id)
 and exists(select 1 from public.mind_map_nodes where id=new.target_node_id and mind_map_id=new.mind_map_id)
 and not exists(select 1 from public.mind_map_nodes where id=new.target_node_id and mind_map_id=new.mind_map_id and parent_node_id=new.source_node_id)
 then raise exception 'Hierarchy edge requires existing parent' using errcode='22023';end if;
 return new;
end $$;
create trigger mind_map_edge_hierarchy_guard before insert or update on public.mind_map_edges for each row execute function private.validate_mind_map_edge_hierarchy();
create function private.preserve_mind_map_edge_parent() returns trigger language plpgsql set search_path='' as $$
begin
 if new.parent_node_id is distinct from old.parent_node_id then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('mind-map-node-edit:'||old.mind_map_id::text,0));
  if exists(select 1 from public.mind_map_edges where mind_map_id=old.mind_map_id and target_node_id=old.id and edge_type='HIERARCHY' and source_node_id is distinct from new.parent_node_id)
  then raise exception 'Remove hierarchy edge before changing parent' using errcode='22023';end if;
 end if;
 return new;
end $$;
create trigger mind_map_node_edge_parent_guard before update of parent_node_id on public.mind_map_nodes for each row execute function private.preserve_mind_map_edge_parent();

-- Invoker implementation is private; public SECURITY DEFINER wrappers alone
-- compose protected tables. Identity and scope are always canonical FICI state.
create function private.mutate_mind_map_edge(input jsonb,operation text) returns jsonb
language plpgsql volatile set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();e public.mind_map_edges;next0 public.mind_map_edges;a public.activity_instances;
 map_id uuid;allowed text[];expected bigint;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 allowed:=case operation when 'connect' then array['mindMapId','sourceNodeId','targetNodeId','edgeType','label','metadata'] when 'update' then array['edgeId','expectedRevision','edgeType','label','metadata'] when 'remove' then array['edgeId','expectedRevision'] end;
 if allowed is null or input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where not k=any(allowed))
 then raise exception 'Invalid input' using errcode='22023';end if;
 if (input ? 'label' and jsonb_typeof(input->'label') not in ('string','null'))
 or (jsonb_typeof(input->'label')='string' and length(private.trim_decision_text(input->>'label')) not between 1 and 200)
 or (input ? 'metadata' and jsonb_typeof(input->'metadata') is distinct from 'object')
 or (input ? 'edgeType' and (jsonb_typeof(input->'edgeType') is distinct from 'string' or input->>'edgeType' not in ('HIERARCHY','CROSS_CONNECTION')))
 then raise exception 'Invalid edge fields' using errcode='22023';end if;
 if input ? 'metadata' and exists(select 1 from jsonb_object_keys(input->'metadata') k where lower(replace(k,'_','')) in
 ('mindmapid','mapid','sourcenodeid','targetnodeid','source','target','projectid','workspaceid','teamid','artifactid','artifactversionid','versionid','developmentobjectrelationshipid','relationshipid','relationshiptype','canonicalrelationshipid','canonicalrelationshiptype','approval','approved','approvalstate','baseline','baselinestate','baselineid','authorization','scope','createdby','actor','userid','status','editrevision'))
 then raise exception 'Reserved metadata field' using errcode='22023';end if;
 if operation='connect' then
  if jsonb_typeof(input->'mindMapId') is distinct from 'string' or jsonb_typeof(input->'sourceNodeId') is distinct from 'string' or jsonb_typeof(input->'targetNodeId') is distinct from 'string' or not input ? 'edgeType'
   then raise exception 'Invalid input' using errcode='22023';end if;
  map_id:=(input->>'mindMapId')::uuid;
  next0.mind_map_id:=map_id;next0.source_node_id:=(input->>'sourceNodeId')::uuid;next0.target_node_id:=(input->>'targetNodeId')::uuid;
  next0.edge_type:=input->>'edgeType';next0.label:=private.trim_decision_text(input->>'label');next0.metadata:=coalesce(input->'metadata','{}');
 else
  if jsonb_typeof(input->'edgeId') is distinct from 'string' or jsonb_typeof(input->'expectedRevision') is distinct from 'number'
   or (input->>'expectedRevision') !~ '^[0-9]+$' or (input->>'expectedRevision')::numeric>9007199254740991
   or (operation='update' and not (input ?| array['edgeType','label','metadata']))
   then raise exception 'Invalid input' using errcode='22023';end if;
  expected:=(input->>'expectedRevision')::bigint;
  select * into e from public.mind_map_edges where id=(input->>'edgeId')::uuid;
  if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
  map_id:=e.mind_map_id;
 end if;
 a:=private.require_mind_map_node_edit(map_id);
 if operation<>'connect' then
  select * into e from public.mind_map_edges where id=e.id for update;
  if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
  if e.edit_revision<>expected then raise exception 'Edge edit conflict' using errcode='40001';end if;
  next0:=e;
  if input ? 'edgeType' then next0.edge_type:=input->>'edgeType';end if;
  if input ? 'label' then next0.label:=private.trim_decision_text(input->>'label');end if;
  if input ? 'metadata' then next0.metadata:=input->'metadata';end if;
 end if;
 -- The same map advisory lock is held by M11.9 parent changes and all edge ops.
 if not exists(select 1 from public.mind_map_nodes where id=next0.source_node_id and mind_map_id=map_id)
 or not exists(select 1 from public.mind_map_nodes where id=next0.target_node_id and mind_map_id=map_id)
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 if next0.source_node_id=next0.target_node_id then raise exception 'Self edge forbidden' using errcode='22023';end if;
 if operation<>'remove' and next0.edge_type='HIERARCHY' and not exists(select 1 from public.mind_map_nodes where id=next0.target_node_id and mind_map_id=map_id and parent_node_id=next0.source_node_id)
 then raise exception 'Hierarchy edge requires existing parent' using errcode='22023';end if;
 if operation='connect' then
  insert into public.mind_map_edges(mind_map_id,source_node_id,target_node_id,edge_type,label,metadata)
  values(map_id,next0.source_node_id,next0.target_node_id,next0.edge_type,next0.label,next0.metadata) returning * into e;
 elsif operation='remove' then
  delete from public.mind_map_edges where id=e.id and edit_revision=expected returning * into e;
 elsif (next0.edge_type,next0.label,next0.metadata) is distinct from (e.edge_type,e.label,e.metadata) then
  if e.edit_revision>=9007199254740991 then raise exception 'Revision exhausted' using errcode='55000';end if;
  update public.mind_map_edges set edge_type=next0.edge_type,label=next0.label,metadata=next0.metadata,edit_revision=edit_revision+1 where id=e.id and edit_revision=expected returning * into e;
 end if;
 perform private.require_mind_map_node_edit(map_id);
 return to_jsonb(e);
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Invalid input' using errcode='22023';
end $$;
create function public.connect_mind_map_nodes(input jsonb) returns jsonb language sql volatile security definer set search_path='' as $$select private.mutate_mind_map_edge(input,'connect')$$;
create function public.update_mind_map_edge(input jsonb) returns jsonb language sql volatile security definer set search_path='' as $$select private.mutate_mind_map_edge(input,'update')$$;
create function public.remove_mind_map_edge(input jsonb) returns jsonb language sql volatile security definer set search_path='' as $$select private.mutate_mind_map_edge(input,'remove')$$;
revoke all on function private.validate_mind_map_edge_hierarchy(),private.preserve_mind_map_edge_parent(),private.mutate_mind_map_edge(jsonb,text) from public,anon,authenticated,service_role;
revoke all on function public.connect_mind_map_nodes(jsonb),public.update_mind_map_edge(jsonb),public.remove_mind_map_edge(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.connect_mind_map_nodes(jsonb),public.update_mind_map_edge(jsonb),public.remove_mind_map_edge(jsonb) to authenticated;
commit;
