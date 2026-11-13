alter type public.project_change_type add value 'DECISION_FINALIZED';
begin;
create or replace function public.validate_project_change_log() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op<>'INSERT' then raise exception 'Project change history is append-only' using errcode='23514';end if;
 if (new.entity_type='PROJECT' and (new.entity_id<>new.project_id or new.change_type::text not like 'PROJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT' and (not exists(select 1 from public.development_objects o where o.id=new.entity_id and o.project_id=new.project_id) or new.change_type::text not like 'OBJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT_RELATIONSHIP' and (not exists(select 1 from public.development_object_relationships e where e.id=new.entity_id and e.project_id=new.project_id) or new.change_type::text not like 'RELATIONSHIP_%')) then raise exception 'Invalid change entity/Project' using errcode='23514';end if;
 if new.entity_type='VOTING_SESSION' and (new.change_type not in ('VOTING_SESSION_CREATED','VOTING_SESSION_OPENED','VOTING_SESSION_REVEALED','VOTING_SESSION_CLOSED')
 or not exists(select 1 from public.voting_sessions s join public.activity_instances a on a.id=s.activity_instance_id where s.id=new.entity_id and a.project_id=new.project_id and ((new.change_type='VOTING_SESSION_CREATED' and s.created_by=new.changed_by) or (new.change_type='VOTING_SESSION_OPENED' and s.status='OPEN' and s.opened_at is not null and s.closed_at is null and new.changed_by=public.current_platform_user_id()) or (new.change_type='VOTING_SESSION_REVEALED' and s.status='CLOSED' and s.voting_type='DOT_VOTE' and s.reveal_mode='HIDDEN_UNTIL_REVEAL' and new.changed_by=public.current_platform_user_id() and not exists(select 1 from public.votes v where v.voting_session_id=s.id and v.revealed_at is distinct from new.created_at)) or (new.change_type='VOTING_SESSION_CLOSED' and s.status='CLOSED' and s.voting_type='DOT_VOTE' and s.opened_at is not null and s.closed_at=new.created_at and new.changed_by=public.current_platform_user_id())))
 or new.previous_version_id is not null or new.new_version_id is not null or new.related_decision_id is not null or new.related_evidence_id is not null or new.related_ai_output_id is not null or new.reason is not null)
 then raise exception 'Invalid Voting Session change context' using errcode='23514';end if;
 if new.entity_type='DECISION' and (new.change_type not in ('DECISION_CREATED','DECISION_FINALIZED')
 or not exists(select 1 from public.decisions d where d.id=new.entity_id and d.project_id=new.project_id and new.changed_by=public.current_platform_user_id() and ((new.change_type='DECISION_CREATED' and d.decision_owner_user_id=new.changed_by and d.status='DRAFT' and d.outcome is null and d.reasoning is null and d.decided_at is null) or (new.change_type='DECISION_FINALIZED' and d.status='FINALIZED' and d.decided_at=new.created_at and length(private.trim_decision_text(d.outcome))>0 and length(private.trim_decision_text(d.reasoning))>0 and exists(select 1 from public.decision_participants dp where dp.decision_id=d.id and dp.user_id=new.changed_by))))
 or new.previous_version_id is not null or new.new_version_id is not null or (new.related_decision_id is not null and (new.change_type='DECISION_CREATED' or new.related_decision_id<>new.entity_id)) or new.related_evidence_id is not null or new.related_ai_output_id is not null or new.reason is not null)
 then raise exception 'Invalid Decision change context' using errcode='23514';end if;
 if new.change_type in ('DECISION_CREATED','DECISION_FINALIZED') and new.entity_type<>'DECISION' then raise exception 'Invalid Decision event' using errcode='23514';end if;
 return new;
end $$;



create function private.require_decision_finalization(target_project uuid,target_workspace uuid,target_activity uuid,first_transition boolean) returns void
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();p public.development_projects;w public.workspaces;a public.activity_instances;checked_at timestamptz;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if current_setting('transaction_isolation')<>'read committed' then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(target_project,target_workspace);
 select * into p from public.development_projects where id=target_project;
 select * into w from public.workspaces where id=target_workspace;
 checked_at:=clock_timestamp();
 if w.workspace_type='PERSONAL' then
  if p.project_type<>'individual' or p.owner_user_id is distinct from actor or w.owner_user_id is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 elsif w.workspace_type='TEAM' then
  if not exists(select 1 from public.role_assignments ra join public.roles rr on rr.id=ra.role_id
   where ra.user_id=actor and rr.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.cohort_id=w.cohort_id and ra.team_id is null) or (ra.team_id=w.team_id and ra.cohort_id is null)))
  and not exists(select 1 from public.teams t join public.team_memberships m on m.team_id=t.id
   where t.id=w.team_id and t.team_lead_user_id=actor and m.user_id=actor and m.membership_role='team_lead' and m.status='active' and m.left_at is null and m.joined_at<=checked_at)
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 else raise exception 'Resource unavailable' using errcode='42501';end if;
 if target_activity is not null then
  perform 1 from public.project_program_links where project_id=p.id for share;
  select * into a from public.activity_instances where id=target_activity for share;
  if not found or a.project_id<>p.id or a.workspace_id<>w.id or a.team_id is distinct from p.owner_team_id or not public.can_read_activity_instance(a.id)
  then raise exception 'Resource unavailable' using errcode='42501';end if;
  if first_transition and a.status<>'active' then raise exception 'Activity is not writable' using errcode='55000';end if;
 end if;
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
end $$;
revoke all on function private.require_decision_finalization(uuid,uuid,uuid,boolean) from public,anon,authenticated,service_role;

-- Stable owner provenance never confers Team authority. M6 locks canonical
-- membership, enrollment, Project and Workspace inputs; M10 adds Lead/Master.
-- Definer writes are needed for default-denied tables, not general client CRUD.
create function public.finalize_decision(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid;d public.decisions;chosen uuid;result_outcome text;result_reasoning text;
 artifact_ids uuid[]:='{}';object_ids uuid[]:='{}';stored_ids uuid[];x jsonb;k text;target uuid;finished_at timestamptz;
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
    if k='linkedEvidenceIds' then raise exception 'Evidence requires M12' using errcode='0A000';end if;
    if k='linkedArtifactIds' then
     if target=any(artifact_ids) then raise exception 'Duplicate Artifact' using errcode='22023';end if;artifact_ids:=array_append(artifact_ids,target);
    else
     if target=any(object_ids) then raise exception 'Duplicate Object' using errcode='22023';end if;object_ids:=array_append(object_ids,target);
    end if;
   end loop;
  end if;
 end loop;
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
  return to_jsonb(d);
 end if;
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
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by,created_at,related_decision_id)
 values(d.project_id,'DECISION',d.id,'DECISION_FINALIZED','Decision finalized',actor,finished_at,d.id);
 return to_jsonb(d);
end $$;
revoke all on function public.finalize_decision(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.finalize_decision(jsonb) to authenticated;
comment on function public.finalize_decision(jsonb) is 'M10.10 explicit human finalization; current owner-only Personal or current Lead/Master Team authority; parent lock, semantic retry/conflict, no voting inference or source mutation.';
commit;
