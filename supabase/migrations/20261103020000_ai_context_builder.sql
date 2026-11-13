begin;
-- Caller-bound exact Snapshot identity; existing M13 resolver is the only Share
-- authority. This helper never hydrates a source entity or source Workspace.
create function public.resolve_ai_context_share(target_share uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare access0 jsonb;snapshot0 public.share_snapshots;
begin
 if public.current_platform_user_id() is null then return null;end if;
 access0:=public.resolve_shared_entity_access(jsonb_build_object('shareId',target_share));
 if access0->>'allowed' is distinct from 'true' then return null;end if;
 select * into snapshot0 from public.share_snapshots where share_id=target_share;
 if snapshot0.id is null then return null;end if;
 return jsonb_build_object('access',access0,'snapshotId',snapshot0.id,
  'hash',encode(sha256(convert_to((access0->'snapshotContent')::text,'UTF8')),'hex'));
end$$;
revoke all on function public.resolve_ai_context_share(uuid) from public,anon,authenticated,service_role;
grant execute on function public.resolve_ai_context_share(uuid) to authenticated;

-- Read-only INVOKER: existing RLS applies independently to every normal source.
-- An exact foreign source ID, child reference or review role never widens the
-- current Project/Workspace envelope. No arbitrary actor, path, hash or row body.
create function public.resolve_ai_context_source(input jsonb) returns jsonb
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
 if not coalesce(case role0 when 'CURRENT_PROJECT' then kind='PROJECT' when 'CURRENT_ARTIFACT' then kind='ARTIFACT_VERSION' when 'PRIOR_APPROVED_OUTPUT' then kind='ARTIFACT_VERSION' when 'TEAM_DECISION' then kind='DECISION' when 'INSTRUCTOR_FEEDBACK' then kind='FEEDBACK_ITEM' when 'EVIDENCE' then kind='EVIDENCE' when 'PATENT' then kind='PATENT_RECORD' when 'GAP' then kind='DEVELOPMENT_OBJECT' when 'COURSE_CONTEXT' then kind='ACTIVITY_INSTANCE' else false end,false) then raise exception 'Invalid context request' using errcode='22023';end if;
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
   when 'ACTIVITY_INSTANCE' then select x.configuration_snapshot,jsonb_build_object('method_type',x.configuration_snapshot->'method_type','instructions',x.configuration_snapshot->'instructions') into body,projection from public.activity_instances x where x.id=eid and x.id=aid and x.project_id=pid and x.workspace_id=wid and public.can_read_activity_instance(x.id);
  end case;
  if body is not null then hash0:=encode(sha256(convert_to(body::text,'UTF8')),'hex');end if;
 end if;
 if body is null or (role0='GAP' and body->>'object_type' is distinct from 'GAP') then return null;end if;
 return jsonb_build_object('entity_type',kind,'entity_id',eid,'context_role',role0,'included_snapshot_hash',hash0,'share_snapshot_id',snapshot0,'permission_scope',jsonb_build_object('access',case when snapshot0 is null then 'SOURCE' else 'SHARE_SNAPSHOT' end),'content',projection);
end$$;
revoke all on function public.resolve_ai_context_source(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.resolve_ai_context_source(jsonb) to authenticated;
commit;
