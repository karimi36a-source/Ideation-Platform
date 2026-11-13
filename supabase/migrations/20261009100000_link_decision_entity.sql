alter type public.project_change_type add value 'DECISION_LINK_ADDED';
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
 if new.entity_type='DECISION' and (new.change_type not in ('DECISION_CREATED','DECISION_FINALIZED','DECISION_LINK_ADDED')
 or not exists(select 1 from public.decisions d where d.id=new.entity_id and d.project_id=new.project_id and new.changed_by=public.current_platform_user_id() and ((new.change_type='DECISION_CREATED' and d.decision_owner_user_id=new.changed_by and d.status='DRAFT' and d.outcome is null and d.reasoning is null and d.decided_at is null) or (new.change_type='DECISION_LINK_ADDED' and d.status in ('DRAFT','FINALIZED') and exists(select 1 from public.decision_links dl where dl.decision_id=d.id)) or (new.change_type='DECISION_FINALIZED' and d.status='FINALIZED' and d.decided_at=new.created_at and length(private.trim_decision_text(d.outcome))>0 and length(private.trim_decision_text(d.reasoning))>0 and exists(select 1 from public.decision_participants dp where dp.decision_id=d.id and dp.user_id=new.changed_by))))
 or new.previous_version_id is not null or new.new_version_id is not null or (new.related_decision_id is not null and (new.change_type='DECISION_CREATED' or new.related_decision_id<>new.entity_id)) or new.related_evidence_id is not null or new.related_ai_output_id is not null or new.reason is not null)
 then raise exception 'Invalid Decision change context' using errcode='23514';end if;
 if new.change_type in ('DECISION_CREATED','DECISION_FINALIZED','DECISION_LINK_ADDED') and new.entity_type<>'DECISION' then raise exception 'Invalid Decision event' using errcode='23514';end if;
 return new;
end $$;



-- Parent locking serializes retries, finalization and link creation. Definer is
-- required only for default-denied link/history writes; authority stays current.
create function public.link_decision_entity(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();d public.decisions;l public.decision_links;
 target uuid;kind text;relation text;p uuid;w uuid;target_activity uuid;object_archived_at timestamptz;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in ('decisionId','linkedEntityType','linkedEntityId','relationshipType'))
 or jsonb_typeof(input->'decisionId') is distinct from 'string' or jsonb_typeof(input->'linkedEntityId') is distinct from 'string'
 or jsonb_typeof(input->'linkedEntityType') is distinct from 'string' or jsonb_typeof(input->'relationshipType') is distinct from 'string'
 then raise exception 'Invalid link input' using errcode='22023';end if;
 target:=(input->>'linkedEntityId')::uuid;kind:=input->>'linkedEntityType';relation:=input->>'relationshipType';
 if kind in ('EVIDENCE','AI_OUTPUT') then raise exception 'Target dependency unavailable' using errcode='0A000';end if;
 if not ((kind='VOTING_SESSION' and relation='INFORMED_BY') or (kind in ('ARTIFACT','DEVELOPMENT_OBJECT') and relation='CONSIDERED_IN_DECISION')) then raise exception 'Invalid link mapping' using errcode='22023';end if;
 select * into d from public.decisions where id=(input->>'decisionId')::uuid for update;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into l from public.decision_links where decision_id=d.id and linked_entity_type::text=kind and linked_entity_id=target and relationship_type=relation;
 perform private.require_decision_finalization(d.project_id,d.workspace_id,d.activity_instance_id,l.id is null);
 if kind='ARTIFACT' then
  select project_id,workspace_id into p,w from public.artifacts where id=target for share;
 elsif kind='DEVELOPMENT_OBJECT' then
  select project_id,workspace_id,archived_at into p,w,object_archived_at from public.development_objects where id=target for share;
  if object_archived_at is not null then raise exception 'Resource unavailable' using errcode='42501';end if;
 else
  select activity_instance_id into target_activity from public.voting_sessions where id=target for share;
  select project_id,workspace_id into p,w from public.activity_instances where id=target_activity for share;
  if not public.can_read_activity_instance(target_activity) then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 if p is null or (p,w) is distinct from (d.project_id,d.workspace_id) or not public.can_read_development_project(p)
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 if l.id is not null then return to_jsonb(l);end if;
 if d.status not in ('DRAFT','FINALIZED') then raise exception 'Decision is not writable' using errcode='55000';end if;
 insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type)
 values(d.id,kind::public.decision_link_entity_type,target,relation) returning * into l;
 perform private.require_decision_finalization(d.project_id,d.workspace_id,d.activity_instance_id,true);
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by,related_decision_id)
 values(d.project_id,'DECISION',d.id,'DECISION_LINK_ADDED','Decision reference added',actor,d.id);
 return to_jsonb(l);
end $$;
revoke all on function public.link_decision_entity(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.link_decision_entity(jsonb) to authenticated;
comment on function public.link_decision_entity(jsonb) is 'M10.11 immutable same-scope reference, current Lead/Master or Personal owner authority, canonical retry, no target-content or authority transfer.';
commit;
