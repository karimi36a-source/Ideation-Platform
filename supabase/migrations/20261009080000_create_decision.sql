alter type public.project_change_entity_type add value 'DECISION';
alter type public.project_change_type add value 'DECISION_CREATED';
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
 if new.entity_type='DECISION' and (new.change_type<>'DECISION_CREATED'
 or not exists(select 1 from public.decisions d where d.id=new.entity_id and d.project_id=new.project_id and d.decision_owner_user_id=new.changed_by and new.changed_by=public.current_platform_user_id() and d.status='DRAFT' and d.outcome is null and d.reasoning is null and d.decided_at is null)
 or new.previous_version_id is not null or new.new_version_id is not null or new.related_decision_id is not null or new.related_evidence_id is not null or new.related_ai_output_id is not null or new.reason is not null)
 then raise exception 'Invalid Decision change context' using errcode='23514';end if;
 if new.change_type='DECISION_CREATED' and new.entity_type<>'DECISION' then raise exception 'Invalid Decision event' using errcode='23514';end if;
 return new;
end $$;



-- Reuses M6 write locks and current canonical Project/Workspace access. The
-- additional formal-Decision authority does not confer general content access.
create function private.require_decision_creation(target_project uuid,target_workspace uuid,target_activity uuid) returns void
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
  if a.status<>'active' then raise exception 'Activity is not writable' using errcode='55000';end if;
 end if;
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
end $$;
revoke all on function private.require_decision_creation(uuid,uuid,uuid) from public,anon,authenticated,service_role;
-- Match ECMAScript String.trim used by the strict public contract, including
-- Unicode whitespace that PostgreSQL's locale-dependent regex does not remove.
create function private.trim_decision_text(value text) returns text
language sql immutable strict set search_path='' as $$
 select btrim(value,chr(9)||chr(10)||chr(11)||chr(12)||chr(13)||chr(32)||chr(160)||chr(5760)||chr(8192)||chr(8193)||chr(8194)||chr(8195)||chr(8196)||chr(8197)||chr(8198)||chr(8199)||chr(8200)||chr(8201)||chr(8202)||chr(8232)||chr(8233)||chr(8239)||chr(8287)||chr(12288)||chr(65279));
$$;
revoke all on function private.trim_decision_text(text) from public,anon,authenticated,service_role;
-- SECURITY DEFINER is necessary to write the default-denied tables atomically.
-- Auth context supplies identity; strict JSON accepts no actor or lifecycle claims.
create function public.create_decision(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid;pid uuid;wid uuid;aid uuid;choice jsonb;obj public.development_objects;oid uuid;ids uuid[]:='{}';d public.decisions;o public.decision_options;options jsonb:='[]';
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' then raise exception 'Invalid Decision input' using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(input) k where k not in ('projectId','workspaceId','activityInstanceId','title','question','method','options'))
 or jsonb_typeof(input->'projectId') is distinct from 'string' or jsonb_typeof(input->'workspaceId') is distinct from 'string'
 or (input ? 'activityInstanceId' and jsonb_typeof(input->'activityInstanceId') is distinct from 'string')
 or jsonb_typeof(input->'title') is distinct from 'string' or length(private.trim_decision_text(input->>'title'))=0
 or jsonb_typeof(input->'question') is distinct from 'string' or length(private.trim_decision_text(input->>'question'))=0
 or jsonb_typeof(input->'method') is distinct from 'string' or input->>'method' not in ('DOT_VOTE','DISCUSSION','CONSENSUS','OTHER')
 or jsonb_typeof(input->'options') is distinct from 'array' then raise exception 'Invalid Decision input' using errcode='22023';end if;
 if jsonb_array_length(input->'options')=0 then raise exception 'Invalid Decision options' using errcode='22023';end if;
 pid:=(input->>'projectId')::uuid;wid:=(input->>'workspaceId')::uuid;aid:=(input->>'activityInstanceId')::uuid;
 perform private.require_decision_creation(pid,wid,aid);
 insert into public.decisions(project_id,workspace_id,activity_instance_id,title,question,method,status,decision_owner_user_id,outcome,reasoning,decided_at)
 values(pid,wid,aid,private.trim_decision_text(input->>'title'),private.trim_decision_text(input->>'question'),(input->>'method')::public.decision_method,'DRAFT',actor,null,null,null) returning * into d;
 for choice in select value from jsonb_array_elements(input->'options') loop
  if jsonb_typeof(choice)<>'object' then raise exception 'Invalid Decision option' using errcode='22023';end if;
  if exists(select 1 from jsonb_object_keys(choice) k where k not in ('label','description','developmentObjectId'))
  or jsonb_typeof(choice->'label') is distinct from 'string' or length(private.trim_decision_text(choice->>'label'))=0
  or (choice ? 'description' and jsonb_typeof(choice->'description') is distinct from 'string')
  or (choice ? 'developmentObjectId' and jsonb_typeof(choice->'developmentObjectId') is distinct from 'string') then raise exception 'Invalid Decision option' using errcode='22023';end if;
  oid:=null;
  if choice ? 'developmentObjectId' then
   oid:=(choice->>'developmentObjectId')::uuid;
   if oid=any(ids) then raise exception 'Duplicate Object option' using errcode='22023';end if;ids:=array_append(ids,oid);
   select * into obj from public.development_objects where id=oid and project_id=pid and workspace_id=wid for share;
   if not found or obj.archived_at is not null or obj.object_type not in ('PROBLEM','SOLUTION','FEATURE') then raise exception 'Resource unavailable' using errcode='42501';end if;
  end if;
  insert into public.decision_options(decision_id,label,description,development_object_id,selected)
  values(d.id,private.trim_decision_text(choice->>'label'),choice->>'description',oid,false) returning * into o;
  options:=options||jsonb_build_array(to_jsonb(o));
 end loop;
 perform private.require_decision_creation(pid,wid,aid);
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by)
 values(pid,'DECISION',d.id,'DECISION_CREATED','Decision created',actor);
 return jsonb_build_object('decision',to_jsonb(d),'options',options);
end $$;
revoke all on function public.create_decision(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_decision(jsonb) to authenticated;
comment on function public.create_decision(jsonb) is 'M10.9 human-authored Draft only. No participants, links, selected Options, voting results or finalization. Each successful call creates a distinct Decision.';
commit;
