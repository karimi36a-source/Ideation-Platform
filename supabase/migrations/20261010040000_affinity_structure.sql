begin;
-- Narrow operation receipts, not a platform-wide idempotency/provenance system.
create table private.affinity_structure_confirmations (
 actor_id uuid not null references public.users(id) on delete restrict,
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 idempotency_key text not null check(length(btrim(idempotency_key)) between 1 and 200),
 payload jsonb not null, result jsonb not null,
 created_at timestamptz not null default clock_timestamp(),
 primary key(actor_id,activity_instance_id,idempotency_key)
);
alter table private.affinity_structure_confirmations enable row level security;
revoke all on private.affinity_structure_confirmations from public,anon,authenticated,service_role;
create unique index artifacts_invention_structure_activity_unique on public.artifacts(activity_instance_id)
 where artifact_type='INVENTION_STRUCTURE' and activity_instance_id is not null;

-- SECURITY DEFINER is necessary solely for this atomic protected composition.
-- Identity, scope, locks and lifecycle are checked through the existing M7/M11
-- validators. No client identity, direct CRUD grants, or service credential path.
create function public.confirm_affinity_structure(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;g public.affinity_groups;
 o public.development_objects;b public.artifacts;v public.artifact_versions;item public.affinity_group_items;
 saved private.affinity_structure_confirmations;edge jsonb;created jsonb;body jsonb;payload jsonb;
 target uuid;source_id uuid;dest_id uuid;edge_id uuid;ids uuid[]:='{}';edges uuid[]:='{}';
 oid uuid;output_id uuid;key text;mode text;stamp timestamptz;position integer:=0;types jsonb;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in('activityInstanceId','affinityGroupId','mode','targetObjectId','newObject','relationships','idempotencyKey'))
 or jsonb_typeof(input->'activityInstanceId') is distinct from 'string'
 or jsonb_typeof(input->'affinityGroupId') is distinct from 'string'
 or jsonb_typeof(input->'idempotencyKey') is distinct from 'string'
 or length(private.trim_decision_text(input->>'idempotencyKey')) not between 1 and 200
 or coalesce(input->>'mode','') not in('LINK_EXISTING','CREATE_NEW')
 then raise exception 'Invalid input' using errcode='22023';end if;
 mode:=input->>'mode';key:=private.trim_decision_text(input->>'idempotencyKey');
 if mode='LINK_EXISTING' then
  if input ? 'newObject' or jsonb_typeof(input->'targetObjectId') is distinct from 'string' then raise exception 'Invalid input' using errcode='22023';end if;
 else
  if input ? 'targetObjectId' or jsonb_typeof(input->'newObject') is distinct from 'object' then raise exception 'Invalid input' using errcode='22023';end if;
  if exists(select 1 from jsonb_object_keys(input->'newObject') k where k not in('objectType','title','content'))
  or coalesce(input#>>'{newObject,objectType}','') not in('SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','GAP')
  or jsonb_typeof(input#>'{newObject,title}') is distinct from 'string'
  or length(private.trim_decision_text(input#>>'{newObject,title}')) not between 1 and 200
  or (input->'newObject' ? 'content' and (jsonb_typeof(input#>'{newObject,content}') is distinct from 'string' or length(input#>>'{newObject,content}')>100000))
  then raise exception 'Invalid input' using errcode='22023';end if;
 end if;
 if input ? 'relationships' and (jsonb_typeof(input->'relationships') is distinct from 'array') then raise exception 'Invalid input' using errcode='22023';end if;
 if jsonb_array_length(coalesce(input->'relationships','[]'))>100 then raise exception 'Invalid input' using errcode='22023';end if;
 -- Normalize defaults, UUIDs and unordered edge sets before comparing intent.
 payload:=jsonb_build_object('activityInstanceId',(input->>'activityInstanceId')::uuid,'affinityGroupId',(input->>'affinityGroupId')::uuid,'mode',mode);
 if mode='LINK_EXISTING' then payload:=payload||jsonb_build_object('targetObjectId',(input->>'targetObjectId')::uuid);
 else payload:=payload||jsonb_build_object('newObject',jsonb_build_object('objectType',input#>>'{newObject,objectType}','title',private.trim_decision_text(input#>>'{newObject,title}'),'content',coalesce(input#>>'{newObject,content}','')));end if;
 for edge in select value from jsonb_array_elements(coalesce(input->'relationships','[]')) loop
  if jsonb_typeof(edge)<>'object' or exists(select 1 from jsonb_object_keys(edge) k where k not in('sourceObjectId','targetObjectId','relationshipType'))
  or jsonb_typeof(edge->'sourceObjectId') is distinct from 'string' or jsonb_typeof(edge->'targetObjectId') is distinct from 'string'
  or not exists(select 1 from unnest(enum_range(null::public.development_relationship_type)) k where k::text=edge->>'relationshipType')
  then raise exception 'Invalid relationship' using errcode='22023';end if;
  if edge->>'sourceObjectId'<>'CONFIRMED_OBJECT' then perform (edge->>'sourceObjectId')::uuid;end if;
  if edge->>'targetObjectId'<>'CONFIRMED_OBJECT' then perform (edge->>'targetObjectId')::uuid;end if;
 end loop;
 payload:=payload||jsonb_build_object('relationships',coalesce((select jsonb_agg(x order by x::text) from
  (select distinct jsonb_build_object('sourceObjectId',case when value->>'sourceObjectId'='CONFIRMED_OBJECT' then case when mode='LINK_EXISTING' then payload->>'targetObjectId' else 'CONFIRMED_OBJECT' end else ((value->>'sourceObjectId')::uuid)::text end,
   'targetObjectId',case when value->>'targetObjectId'='CONFIRMED_OBJECT' then case when mode='LINK_EXISTING' then payload->>'targetObjectId' else 'CONFIRMED_OBJECT' end else ((value->>'targetObjectId')::uuid)::text end,'relationshipType',value->>'relationshipType') x
   from jsonb_array_elements(coalesce(input->'relationships','[]'))) q),'[]'));
 a:=private.require_affinity_write((payload->>'activityInstanceId')::uuid);
 -- Same ordering lock as Affinity movement: confirmation sees a canonical board.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('affinity-items:'||a.id::text,0));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('affinity-structure:'||a.id::text,0));
 a:=private.require_affinity_write(a.id);
 select * into g from public.affinity_groups where id=(payload->>'affinityGroupId')::uuid and activity_instance_id=a.id for share;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into saved from private.affinity_structure_confirmations where actor_id=actor and activity_instance_id=a.id and idempotency_key=key;
 if found then
  if saved.payload<>payload then raise exception 'Confirmation conflict' using errcode='23505';end if;
  if not public.can_read_development_project(a.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
  select * into b from public.artifacts where id=(saved.result#>>'{artifact,id}')::uuid;
  select * into v from public.artifact_versions where id=(saved.result#>>'{version,id}')::uuid;
  return saved.result||jsonb_build_object('artifact',to_jsonb(b),'version',to_jsonb(v),'replayed',true);
 end if;
 stamp:=clock_timestamp();
 -- Validate every included source, retaining references only, never source text.
 for item in select * from public.affinity_group_items where affinity_group_id=g.id order by position,id for share loop
  perform private.require_affinity_source(a,item.development_object_id,item.brainstorm_entry_id);
  if item.development_object_id is not null then ids:=array_append(ids,item.development_object_id);end if;
 end loop;
 if mode='LINK_EXISTING' then
  target:=(payload->>'targetObjectId')::uuid;
  perform private.require_affinity_source(a,target,null);
  select * into o from public.development_objects where id=target for share;
  if o.object_type not in('SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','GAP') then raise exception 'Invalid structural type' using errcode='22023';end if;
 else
  created:=public.create_development_object(a.project_id,a.workspace_id,(payload#>>'{newObject,objectType}')::public.development_object_type,
   payload#>>'{newObject,title}',payload#>>'{newObject,content}','AFFINITY',jsonb_build_object('sourceAffinityGroupId',g.id,'sourceActivityInstanceId',a.id,'confirmationMode',mode,'confirmedBy',actor,'confirmedAt',stamp));
  target:=(created->>'id')::uuid;
  update public.development_objects set origin_reference_id=g.id where id=target;
 end if;
 ids:=array_append(ids,target);
 for edge in select value from jsonb_array_elements(payload->'relationships') loop
  source_id:=case when edge->>'sourceObjectId'='CONFIRMED_OBJECT' then target else (edge->>'sourceObjectId')::uuid end;
  dest_id:=case when edge->>'targetObjectId'='CONFIRMED_OBJECT' then target else (edge->>'targetObjectId')::uuid end;
  perform private.require_affinity_source(a,source_id,null);perform private.require_affinity_source(a,dest_id,null);
  if source_id=dest_id then raise exception 'Self relationship' using errcode='22023';end if;
  select id into edge_id from public.development_object_relationships where project_id=a.project_id and source_object_id=source_id and target_object_id=dest_id and relationship_type::text=edge->>'relationshipType' and status='active' for share;
  if not found then
   created:=public.relate_development_objects(source_id,dest_id,(edge->>'relationshipType')::public.development_relationship_type,null);
   edge_id:=(created->>'id')::uuid;
  end if;
  edges:=array_append(edges,edge_id);ids:=ids||array[source_id,dest_id];
 end loop;
 body:=jsonb_build_object('affinityGroupId',g.id,'activityInstanceId',a.id,'confirmationMode',mode,'resolvedDevelopmentObjectId',target,
  'reused',mode='LINK_EXISTING','confirmedBy',actor,'confirmedAt',stamp,'relationshipIds',to_jsonb(edges),
  'items',coalesce((select jsonb_agg(jsonb_build_object('itemId',i.id,'developmentObjectId',i.development_object_id,'brainstormEntryId',i.brainstorm_entry_id,'position',i.position,'moveRevision',i.move_revision) order by i.position,i.id) from public.affinity_group_items i where i.affinity_group_id=g.id),'[]'));
 select * into b from public.artifacts where artifact_type='INVENTION_STRUCTURE' and activity_instance_id=a.id for update;
 if b.id is null then
  insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by,activity_instance_id,review_required,approval_required)
  values(a.project_id,a.workspace_id,'INVENTION_STRUCTURE','Invention Structure',actor,a.id,(a.configuration_snapshot->>'requires_review')::boolean,(a.configuration_snapshot->>'requires_approval')::boolean) returning * into b;
 elsif b.status<>'ACTIVE' or b.archived_at is not null or (b.project_id,b.workspace_id) is distinct from (a.project_id,a.workspace_id)
 or b.review_required is distinct from (a.configuration_snapshot->>'requires_review')::boolean or b.approval_required is distinct from (a.configuration_snapshot->>'requires_approval')::boolean
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 created:=public.create_artifact_version(b.id,body,null);
 select * into v from public.artifact_versions where id=(created->>'id')::uuid;
 for oid in select distinct x from unnest(ids) x order by x loop
  position:=position+1;
  insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence,role_in_artifact,metadata)
  values(b.id,v.id,oid,position,'structure',jsonb_build_object('sourceAffinityGroupId',g.id,'sourceActivityInstanceId',a.id));
 end loop;
 types:=a.configuration_snapshot#>'{configuration,outputs,artifact_types}';
 if types is not null then
  if jsonb_typeof(types)<>'array' or exists(select 1 from jsonb_array_elements(types) x where jsonb_typeof(x)<>'string' or not exists(select 1 from unnest(enum_range(null::public.artifact_type)) k where k::text=x#>>'{}')) then raise exception 'Invalid output configuration' using errcode='55000';end if;
  if types @> '["INVENTION_STRUCTURE"]' then created:=public.add_activity_artifact_output(a.id,b.id);output_id:=(created->>'id')::uuid;end if;
 end if;
 perform private.require_affinity_write(a.id);
 created:=jsonb_build_object('resolvedDevelopmentObjectId',target,'relationshipIds',to_jsonb(edges),'artifact',to_jsonb(b),'version',to_jsonb(v),'activityOutputId',output_id,'replayed',false);
 insert into private.affinity_structure_confirmations(actor_id,activity_instance_id,idempotency_key,payload,result) values(actor,a.id,key,payload,created);
 return created;
exception when invalid_text_representation then raise exception 'Invalid input' using errcode='22023';
end $$;
revoke all on function public.confirm_affinity_structure(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.confirm_affinity_structure(jsonb) to authenticated;
comment on function public.confirm_affinity_structure(jsonb) is 'M11.5 explicit human confirmation; current Affinity edit authority, atomic actor/Activity-scoped retry receipts, canonical Objects/relationships and M8 Draft. No approval, baseline, sharing or M11.6.';
commit;
