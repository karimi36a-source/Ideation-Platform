begin;
-- M12.18 canonical Evidence -> Decision integration. No new tables or ACLs.
create or replace function public.link_evidence(input jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();e public.evidence;l public.evidence_links;kind public.evidence_link_entity_type;relation public.evidence_relationship_type;target uuid;source uuid;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in ('evidenceId','entityType','entityId','relationshipType','notes'))
 or jsonb_typeof(input->'evidenceId') is distinct from 'string' or jsonb_typeof(input->'entityId') is distinct from 'string'
 or jsonb_typeof(input->'entityType') is distinct from 'string' or jsonb_typeof(input->'relationshipType') is distinct from 'string'
 or (input ? 'notes' and jsonb_typeof(input->'notes') is distinct from 'string')
 then raise exception 'Invalid link input' using errcode='22023';end if;
 source:=(input->>'evidenceId')::uuid;target:=(input->>'entityId')::uuid;
 kind:=(input->>'entityType')::public.evidence_link_entity_type;relation:=(input->>'relationshipType')::public.evidence_relationship_type;
 select * into e from public.evidence where id=source;
 if e.id is null or not public.can_read_development_project(e.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(e.project_id,e.workspace_id);
 -- Parent lock serializes duplicate creation and archive; canonical write
 -- validation locks current account/enrollment/Team/Project authority.
 -- Match finalize_decision: acquire the Decision before the Evidence row.
 -- This changes lock ordering only; existing endpoint authorization remains.
 if kind='DECISION' then perform 1 from public.decisions where id=target for share;end if;
 select * into e from public.evidence where id=source for update;
 if kind='PATENT_RECORD' then raise exception 'Target dependency unavailable' using errcode='0A000';end if;
 if kind='ARTIFACT' then perform 1 from public.artifacts where id=target for share;
 elsif kind<>'DECISION' then perform 1 from public.development_objects where id=target for share;end if;
 perform public.require_development_object_write(e.project_id,e.workspace_id);
 select * into l from public.evidence_links where evidence_id=source and linked_entity_type=kind and linked_entity_id=target and relationship_type=relation and archived_at is null;
 if not private.evidence_target_allowed(kind,target,e.project_id,e.workspace_id,l.id is null) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if l.id is not null then return to_jsonb(l);end if;
 if e.archived_at is not null then raise exception 'Resource unavailable' using errcode='42501';end if;
 insert into public.evidence_links(evidence_id,linked_entity_type,linked_entity_id,relationship_type,notes,created_by)
 values(source,kind,target,relation,input->>'notes',actor) returning * into l;
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 return to_jsonb(l);
end $$;
revoke all on function public.link_evidence(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.link_evidence(jsonb) to authenticated;

create or replace function public.finalize_decision(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid;d public.decisions;chosen uuid;result_outcome text;result_reasoning text;
 evidence_ids uuid[]:='{}';artifact_ids uuid[]:='{}';object_ids uuid[]:='{}';stored_ids uuid[];x jsonb;k text;target uuid;finished_at timestamptz;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' then raise exception 'Invalid finalization input' using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(input) f where f not in ('decisionId','selectedOptionId','outcome','reasoning','linkedEvidenceIds','linkedArtifactIds','linkedObjectIds'))
 or jsonb_typeof(input->'decisionId') is distinct from 'string'
 or (input ? 'selectedOptionId' and jsonb_typeof(input->'selectedOptionId') is distinct from 'string')
 or jsonb_typeof(input->'outcome') is distinct from 'string' or length(private.trim_decision_text(input->>'outcome'))=0
 or jsonb_typeof(input->'reasoning') is distinct from 'string' or length(private.trim_decision_text(input->>'reasoning'))=0
 then raise exception 'Invalid finalization input' using errcode='22023';end if;
 result_outcome:=private.trim_decision_text(input->>'outcome');result_reasoning:=private.trim_decision_text(input->>'reasoning');
 chosen:=(input->>'selectedOptionId')::uuid;
 -- Serialize both identical and conflicting requests at the canonical parent.
 select * into d from public.decisions where id=(input->>'decisionId')::uuid for update;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform private.require_decision_finalization(d.project_id,d.workspace_id,d.activity_instance_id,d.status<>'FINALIZED');
 if d.status not in ('DRAFT','FINALIZED') then raise exception 'Decision is not finalizable' using errcode='55000';end if;
 foreach k in array array['linkedEvidenceIds','linkedArtifactIds','linkedObjectIds'] loop
  if input ? k then
   if jsonb_typeof(input->k)<>'array' then raise exception 'Invalid link array' using errcode='22023';end if;
   for x in select value from jsonb_array_elements(input->k) loop
    if jsonb_typeof(x)<>'string' then raise exception 'Invalid link UUID' using errcode='22023';end if;
    target:=(x#>>'{}')::uuid;
    if k='linkedEvidenceIds' then
     if not target=any(evidence_ids) then evidence_ids:=array_append(evidence_ids,target);end if;
    elsif k='linkedArtifactIds' then
     if target=any(artifact_ids) then raise exception 'Duplicate Artifact' using errcode='22023';end if;artifact_ids:=array_append(artifact_ids,target);
    else
     if target=any(object_ids) then raise exception 'Duplicate Object' using errcode='22023';end if;object_ids:=array_append(object_ids,target);
    end if;
   end loop;
  end if;
 end loop;
 -- Decision lock precedes Evidence locks in every Decision/Evidence operation.
 -- Explicit source authorization is required even when M10 finalization authority
 -- exists independently (for example, instructional role without private reads).
 if (cardinality(evidence_ids)>0 or exists(select 1 from public.evidence_links l where l.linked_entity_type='DECISION' and l.linked_entity_id=d.id and l.relationship_type='SUPPORTS' and l.archived_at is null)) and not public.can_read_decision(d.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if exists(select 1 from unnest(evidence_ids) req(id) where not exists(select 1 from public.evidence e where e.id=req.id and e.project_id=d.project_id and e.workspace_id=d.workspace_id and public.can_read_development_project(e.project_id))) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform 1 from public.evidence where id=any(evidence_ids) and project_id=d.project_id and workspace_id=d.workspace_id order by id for update;
 if exists(select 1 from unnest(evidence_ids) req(id) where not exists(select 1 from public.evidence e where e.id=req.id and e.project_id=d.project_id and e.workspace_id=d.workspace_id and public.can_read_development_project(e.project_id))) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if d.status='DRAFT' and exists(select 1 from public.evidence_links l where l.linked_entity_type='DECISION' and l.linked_entity_id=d.id and l.relationship_type='SUPPORTS' and l.archived_at is null and not l.evidence_id=any(evidence_ids)) then raise exception 'Finalization conflicts with persisted links' using errcode='40001';end if;
 if chosen is not null and not exists(select 1 from public.decision_options where id=chosen and decision_id=d.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Current canonical Project/Workspace access has already been locked. Targets
 -- must share that exact scope; reviewer exceptions cannot expand it.
 perform 1 from public.artifacts where id=any(artifact_ids) order by id for share;
 if exists(select 1 from unnest(artifact_ids) req(id) where not exists(select 1 from public.artifacts a where a.id=req.id and a.project_id=d.project_id and a.workspace_id=d.workspace_id)) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform 1 from public.development_objects where id=any(object_ids) order by id for share;
 if exists(select 1 from unnest(object_ids) req(id) where not exists(select 1 from public.development_objects o where o.id=req.id and o.project_id=d.project_id and o.workspace_id=d.workspace_id)) then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Preserve pre-existing considered links without accepting a payload whose
 -- immediate identical retry would conflict with the persisted final set.
 if d.status='DRAFT' and exists(select 1 from public.decision_links l where l.decision_id=d.id and l.relationship_type='CONSIDERED_IN_DECISION'
  and ((l.linked_entity_type='ARTIFACT' and not l.linked_entity_id=any(artifact_ids)) or (l.linked_entity_type='DEVELOPMENT_OBJECT' and not l.linked_entity_id=any(object_ids))))
 then raise exception 'Finalization conflicts with persisted links' using errcode='40001';end if;
 if d.status='FINALIZED' then
  if d.outcome is distinct from result_outcome or d.reasoning is distinct from result_reasoning
  or array(select id from public.decision_options where decision_id=d.id and selected order by id) is distinct from array(select chosen where chosen is not null)
  then raise exception 'Finalization conflicts with persisted state' using errcode='40001';end if;
  select coalesce(array_agg(linked_entity_id order by linked_entity_id),'{}'::uuid[]) into stored_ids from public.decision_links where decision_id=d.id and linked_entity_type='ARTIFACT' and relationship_type='CONSIDERED_IN_DECISION';
  if stored_ids is distinct from array(select id from unnest(artifact_ids) id order by id) then raise exception 'Finalization conflicts with persisted state' using errcode='40001';end if;
  select coalesce(array_agg(linked_entity_id order by linked_entity_id),'{}'::uuid[]) into stored_ids from public.decision_links where decision_id=d.id and linked_entity_type='DEVELOPMENT_OBJECT' and relationship_type='CONSIDERED_IN_DECISION';
  if stored_ids is distinct from array(select id from unnest(object_ids) id order by id) then raise exception 'Finalization conflicts with persisted state' using errcode='40001';end if;
  select coalesce(array_agg(evidence_id order by evidence_id),'{}'::uuid[]) into stored_ids from public.evidence_links where linked_entity_type='DECISION' and linked_entity_id=d.id and relationship_type='SUPPORTS' and archived_at is null;
  if stored_ids is distinct from array(select id from unnest(evidence_ids) id order by id) then raise exception 'Finalization conflicts with persisted state' using errcode='40001';end if;
  return to_jsonb(d);
 end if;
 -- Reuse the accepted canonical link operation; no second Evidence table or
 -- Decision Link row is created and no verification/source field is modified.
 for target in select id from unnest(evidence_ids) id order by id loop
  perform public.link_evidence(jsonb_build_object('evidenceId',target,'entityType','DECISION','entityId',d.id,'relationshipType','SUPPORTS'));
 end loop;
 update public.decision_options set selected=(chosen is not null and id=chosen) where decision_id=d.id;
 insert into public.decision_participants(decision_id,user_id,role,position,comment) values(d.id,actor,'FINALIZER',null,null) on conflict(decision_id,user_id) do nothing;
 insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type)
 select d.id,'ARTIFACT',id,'CONSIDERED_IN_DECISION' from unnest(artifact_ids) id
 on conflict(decision_id,linked_entity_type,linked_entity_id,relationship_type) do nothing;
 insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type)
 select d.id,'DEVELOPMENT_OBJECT',id,'CONSIDERED_IN_DECISION' from unnest(object_ids) id
 on conflict(decision_id,linked_entity_type,linked_entity_id,relationship_type) do nothing;
 finished_at:=clock_timestamp();
 update public.decisions set outcome=result_outcome,reasoning=result_reasoning,status='FINALIZED',decided_at=finished_at where id=d.id returning * into d;
 -- Recheck temporal authority at commit boundary; held locks prevent revocation
 -- races, while this rejects assignments expiring during the operation.
 perform private.require_decision_finalization(d.project_id,d.workspace_id,d.activity_instance_id,true);
 if cardinality(evidence_ids)>0 and (not public.can_read_decision(d.id) or not public.can_read_development_project(d.project_id)) then raise exception 'Resource unavailable' using errcode='42501';end if;
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by,created_at,related_decision_id)
 values(d.project_id,'DECISION',d.id,'DECISION_FINALIZED','Decision finalized',actor,finished_at,d.id);
 return to_jsonb(d);
end $$;
revoke all on function public.finalize_decision(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.finalize_decision(jsonb) to authenticated;

comment on function public.finalize_decision(jsonb) is 'Explicit M10 finalization with exact-scope independently readable M12 Evidence SUPPORTS links; atomic, duplicate-safe, semantic retry; no verification or source mutation.';
commit;
