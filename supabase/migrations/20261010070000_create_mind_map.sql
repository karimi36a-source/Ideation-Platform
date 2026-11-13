begin;
create unique index artifacts_mind_map_activity_unique on public.artifacts(activity_instance_id)
 where artifact_type='MIND_MAP' and activity_instance_id is not null;
-- Narrow initialization/provenance records. No general idempotency platform.
create table private.mind_map_initializations (
 activity_instance_id uuid primary key references public.activity_instances(id) on delete restrict,
 mind_map_id uuid not null unique references public.mind_maps(id) on delete restrict,
 initialized_by uuid not null references public.users(id) on delete restrict,
 context jsonb not null,activity_output_id uuid references public.activity_outputs(id) on delete restrict,
 created_at timestamptz not null default clock_timestamp()
);
create table private.mind_map_creation_requests (
 actor_id uuid not null references public.users(id) on delete restrict,
 activity_instance_id uuid not null references private.mind_map_initializations(activity_instance_id) on delete restrict,
 idempotency_key text not null check(length(btrim(idempotency_key)) between 1 and 200),
 context jsonb not null,created_at timestamptz not null default clock_timestamp(),
 primary key(actor_id,activity_instance_id,idempotency_key)
);
alter table private.mind_map_initializations enable row level security;
alter table private.mind_map_creation_requests enable row level security;
revoke all on private.mind_map_initializations,private.mind_map_creation_requests from public,anon,authenticated,service_role;

create function private.require_mind_map_write(target_instance uuid) returns public.activity_instances
language plpgsql volatile set search_path='' as $$
declare a public.activity_instances;begin
 a:=public.lock_activity_artifact_contribution(target_instance);
 if a.configuration_snapshot->>'method_type' is distinct from 'mind_map'
 or not exists(select 1 from public.activity_definitions where id=a.activity_definition_id and method_type='mind_map')
 then raise exception 'Invalid Activity method' using errcode='22023';end if;
 if not exists(select 1 from public.workspaces w where w.id=a.workspace_id and
  ((a.configuration_snapshot->>'workspace_mode'='Team Workspace' and w.workspace_type='TEAM' and w.team_id=a.team_id)
   or (a.configuration_snapshot->>'workspace_mode'='Personal Workspace' and w.workspace_type='PERSONAL' and w.owner_user_id=public.current_platform_user_id() and a.team_id is null)))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 return a;
end $$;
revoke all on function private.require_mind_map_write(uuid) from public,anon,authenticated,service_role;

-- SECURITY DEFINER composes protected M8/M7 writes atomically. All authority is
-- current FICI state and auth.uid(); no supplied owner/scope or direct CRUD grant.
create function public.create_mind_map(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;p public.development_projects;
 b public.artifacts;v public.artifact_versions;m public.mind_maps;n public.mind_map_nodes;
 init private.mind_map_initializations;saved private.mind_map_creation_requests;
 source public.artifacts;source_version public.artifact_versions;r record;
 key0 text;ctx jsonb;made jsonb;body jsonb;sources jsonb:='[]';types jsonb;out_id uuid;
 stamp timestamptz;map_id uuid;root_id uuid;replayed boolean:=false;deps jsonb;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in('activityInstanceId','idempotencyKey'))
 or jsonb_typeof(input->'activityInstanceId') is distinct from 'string'
 or jsonb_typeof(input->'idempotencyKey') is distinct from 'string'
 or length(private.trim_decision_text(input->>'idempotencyKey')) not between 1 and 200
 then raise exception 'Invalid input' using errcode='22023';end if;
 key0:=private.trim_decision_text(input->>'idempotencyKey');
 a:=private.require_mind_map_write((input->>'activityInstanceId')::uuid);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('mind-map-initialize:'||a.id::text,0));
 a:=private.require_mind_map_write(a.id);
 ctx:=jsonb_build_object('activityInstanceId',a.id,'activityDefinitionId',a.activity_definition_id,
  'projectId',a.project_id,'workspaceId',a.workspace_id,'teamId',a.team_id,'cohortId',a.cohort_id);
 select * into saved from private.mind_map_creation_requests where actor_id=actor and activity_instance_id=a.id and idempotency_key=key0;
 if found and saved.context<>ctx then raise exception 'Initialization conflict' using errcode='23505';end if;
 select * into init from private.mind_map_initializations where activity_instance_id=a.id;
 if found then
  if init.context<>ctx then raise exception 'Initialization conflict' using errcode='23505';end if;
  select * into m from public.mind_maps where id=init.mind_map_id for share;
  select * into b from public.artifacts where id=m.artifact_id for share;
  select * into v from public.artifact_versions where id=m.artifact_version_id for share;
  select * into n from public.mind_map_nodes where id=m.root_node_id and mind_map_id=m.id for share;
  out_id:=init.activity_output_id;
  if m.id is null or b.id is null or v.id is null or n.id is null or b.artifact_type<>'MIND_MAP'
   or b.activity_instance_id is distinct from a.id or (b.project_id,b.workspace_id) is distinct from (a.project_id,a.workspace_id)
   or b.status<>'ACTIVE' or b.archived_at is not null or v.artifact_id<>b.id
   or n.node_type<>'CENTRAL_INVENTION' or n.development_object_id is not null or n.parent_node_id is not null
   or n.created_by<>init.initialized_by
   or (out_id is not null and not exists(select 1 from public.activity_outputs where id=out_id and activity_instance_id=a.id and artifact_id=b.id and output_type='artifact'))
  then raise exception 'Invalid initialization history' using errcode='55000';end if;
  replayed:=true;
 else
  if exists(select 1 from public.artifacts where artifact_type='MIND_MAP' and activity_instance_id=a.id)
   then raise exception 'Unbound initialization history' using errcode='55000';end if;
  -- Prerequisites gate new initialization only. Reuse of the already canonical
  -- map preserves historical source references, with current scope/active
  -- Activity authority still required before and after every call.
 perform 1 from public.activity_dependencies where activity_definition_id=a.activity_definition_id for share;
 perform 1 from public.activity_instances s join public.activity_dependencies d on d.required_activity_definition_id=s.activity_definition_id
  where d.activity_definition_id=a.activity_definition_id and (s.project_id,s.workspace_id,s.cohort_id)=(a.project_id,a.workspace_id,a.cohort_id)
  and s.team_id is not distinct from a.team_id for share of s;
 -- Pin existing configured sources/pointers before evaluating availability.
 perform 1 from public.artifacts x join public.activity_instances s on s.id=x.activity_instance_id
  join public.activity_dependencies d on d.required_activity_definition_id=s.activity_definition_id
  where d.activity_definition_id=a.activity_definition_id and (s.project_id,s.workspace_id,s.cohort_id)=(a.project_id,a.workspace_id,a.cohort_id)
  and s.team_id is not distinct from a.team_id for share of x;
 perform 1 from public.artifact_versions x join public.artifacts z on z.current_version_id=x.id
  join public.activity_instances s on s.id=z.activity_instance_id join public.activity_dependencies d on d.required_activity_definition_id=s.activity_definition_id
  where d.activity_definition_id=a.activity_definition_id and (s.project_id,s.workspace_id,s.cohort_id)=(a.project_id,a.workspace_id,a.cohort_id)
  and s.team_id is not distinct from a.team_id for share of x;
 deps:=public.activity_dependencies_in_context(a.activity_definition_id,a.project_id,a.workspace_id,a.team_id,a.cohort_id);
 if deps->>'satisfied' is distinct from 'true' then raise exception 'Activity dependency unavailable' using errcode='55000';end if;
  select * into p from public.development_projects where id=a.project_id for share;
  if p.name is null or length(btrim(p.name)) not between 1 and 200 then raise exception 'Invalid Project name' using errcode='55000';end if;
  -- Exact registered inputs plus configured candidates. artifact_available keeps
  -- its nullable Version; never guess latest or silently require approval.
  perform 1 from public.activity_inputs where activity_instance_id=a.id for share;
  for r in select distinct q.artifact_id,q.artifact_version_id from (
   select i.artifact_id,i.artifact_version_id from public.activity_inputs i where i.activity_instance_id=a.id and i.artifact_id is not null
   union select c.artifact_id,c.artifact_version_id from public.activity_artifact_candidates_in_context(a.activity_definition_id,a.project_id,a.workspace_id,a.team_id,a.cohort_id) c
  ) q join public.artifacts z on z.id=q.artifact_id where z.artifact_type in('INVENTION_STRUCTURE','GAP_LIST')
  order by q.artifact_id,q.artifact_version_id loop
   select * into source from public.artifacts where id=r.artifact_id for share;
   if source.status<>'ACTIVE' or source.archived_at is not null or (source.project_id,source.workspace_id) is distinct from (a.project_id,a.workspace_id)
    or not public.can_read_development_project(source.project_id)
    or (source.activity_instance_id is not null and not public.can_read_activity_instance(source.activity_instance_id))
   then raise exception 'Resource unavailable' using errcode='42501';end if;
   if r.artifact_version_id is not null then
    select * into source_version from public.artifact_versions where id=r.artifact_version_id and artifact_id=source.id for share;
    if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
   end if;
   if exists(select 1 from public.activity_dependencies d where d.activity_definition_id=a.activity_definition_id and d.dependency_type in('approved_output','artifact_available'))
    and not exists(select 1 from public.activity_artifact_candidates_in_context(a.activity_definition_id,a.project_id,a.workspace_id,a.team_id,a.cohort_id) c where c.artifact_id=source.id and (c.dependency_type='artifact_available' or c.artifact_version_id=r.artifact_version_id))
   then raise exception 'Activity input unavailable' using errcode='55000';end if;
   sources:=sources||jsonb_build_array(jsonb_build_object('artifactType',source.artifact_type,'artifactId',source.id,'artifactVersionId',r.artifact_version_id));
  end loop;
  types:=a.configuration_snapshot#>'{configuration,outputs,artifact_types}';
  if types is not null and (jsonb_typeof(types)<>'array') then raise exception 'Invalid output configuration' using errcode='55000';end if;
  if types is not null and exists(select 1 from jsonb_array_elements(types) x where jsonb_typeof(x)<>'string' or not exists(select 1 from unnest(enum_range(null::public.artifact_type)) k where k::text=x#>>'{}')) then raise exception 'Invalid output configuration' using errcode='55000';end if;
  if jsonb_typeof(a.configuration_snapshot->'requires_review') is distinct from 'boolean' or jsonb_typeof(a.configuration_snapshot->'requires_approval') is distinct from 'boolean'
   then raise exception 'Invalid requirement configuration' using errcode='55000';end if;
  made:=private.create_artifact_initial_draft(a.project_id,a.workspace_id,'MIND_MAP','Invention Mind Map',a.id,
   (a.configuration_snapshot->>'requires_review')::boolean,(a.configuration_snapshot->>'requires_approval')::boolean);
  select * into b from public.artifacts where id=(made->>'artifactId')::uuid;
  select * into v from public.artifact_versions where id=(made->>'initialVersionId')::uuid;
  insert into public.mind_maps(artifact_id,artifact_version_id) values(b.id,v.id) returning * into m;
  insert into public.mind_map_nodes(mind_map_id,node_type,label,development_object_id,parent_node_id,position_data,metadata,created_by)
   values(m.id,'CENTRAL_INVENTION',p.name,null,null,'{"x":0,"y":0}','{"role":"central_invention"}',actor) returning * into n;
  update public.mind_maps set root_node_id=n.id where id=m.id returning * into m;
  stamp:=clock_timestamp();
  body:=jsonb_build_object('activityInstanceId',a.id,'projectId',a.project_id,'mindMapId',m.id,'rootNodeId',n.id,
   'initializedBy',actor,'initializedAt',stamp,'sources',sources,
   'nodes',jsonb_build_array(jsonb_build_object('id',n.id,'nodeType',n.node_type,'label',n.label,'developmentObjectId',null,'parentNodeId',null,'positionData',n.position_data,'metadata',n.metadata)),'edges','[]'::jsonb);
  -- Initial composition follows M10.13's M8 initializer pattern: not a Draft
  -- save, so the initial CAS counter stays 0. No existing Version is rewritten.
  update public.artifact_versions set content_snapshot=body where id=v.id returning * into v;
  if types @> '["MIND_MAP"]' then made:=public.add_activity_artifact_output(a.id,b.id);out_id:=(made->>'id')::uuid;end if;
  insert into private.mind_map_initializations(activity_instance_id,mind_map_id,initialized_by,context,activity_output_id,created_at)
   values(a.id,m.id,actor,ctx,out_id,stamp);
 end if;
 insert into private.mind_map_creation_requests(actor_id,activity_instance_id,idempotency_key,context)
  values(actor,a.id,key0,ctx) on conflict do nothing;
 perform private.require_mind_map_write(a.id);
 return jsonb_build_object('artifact',to_jsonb(b),'version',to_jsonb(v),'mindMap',to_jsonb(m),'rootNode',to_jsonb(n),'activityOutputId',out_id,'replayed',replayed);
exception when invalid_text_representation then raise exception 'Invalid input' using errcode='22023';
end $$;
revoke all on function public.create_mind_map(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_mind_map(jsonb) to authenticated;
comment on function public.create_mind_map(jsonb) is 'M11.8 current identity/scope, Activity singleton, narrow retry receipts, M8 initial Draft and visual-only CENTRAL_INVENTION root. No child nodes, approval, baseline or M11.9.';
commit;
