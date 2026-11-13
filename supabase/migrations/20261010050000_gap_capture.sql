begin;
-- Narrow retry receipts only. Canonical Gaps remain Development Objects.
create table private.gap_captures (
 actor_id uuid not null references public.users(id) on delete restrict,
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 idempotency_key text not null check(length(btrim(idempotency_key)) between 1 and 200),
 payload jsonb not null,result jsonb not null,created_at timestamptz not null default clock_timestamp(),
 primary key(actor_id,activity_instance_id,idempotency_key)
);
alter table private.gap_captures enable row level security;
revoke all on private.gap_captures from public,anon,authenticated,service_role;
create unique index artifacts_gap_list_activity_unique on public.artifacts(activity_instance_id)
 where artifact_type='GAP_LIST' and activity_instance_id is not null;

-- Definer privileges only for the atomic protected composition. Existing M7/M11
-- validators bind identity, current exact scope and editable lifecycle. No CRUD
-- grants, service credentials, or caller-provided ownership are introduced.
create function public.capture_gap(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;o public.development_objects;
 bank public.artifacts;v public.artifact_versions;prior public.artifact_versions;link public.artifact_object_links;
 saved private.gap_captures;payload jsonb;edge jsonb;created jsonb;body jsonb;types jsonb;
 target uuid;src uuid;dst uuid;edge_id uuid;output_id uuid;ids uuid[]:='{}';edges uuid[]:='{}';
 oid uuid;key text;mode text;stamp timestamptz;seq integer:=0;changed boolean;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in('activityInstanceId','mode','gapObjectId','newGap','relationships','idempotencyKey'))
 or jsonb_typeof(input->'activityInstanceId') is distinct from 'string'
 or jsonb_typeof(input->'idempotencyKey') is distinct from 'string'
 or length(private.trim_decision_text(input->>'idempotencyKey')) not between 1 and 200
 or coalesce(input->>'mode','') not in('CREATE_NEW','ADD_EXISTING')
 then raise exception 'Invalid input' using errcode='22023';end if;
 key:=private.trim_decision_text(input->>'idempotencyKey');mode:=input->>'mode';
 payload:=jsonb_build_object('activityInstanceId',(input->>'activityInstanceId')::uuid,'mode',mode);
 if mode='ADD_EXISTING' then
  if input ? 'newGap' or jsonb_typeof(input->'gapObjectId') is distinct from 'string' then raise exception 'Invalid input' using errcode='22023';end if;
  payload:=payload||jsonb_build_object('gapObjectId',(input->>'gapObjectId')::uuid);
 else
  if input ? 'gapObjectId' or jsonb_typeof(input->'newGap') is distinct from 'object' then raise exception 'Invalid input' using errcode='22023';end if;
  if exists(select 1 from jsonb_object_keys(input->'newGap') k where k not in('title','content'))
  or jsonb_typeof(input#>'{newGap,title}') is distinct from 'string'
  or length(private.trim_decision_text(input#>>'{newGap,title}')) not between 1 and 200
  or (input->'newGap' ? 'content' and (jsonb_typeof(input#>'{newGap,content}') is distinct from 'string' or length(input#>>'{newGap,content}')>100000))
  then raise exception 'Invalid input' using errcode='22023';end if;
  payload:=payload||jsonb_build_object('newGap',jsonb_build_object('title',private.trim_decision_text(input#>>'{newGap,title}'),'content',coalesce(input#>>'{newGap,content}','')));
 end if;
 if input ? 'relationships' and jsonb_typeof(input->'relationships') is distinct from 'array' then raise exception 'Invalid input' using errcode='22023';end if;
 if jsonb_array_length(coalesce(input->'relationships','[]'))>100 then raise exception 'Invalid input' using errcode='22023';end if;
 for edge in select value from jsonb_array_elements(coalesce(input->'relationships','[]')) loop
  if jsonb_typeof(edge)<>'object' or exists(select 1 from jsonb_object_keys(edge) k where k not in('sourceObjectId','targetObjectId','relationshipType'))
  or jsonb_typeof(edge->'sourceObjectId') is distinct from 'string' or jsonb_typeof(edge->'targetObjectId') is distinct from 'string'
  or not exists(select 1 from unnest(enum_range(null::public.development_relationship_type)) k where k::text=edge->>'relationshipType')
  then raise exception 'Invalid relationship' using errcode='22023';end if;
  if edge->>'sourceObjectId'<>'CONFIRMED_OBJECT' then perform (edge->>'sourceObjectId')::uuid;end if;
  if edge->>'targetObjectId'<>'CONFIRMED_OBJECT' then perform (edge->>'targetObjectId')::uuid;end if;
 end loop;
 payload:=payload||jsonb_build_object('relationships',coalesce((select jsonb_agg(x order by x::text) from
  (select distinct jsonb_build_object('sourceObjectId',case when value->>'sourceObjectId'='CONFIRMED_OBJECT' then case when mode='ADD_EXISTING' then payload->>'gapObjectId' else 'CONFIRMED_OBJECT' end else ((value->>'sourceObjectId')::uuid)::text end,
   'targetObjectId',case when value->>'targetObjectId'='CONFIRMED_OBJECT' then case when mode='ADD_EXISTING' then payload->>'gapObjectId' else 'CONFIRMED_OBJECT' end else ((value->>'targetObjectId')::uuid)::text end,'relationshipType',value->>'relationshipType') x
   from jsonb_array_elements(coalesce(input->'relationships','[]'))) q),'[]'));
 a:=private.require_affinity_write((payload->>'activityInstanceId')::uuid);
 -- Serialize the entire read-latest/add/checkpoint sequence, not just numbering.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gap-capture:'||a.id::text,0));
 a:=private.require_affinity_write(a.id);
 select * into saved from private.gap_captures where actor_id=actor and activity_instance_id=a.id and idempotency_key=key;
 if found then
  if saved.payload<>payload then raise exception 'Gap capture conflict' using errcode='23505';end if;
  target:=(saved.result#>>'{gap,id}')::uuid;perform private.require_affinity_source(a,target,null);
  select * into o from public.development_objects where id=target;
  select * into bank from public.artifacts where id=(saved.result#>>'{artifact,id}')::uuid;
  select * into v from public.artifact_versions where id=(saved.result#>>'{version,id}')::uuid;
  if bank.status<>'ACTIVE' or bank.archived_at is not null then raise exception 'Resource unavailable' using errcode='42501';end if;
  return saved.result||jsonb_build_object('gap',to_jsonb(o),'artifact',to_jsonb(bank),'version',to_jsonb(v),'replayed',true);
 end if;
 stamp:=clock_timestamp();
 select * into bank from public.artifacts where artifact_type='GAP_LIST' and activity_instance_id=a.id for update;
 if bank.id is not null then
  if bank.status<>'ACTIVE' or bank.archived_at is not null or (bank.project_id,bank.workspace_id) is distinct from (a.project_id,a.workspace_id)
  or bank.review_required is distinct from (a.configuration_snapshot->>'requires_review')::boolean
  or bank.approval_required is distinct from (a.configuration_snapshot->>'requires_approval')::boolean
  then raise exception 'Resource unavailable' using errcode='42501';end if;
  select * into prior from public.artifact_versions where artifact_id=bank.id order by version_number desc limit 1 for share;
  for link in select * from public.artifact_object_links where artifact_version_id=prior.id order by sequence,id for share loop
   perform private.require_affinity_source(a,link.development_object_id,null);
   select * into o from public.development_objects where id=link.development_object_id;
   if o.object_type<>'GAP' or o.id=any(ids) then raise exception 'Invalid Gap List history' using errcode='55000';end if;
   ids:=array_append(ids,o.id);
  end loop;
  -- A generic empty/unbound Draft must not silently erase prior list membership.
  if prior.id is not null and (prior.content_snapshot->'gapObjectIds' is distinct from to_jsonb(ids)
   or prior.content_snapshot->>'activityInstanceId' is distinct from a.id::text
   or not exists(select 1 from private.gap_captures checkpoint where checkpoint.activity_instance_id=a.id
    and checkpoint.result#>>'{artifact,id}'=bank.id::text and checkpoint.result#>>'{version,id}'=prior.id::text
    and checkpoint.result->>'membershipChanged'='true'))
  then raise exception 'Invalid Gap List history' using errcode='55000';end if;
 end if;
 if mode='ADD_EXISTING' then
  target:=(payload->>'gapObjectId')::uuid;perform private.require_affinity_source(a,target,null);
  select * into o from public.development_objects where id=target for share;
  if o.object_type<>'GAP' then raise exception 'Invalid Gap type' using errcode='22023';end if;
 else
  created:=public.create_development_object(a.project_id,a.workspace_id,'GAP',payload#>>'{newGap,title}',payload#>>'{newGap,content}',
   'GAP_CAPTURE',jsonb_build_object('sourceActivityInstanceId',a.id,'captureMode',mode,'capturedBy',actor,'capturedAt',stamp));
  target:=(created->>'id')::uuid;
  update public.development_objects set origin_reference_id=a.id where id=target;
 end if;
 for edge in select value from jsonb_array_elements(payload->'relationships') loop
  src:=case when edge->>'sourceObjectId'='CONFIRMED_OBJECT' then target else (edge->>'sourceObjectId')::uuid end;
  dst:=case when edge->>'targetObjectId'='CONFIRMED_OBJECT' then target else (edge->>'targetObjectId')::uuid end;
  perform private.require_affinity_source(a,src,null);perform private.require_affinity_source(a,dst,null);
  if src=dst then raise exception 'Self relationship' using errcode='22023';end if;
  select id into edge_id from public.development_object_relationships where project_id=a.project_id and source_object_id=src and target_object_id=dst and relationship_type::text=edge->>'relationshipType' and status='active' for share;
  if not found then created:=public.relate_development_objects(src,dst,(edge->>'relationshipType')::public.development_relationship_type,null);edge_id:=(created->>'id')::uuid;end if;
  edges:=array_append(edges,edge_id);
 end loop;
 changed:=not(target=any(ids));
 if changed then
  ids:=array_append(ids,target);
  if bank.id is null then
   insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by,activity_instance_id,review_required,approval_required)
   values(a.project_id,a.workspace_id,'GAP_LIST','Gap List',actor,a.id,(a.configuration_snapshot->>'requires_review')::boolean,(a.configuration_snapshot->>'requires_approval')::boolean) returning * into bank;
  end if;
  body:=jsonb_build_object('activityInstanceId',a.id,'gapObjectIds',to_jsonb(ids),'capturedGapObjectId',target,'captureMode',mode,
   'capturedBy',actor,'capturedAt',stamp,'relationshipIds',to_jsonb(edges),'priorVersionId',prior.id);
  created:=public.create_artifact_version(bank.id,body,null);
  select * into v from public.artifact_versions where id=(created->>'id')::uuid;
  foreach oid in array ids loop
   seq:=seq+1;
   insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence,role_in_artifact,metadata)
   values(bank.id,v.id,oid,seq,'gap',jsonb_build_object('sourceActivityInstanceId',a.id));
  end loop;
 else
  -- Canonical edges can be changed explicitly without rewriting list history.
  -- The receipt records this action; the existing Version and links stay intact.
  v:=prior;
 end if;
 types:=a.configuration_snapshot#>'{configuration,outputs,artifact_types}';
 if types is not null then
  if jsonb_typeof(types)<>'array' or exists(select 1 from jsonb_array_elements(types) x where jsonb_typeof(x)<>'string' or not exists(select 1 from unnest(enum_range(null::public.artifact_type)) k where k::text=x#>>'{}')) then raise exception 'Invalid output configuration' using errcode='55000';end if;
  if types @> '["GAP_LIST"]' then created:=public.add_activity_artifact_output(a.id,bank.id);output_id:=(created->>'id')::uuid;end if;
 end if;
 perform private.require_affinity_write(a.id);
 select * into o from public.development_objects where id=target;
 created:=jsonb_build_object('gap',to_jsonb(o),'relationshipIds',to_jsonb(edges),'artifact',to_jsonb(bank),'version',to_jsonb(v),'activityOutputId',output_id,'replayed',false,'membershipChanged',changed);
 insert into private.gap_captures(actor_id,activity_instance_id,idempotency_key,payload,result) values(actor,a.id,key,payload,created);
 return created;
exception when invalid_text_representation then raise exception 'Invalid input' using errcode='22023';
end $$;
revoke all on function public.capture_gap(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.capture_gap(jsonb) to authenticated;
comment on function public.capture_gap(jsonb) is 'M11.6 explicit canonical GAP capture/reuse; cumulative ordered M8 Draft checkpoints, narrow actor/Activity retry receipts, current Affinity authority. No inferred Gaps, approval, baseline, sharing or Mind Map.';
commit;
