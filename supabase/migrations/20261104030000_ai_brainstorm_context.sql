begin;
-- One narrow predicate composes M9 access with exact AI execution scope.
-- It grants no entry read, reveal, membership or Share permission.
create function public.can_read_ai_brainstorm_entry(target_entry uuid,target_activity uuid,target_project uuid,target_workspace uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare b public.brainstorm_entries;s jsonb;a public.activity_instances;pool0 boolean;
begin
 if public.current_platform_user_id() is null or target_activity is null or not public.can_read_brainstorm_entry(target_entry) then return false;end if;
 select * into b from public.brainstorm_entries where id=target_entry;
 if b.id is null or (b.activity_instance_id,b.project_id,b.workspace_id) is distinct from (target_activity,target_project,target_workspace) then return false;end if;
 select * into a from public.activity_instances where id=target_activity;
 s:=public.resolve_activity_ai_configuration(target_activity);
 if s is null or s->>'method_type' is distinct from 'brainstorming' or s->>'current_method' is distinct from 'brainstorming'
 or s->>'ai_role_code' is distinct from 'BRAINSTORMING_FACILITATOR' or s->>'current_role' is distinct from 'BRAINSTORMING_FACILITATOR'
 or a.configuration_snapshot #>> '{configuration,brainstorming,visibility_mode}' is distinct from 'private_before_reveal' then return false;end if;
 -- Availability remains owned by M14.9. This predicate only restricts which
 -- readable entries may represent its self-only versus revealed-pool input.
 if coalesce(jsonb_typeof(s #> '{configuration,ai,requires_revealed_pool}'),'null') not in ('boolean','null')
 or coalesce(jsonb_typeof(s #> '{current_ai,requires_revealed_pool}'),'null') not in ('boolean','null') then return false;end if;
 pool0:=coalesce((s #> '{configuration,ai,requires_revealed_pool}')='true'::jsonb,false) or coalesce((s #> '{current_ai,requires_revealed_pool}')='true'::jsonb,false);
 return b.revealed_at is not null or (not pool0 and b.created_by=public.current_platform_user_id());
end$$;
revoke all on function public.can_read_ai_brainstorm_entry(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_ai_brainstorm_entry(uuid,uuid,uuid,uuid) to authenticated;
-- Replace only the role/source CHECK, retaining all other constraints and RLS.
do $$declare c record;begin
 for c in select conname from pg_constraint where conrelid='public.ai_context_references'::regclass and contype='c' and pg_get_expr(conbin,conrelid) like '%CASE context_role%' loop
  execute format('alter table public.ai_context_references drop constraint %I',c.conname);
 end loop;
end$$;
alter table public.ai_context_references add constraint ai_context_source_role_check check(case context_role
 when 'CURRENT_PROJECT' then entity_type='PROJECT' when 'CURRENT_ARTIFACT' then entity_type='ARTIFACT_VERSION'
 when 'PRIOR_APPROVED_OUTPUT' then entity_type='ARTIFACT_VERSION' when 'TEAM_DECISION' then entity_type='DECISION'
 when 'INSTRUCTOR_FEEDBACK' then entity_type='FEEDBACK_ITEM' when 'EVIDENCE' then entity_type='EVIDENCE'
 when 'PATENT' then entity_type='PATENT_RECORD' when 'GAP' then entity_type='DEVELOPMENT_OBJECT'
 when 'COURSE_CONTEXT' then entity_type='ACTIVITY_INSTANCE' when 'BRAINSTORM' then entity_type='BRAINSTORM_ENTRY' else false end);
alter table public.ai_context_references add constraint ai_brainstorm_no_share check(entity_type<>'BRAINSTORM_ENTRY' or share_snapshot_id is null);

create or replace function public.resolve_ai_context_source(input jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare pid uuid;wid uuid;aid uuid;eid uuid;kind text;role0 text;body jsonb;projection jsonb;
 p public.development_projects;a public.artifacts;v public.artifact_versions;f public.feedback_items;
 share0 jsonb;access0 jsonb;snapshot0 uuid;hash0 text;
begin
 if public.current_platform_user_id() is null then raise exception 'Context unavailable' using errcode='42501';end if;
 if jsonb_typeof(input) is distinct from 'object' or exists(select 1 from jsonb_object_keys(input) k where k not in ('projectId','workspaceId','activityInstanceId','entityType','entityId','contextRole','shareId'))
 or not(input ?& array['projectId','workspaceId','entityType','entityId','contextRole']) then raise exception 'Invalid context request' using errcode='22023';end if;
 pid:=(input->>'projectId')::uuid;wid:=(input->>'workspaceId')::uuid;aid:=(input->>'activityInstanceId')::uuid;
 eid:=(input->>'entityId')::uuid;kind:=input->>'entityType';role0:=input->>'contextRole';
 select * into p from public.development_projects where id=pid and primary_workspace_id=wid and public.can_read_development_project(pid);
 if p.id is null or not exists(select 1 from public.workspaces where id=wid) then raise exception 'Context unavailable' using errcode='42501';end if;
 if aid is not null and not exists(select 1 from public.activity_instances where id=aid and project_id=pid and workspace_id=wid and public.can_read_activity_instance(id)) then raise exception 'Context unavailable' using errcode='42501';end if;
 if not coalesce(case role0 when 'CURRENT_PROJECT' then kind='PROJECT' when 'CURRENT_ARTIFACT' then kind='ARTIFACT_VERSION' when 'PRIOR_APPROVED_OUTPUT' then kind='ARTIFACT_VERSION' when 'TEAM_DECISION' then kind='DECISION' when 'INSTRUCTOR_FEEDBACK' then kind='FEEDBACK_ITEM' when 'EVIDENCE' then kind='EVIDENCE' when 'PATENT' then kind='PATENT_RECORD' when 'GAP' then kind='DEVELOPMENT_OBJECT' when 'COURSE_CONTEXT' then kind='ACTIVITY_INSTANCE' when 'BRAINSTORM' then kind='BRAINSTORM_ENTRY' else false end,false) then raise exception 'Invalid context request' using errcode='22023';end if;
 if input->>'shareId' is not null then
  share0:=public.resolve_ai_context_share((input->>'shareId')::uuid);access0:=share0->'access';
  if access0->>'allowed' is distinct from 'true' then return null;end if;
  if not ((kind='ARTIFACT_VERSION' and access0->>'sharedEntityType'='ARTIFACT' and access0->>'sourceVersionId'=eid::text)
   or (kind in ('DEVELOPMENT_OBJECT','EVIDENCE','PATENT_RECORD') and access0->>'sharedEntityType'=kind and access0->>'sharedEntityId'=eid::text)) then return null;end if;
  -- Frozen recipient projection carries no approval attestation. Do not reopen
  -- private Version state to manufacture PRIOR_APPROVED_OUTPUT authority.
  if role0='PRIOR_APPROVED_OUTPUT' then return null;end if;
  body:=access0->'snapshotContent';projection:=body;snapshot0:=(share0->>'snapshotId')::uuid;hash0:=share0->>'hash';
 else
  case kind
   when 'PROJECT' then if eid=pid then body:=to_jsonb(p);projection:=jsonb_build_object('name',p.name,'description',p.description);end if;
   when 'ARTIFACT_VERSION' then
    select * into v from public.artifact_versions where id=eid;
    select * into a from public.artifacts where id=v.artifact_id and project_id=pid and workspace_id=wid;
    if a.id is not null then
     if role0='PRIOR_APPROVED_OUTPUT' and not(v.status in ('APPROVED','CURRENT','SUPERSEDED') and v.approved_by is not null and v.approved_at is not null) then return null;end if;
     body:=v.content_snapshot;projection:=jsonb_build_object('title',a.title,'artifact_type',a.artifact_type,'content_snapshot',v.content_snapshot);
    end if;
   when 'DEVELOPMENT_OBJECT' then select to_jsonb(d),jsonb_build_object('title',d.title,'content',d.content,'object_type',d.object_type) into body,projection from public.development_objects d where d.id=eid and d.project_id=pid and d.workspace_id=wid and d.object_type='GAP';
   when 'DECISION' then select to_jsonb(d),jsonb_build_object('title',d.title,'question',d.question,'outcome',d.outcome,'reasoning',d.reasoning) into body,projection from public.decisions d where d.id=eid and d.project_id=pid and d.workspace_id=wid;
   when 'FEEDBACK_ITEM' then
    select x.* into f from public.feedback_items x join public.submissions s on s.id=x.submission_id join public.artifacts a0 on a0.id=s.artifact_id where x.id=eid and x.project_id=pid and a0.workspace_id=wid;
    if f.id is not null then body:=to_jsonb(f);projection:=jsonb_build_object('feedback_type',f.feedback_type,'content',f.content);end if;
   when 'EVIDENCE' then select to_jsonb(e),jsonb_build_object('title',e.title,'description',e.description,'source_name',e.source_name,'evidence_type',e.evidence_type,'verification_status',e.verification_status,'claim_locator',e.claim_locator) into body,projection from public.evidence e where e.id=eid and e.project_id=pid and e.workspace_id=wid;
   when 'PATENT_RECORD' then select to_jsonb(x),jsonb_build_object('title',x.title,'publication_number',x.publication_number,'source_database',x.source_database,'abstract_text',x.abstract_text,'ipc_cpc',x.ipc_cpc) into body,projection from public.patent_records x where x.id=eid and x.project_id=pid and x.workspace_id=wid;
   when 'BRAINSTORM_ENTRY' then select to_jsonb(b),jsonb_build_object('content',b.content) into body,projection from public.brainstorm_entries b where b.id=eid and public.can_read_ai_brainstorm_entry(b.id,aid,pid,wid);
   when 'ACTIVITY_INSTANCE' then select x.configuration_snapshot,jsonb_build_object('method_type',x.configuration_snapshot->'method_type','instructions',x.configuration_snapshot->'instructions') into body,projection from public.activity_instances x where x.id=eid and x.id=aid and x.project_id=pid and x.workspace_id=wid and public.can_read_activity_instance(x.id);
  end case;
  if body is not null then hash0:=encode(sha256(convert_to(body::text,'UTF8')),'hex');end if;
 end if;
 if body is null or (role0='GAP' and body->>'object_type' is distinct from 'GAP') then return null;end if;
 return jsonb_build_object('entity_type',kind,'entity_id',eid,'context_role',role0,'included_snapshot_hash',hash0,'share_snapshot_id',snapshot0,'permission_scope',jsonb_build_object('access',case when snapshot0 is null then 'SOURCE' else 'SHARE_SNAPSHOT' end),'content',projection);
end$$;

create or replace function private.preserve_ai_context_reference() returns trigger
language plpgsql set search_path='' as $$
declare o public.ai_outputs;actor uuid:=public.current_platform_user_id();body jsonb;
 pid uuid;wid uuid;ss public.share_snapshots;s public.shares;access_result jsonb;
 v public.artifact_versions;a public.artifacts;f public.feedback_items;
begin
 if tg_op<>'INSERT' then raise exception 'AI context history is immutable' using errcode='55000';end if;
 select * into o from public.ai_outputs where id=new.ai_output_id for share;
 if actor is null or o.id is null or o.requested_by is distinct from actor then
  raise exception 'Context unavailable' using errcode='42501';end if;
 -- References and generated output must be saved atomically, not appended to
 -- old output after permissions/content have changed.
 -- Own transaction-ID locks include subtransactions used by atomic RPC error
 -- handling. A top-level transaction-ID comparison would wrongly reject them.
 if not exists(select 1 from public.ai_outputs x join pg_catalog.pg_locks l on l.transactionid=x.xmin
  where x.id=o.id and l.locktype='transactionid' and l.pid=pg_backend_pid() and l.mode='ExclusiveLock' and l.granted) then
  raise exception 'Context must be captured with its output' using errcode='55000';end if;
 perform public.require_development_object_write(o.project_id,o.workspace_id);
 if new.share_snapshot_id is not null then
  select * into ss from public.share_snapshots where id=new.share_snapshot_id;
  select * into s from public.shares where id=ss.share_id for share;
  access_result:=public.resolve_shared_entity_access(jsonb_build_object('shareId',s.id));
  if (access_result->>'allowed') is distinct from 'true' or not (
   (new.entity_type='ARTIFACT_VERSION' and s.shared_entity_type='ARTIFACT' and ss.source_version_id=new.entity_id)
   or (new.entity_type::text=s.shared_entity_type::text and new.entity_id=s.shared_entity_id
    and new.entity_type in ('DEVELOPMENT_OBJECT','EVIDENCE','PATENT_RECORD'))
  ) then raise exception 'Context unavailable' using errcode='42501';end if;
  body:=access_result->'snapshotContent';
  if new.context_role='GAP' and body->>'object_type' is distinct from 'GAP' then raise exception 'Context unavailable' using errcode='42501';end if;
  new.permission_scope:='{"access":"SHARE_SNAPSHOT"}';
 else
  case new.entity_type
   when 'PROJECT' then select to_jsonb(p),p.id,p.primary_workspace_id into body,pid,wid from public.development_projects p where p.id=new.entity_id for share;
   when 'ARTIFACT_VERSION' then
    select * into v from public.artifact_versions where id=new.entity_id for share;
    select * into a from public.artifacts where id=v.artifact_id for share;
    if a.id is not null and (a.artifact_type<>'MIND_MAP' or public.can_read_private_mind_map(a.id))
     and (a.artifact_type not in ('INVENTION_CONCEPT','MINIMUM_ESSENTIAL_STRUCTURE') or public.can_read_session7_output(a.id)) then
     body:=v.content_snapshot;pid:=a.project_id;wid:=a.workspace_id;
    end if;
   when 'DEVELOPMENT_OBJECT' then select to_jsonb(d),d.project_id,d.workspace_id into body,pid,wid from public.development_objects d where d.id=new.entity_id and (new.context_role<>'GAP' or d.object_type='GAP') for share;
   when 'DECISION' then select to_jsonb(d),d.project_id,d.workspace_id into body,pid,wid from public.decisions d where d.id=new.entity_id and public.can_read_decision(d.id) for share;
   when 'FEEDBACK_ITEM' then
    select * into f from public.feedback_items where id=new.entity_id for share;
    select b.* into a from public.artifacts b join public.submissions t on t.artifact_id=b.id where t.id=f.submission_id;
    if a.id is not null and (a.artifact_type<>'MIND_MAP' or public.can_read_private_mind_map(a.id))
     and (a.artifact_type not in ('INVENTION_CONCEPT','MINIMUM_ESSENTIAL_STRUCTURE') or public.can_read_session7_output(a.id)) then
     body:=to_jsonb(f);pid:=f.project_id;wid:=a.workspace_id;
    end if;
   when 'EVIDENCE' then select to_jsonb(e),e.project_id,e.workspace_id into body,pid,wid from public.evidence e where e.id=new.entity_id for share;
   when 'PATENT_RECORD' then select to_jsonb(p),p.project_id,p.workspace_id into body,pid,wid from public.patent_records p where p.id=new.entity_id for share;
   when 'BRAINSTORM_ENTRY' then select to_jsonb(b),b.project_id,b.workspace_id into body,pid,wid from public.brainstorm_entries b where b.id=new.entity_id and o.task_type='BRAINSTORMING_ASSISTANCE' and o.ai_role='BRAINSTORMING_FACILITATOR' and public.can_read_ai_brainstorm_entry(b.id,o.activity_instance_id,o.project_id,o.workspace_id) for share;
   when 'ACTIVITY_INSTANCE' then select x.configuration_snapshot,x.project_id,x.workspace_id into body,pid,wid from public.activity_instances x where x.id=new.entity_id and x.id=o.activity_instance_id and public.can_read_activity_instance(x.id) for share;
  end case;
  if body is null or (pid,wid) is distinct from (o.project_id,o.workspace_id) or not public.can_read_development_project(pid) then
   raise exception 'Context unavailable' using errcode='42501';end if;
  new.permission_scope:='{"access":"SOURCE"}';
 end if;
 if new.context_role='PRIOR_APPROVED_OUTPUT' and not exists(select 1 from public.artifact_versions where id=new.entity_id and status in ('APPROVED','CURRENT','SUPERSEDED') and approved_by is not null and approved_at is not null) then
  raise exception 'Approved context unavailable' using errcode='42501';end if;
 new.included_snapshot_hash:=encode(sha256(convert_to(body::text,'UTF8')),'hex');
 return new;
end$$;

commit;
