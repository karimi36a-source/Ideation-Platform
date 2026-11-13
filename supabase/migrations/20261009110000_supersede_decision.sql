-- Add enum values before the transaction so new labels are committed before use.
alter type public.decision_link_entity_type add value 'DECISION';
alter type public.project_change_type add value 'DECISION_SUPERSEDED';
begin;
alter table public.decision_links drop constraint decision_links_supported_target;
alter table public.decision_links add constraint decision_links_supported_target check
 ((linked_entity_type in ('VOTING_SESSION','ARTIFACT','DEVELOPMENT_OBJECT') and relationship_type<>'SUPERSEDES')
 or (linked_entity_type='DECISION' and relationship_type='SUPERSEDES' and decision_id<>linked_entity_id));
create unique index decision_links_one_successor on public.decision_links(linked_entity_id) where linked_entity_type='DECISION';
create unique index decision_links_one_predecessor on public.decision_links(decision_id) where linked_entity_type='DECISION';
create or replace function public.validate_decision_reference_scope() returns trigger language plpgsql set search_path='' as $$
declare d public.decisions;target_project uuid;target_workspace uuid;
begin
 select * into d from public.decisions where id=new.decision_id for share;
 if not found then raise exception 'Invalid Decision reference' using errcode='23503';end if;
 if tg_table_name='decision_options' then
  if new.development_object_id is null then return new;end if;
  select project_id,workspace_id into target_project,target_workspace from public.development_objects where id=new.development_object_id for share;
 elsif new.linked_entity_type='DECISION' then
  if new.relationship_type<>'SUPERSEDES' or new.decision_id=new.linked_entity_id then raise exception 'Invalid supersession relationship' using errcode='23514';end if;
  select project_id,workspace_id into target_project,target_workspace from public.decisions where id=new.linked_entity_id for share;
 elsif new.linked_entity_type='DEVELOPMENT_OBJECT' then
  select project_id,workspace_id into target_project,target_workspace from public.development_objects where id=new.linked_entity_id for share;
 elsif new.linked_entity_type='ARTIFACT' then
  select project_id,workspace_id into target_project,target_workspace from public.artifacts where id=new.linked_entity_id for share;
 elsif new.linked_entity_type='VOTING_SESSION' then
  select a.project_id,a.workspace_id into target_project,target_workspace from public.voting_sessions s join public.activity_instances a on a.id=s.activity_instance_id where s.id=new.linked_entity_id for share of s,a;
 else raise exception 'Unsupported Decision target' using errcode='23514';end if;
 if target_project is null then raise exception 'Invalid Decision target' using errcode='23503';end if;
 if (d.project_id,d.workspace_id) is distinct from (target_project,target_workspace) then raise exception 'Invalid Decision scope' using errcode='23514';end if;
 return new;
end $$;

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
 if new.entity_type='DECISION' and ((new.change_type='DECISION_SUPERSEDED' and new.related_decision_id is null) or new.change_type not in ('DECISION_CREATED','DECISION_FINALIZED','DECISION_LINK_ADDED','DECISION_SUPERSEDED')
 or not exists(select 1 from public.decisions d where d.id=new.entity_id and d.project_id=new.project_id and new.changed_by=public.current_platform_user_id() and ((new.change_type='DECISION_SUPERSEDED' and d.status='SUPERSEDED' and exists(select 1 from public.decision_links l join public.decisions replacement on replacement.id=l.decision_id where l.linked_entity_type='DECISION' and l.relationship_type='SUPERSEDES' and l.linked_entity_id=d.id and l.decision_id=new.related_decision_id and replacement.status='FINALIZED' and replacement.project_id=d.project_id and replacement.workspace_id=d.workspace_id)) or (new.change_type='DECISION_CREATED' and d.decision_owner_user_id=new.changed_by and d.status='DRAFT' and d.outcome is null and d.reasoning is null and d.decided_at is null) or (new.change_type='DECISION_LINK_ADDED' and d.status in ('DRAFT','FINALIZED') and exists(select 1 from public.decision_links dl where dl.decision_id=d.id)) or (new.change_type='DECISION_FINALIZED' and d.status='FINALIZED' and d.decided_at=new.created_at and length(private.trim_decision_text(d.outcome))>0 and length(private.trim_decision_text(d.reasoning))>0 and exists(select 1 from public.decision_participants dp where dp.decision_id=d.id and dp.user_id=new.changed_by))))
 or new.previous_version_id is not null or new.new_version_id is not null or (new.related_decision_id is not null and (new.change_type='DECISION_CREATED' or (new.change_type<>'DECISION_SUPERSEDED' and new.related_decision_id<>new.entity_id))) or new.related_evidence_id is not null or new.related_ai_output_id is not null or new.reason is not null)
 then raise exception 'Invalid Decision change context' using errcode='23514';end if;
 if new.change_type in ('DECISION_CREATED','DECISION_FINALIZED','DECISION_LINK_ADDED','DECISION_SUPERSEDED') and new.entity_type<>'DECISION' then raise exception 'Invalid Decision event' using errcode='23514';end if;
 return new;
end $$;
-- Default-denied tables require a definer for atomic writes, never for authority.
-- Both rows lock in UUID order before current M10.10 authority is evaluated.
create function public.supersede_decision(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();old_id uuid;new_id uuid;
 older public.decisions;newer public.decisions;link public.decision_links;retry boolean;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in ('oldDecisionId','newDecisionId'))
 or jsonb_typeof(input->'oldDecisionId') is distinct from 'string'
 or jsonb_typeof(input->'newDecisionId') is distinct from 'string' then raise exception 'Invalid supersession input' using errcode='22023';end if;
 old_id:=(input->>'oldDecisionId')::uuid;new_id:=(input->>'newDecisionId')::uuid;
 if old_id=new_id then raise exception 'Self supersession is invalid' using errcode='22023';end if;
 perform 1 from public.decisions where id in (old_id,new_id) order by id for update;
 select * into older from public.decisions where id=old_id;
 select * into newer from public.decisions where id=new_id;
 if older.id is null or newer.id is null then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into link from public.decision_links where decision_id=new_id and linked_entity_type='DECISION' and linked_entity_id=old_id and relationship_type='SUPERSEDES';
 retry:=link.id is not null;
 perform private.require_decision_finalization(older.project_id,older.workspace_id,older.activity_instance_id,not retry);
 perform private.require_decision_finalization(newer.project_id,newer.workspace_id,newer.activity_instance_id,not retry);
 if (older.project_id,older.workspace_id) is distinct from (newer.project_id,newer.workspace_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if retry then
  if older.status<>'SUPERSEDED' or newer.status<>'FINALIZED' then raise exception 'Supersession conflicts with persisted state' using errcode='40001';end if;
  return to_jsonb(link);
 end if;
 if exists(select 1 from public.decision_links where linked_entity_type='DECISION' and (linked_entity_id=old_id or decision_id=new_id))
 then raise exception 'Supersession conflicts with persisted history' using errcode='40001';end if;
 if older.status<>'FINALIZED' or newer.status<>'FINALIZED' then raise exception 'Decision is not supersedable' using errcode='55000';end if;
 if older.decided_at is null or newer.decided_at is null or newer.decided_at<=older.decided_at then raise exception 'Replacement must be later' using errcode='22023';end if;
 update public.decisions set status='SUPERSEDED' where id=old_id;
 insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type)
 values(new_id,'DECISION',old_id,'SUPERSEDES') returning * into link;
 perform private.require_decision_finalization(older.project_id,older.workspace_id,older.activity_instance_id,true);
 perform private.require_decision_finalization(newer.project_id,newer.workspace_id,newer.activity_instance_id,true);
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by,related_decision_id)
 values(older.project_id,'DECISION',old_id,'DECISION_SUPERSEDED','Decision superseded',actor,new_id);
 return to_jsonb(link);
end $$;
revoke all on function public.supersede_decision(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.supersede_decision(jsonb) to authenticated;
comment on function public.supersede_decision(jsonb) is 'M10.12 explicit linear same-scope history; current authority; deterministic locks; canonical retry; no source or baseline mutation.';
commit;
