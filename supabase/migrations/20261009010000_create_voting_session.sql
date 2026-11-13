alter type public.project_change_entity_type add value 'VOTING_SESSION';
alter type public.project_change_type add value 'VOTING_SESSION_CREATED';
begin;
create or replace function public.validate_project_change_log() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op<>'INSERT' then raise exception 'Project change history is append-only' using errcode='23514';end if;
 if (new.entity_type='PROJECT' and (new.entity_id<>new.project_id or new.change_type::text not like 'PROJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT' and (not exists(select 1 from public.development_objects o where o.id=new.entity_id and o.project_id=new.project_id) or new.change_type::text not like 'OBJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT_RELATIONSHIP' and (not exists(select 1 from public.development_object_relationships e where e.id=new.entity_id and e.project_id=new.project_id) or new.change_type::text not like 'RELATIONSHIP_%')) then raise exception 'Invalid change entity/Project' using errcode='23514';end if;
 if new.entity_type='VOTING_SESSION' and (new.change_type<>'VOTING_SESSION_CREATED'
 or not exists(select 1 from public.voting_sessions s join public.activity_instances a on a.id=s.activity_instance_id where s.id=new.entity_id and a.project_id=new.project_id and s.created_by=new.changed_by)
 or new.previous_version_id is not null or new.new_version_id is not null or new.related_decision_id is not null or new.related_evidence_id is not null or new.related_ai_output_id is not null or new.reason is not null)
 then raise exception 'Invalid Voting Session change context' using errcode='23514';end if;
 return new;
end $$;

-- Owner execution is necessary for narrowly authorized writes to default-denied tables.
-- Identity is always verified through the session; no actor/scope claims are accepted.
create function private.require_voting_creation(target_instance uuid) returns public.activity_instances
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;checked_at timestamptz;authority text;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if current_setting('transaction_isolation')<>'read committed' or not public.can_read_activity_instance(target_instance) then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into a from public.activity_instances where id=target_instance;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 perform 1 from public.cohorts where id=a.cohort_id for share;
 perform 1 from public.project_program_links where project_id=a.project_id for share;
 select * into a from public.activity_instances where id=target_instance for share;
 if public.current_platform_user_id() is distinct from actor or not public.can_read_activity_instance(a.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if a.status<>'active' then raise exception 'Activity not writable' using errcode='55000';end if;
 authority:=a.configuration_snapshot #>> '{configuration,voting,session_creation_authority}';
 if a.configuration_snapshot->>'method_type' is distinct from 'voting'
 or a.configuration_snapshot #> '{configuration,voting,enabled}' is distinct from 'true'::jsonb
 or a.configuration_snapshot #>> '{configuration,voting,voting_type}' is distinct from 'DOT_VOTE'
 or authority is null or authority not in ('scoped_master_only','scoped_master_or_team_lead')
 then raise exception 'Required Activity configuration unavailable' using errcode='0A000';end if;
 checked_at:=clock_timestamp();
 if not exists(select 1 from public.role_assignments ra join public.roles rr on rr.id=ra.role_id
 where ra.user_id=actor and rr.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
 and ra.organization_id is null and ra.program_id is null and ra.project_id is null
 and ((ra.cohort_id=a.cohort_id and ra.team_id is null) or (ra.team_id=a.team_id and ra.cohort_id is null)))
 and not (authority='scoped_master_or_team_lead' and a.team_id is not null and exists(
 select 1 from public.team_memberships m join public.teams t on t.id=m.team_id
 where m.team_id=a.team_id and m.user_id=actor and t.team_lead_user_id=actor and m.membership_role='team_lead'
 and m.status='active' and m.left_at is null and m.joined_at<=checked_at))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 return a;
end $$;
revoke all on function private.require_voting_creation(uuid) from public,anon,authenticated,service_role;
create function public.create_voting_session(target_instance uuid,kind text,dot_limit integer,is_anonymous boolean,visibility text,choices jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;s public.voting_sessions;choice jsonb;obj public.development_objects;ids uuid[]:='{}';object_id uuid;ordinal integer:=0;result jsonb;actor uuid;
begin
 a:=private.require_voting_creation(target_instance);actor:=public.current_platform_user_id();
 if kind is distinct from 'DOT_VOTE' or dot_limit is null or dot_limit<0 or is_anonymous is null or visibility is null or visibility not in ('LIVE','HIDDEN_UNTIL_REVEAL')
 or choices is null or jsonb_typeof(choices)<>'array' then raise exception 'Invalid voting input' using errcode='22023';end if;
 if jsonb_array_length(choices)=0 then raise exception 'Invalid voting options' using errcode='22023';end if;
 insert into public.voting_sessions(activity_instance_id,voting_type,status,vote_limit,anonymous,reveal_mode,created_by)
 values(a.id,'DOT_VOTE','DRAFT',dot_limit,is_anonymous,visibility::public.voting_reveal_mode,actor) returning * into s;
 for choice in select value from jsonb_array_elements(choices) loop
  if jsonb_typeof(choice)<>'object' then raise exception 'Invalid option' using errcode='22023';end if;
  if exists(select 1 from jsonb_object_keys(choice) k where k not in ('developmentObjectId','label','description'))
  or jsonb_typeof(choice->'label') is distinct from 'string' or length(regexp_replace(choice->>'label','^\s+|\s+$','','g'))=0
  or (choice ? 'description' and jsonb_typeof(choice->'description') is distinct from 'string')
  or (choice ? 'developmentObjectId' and jsonb_typeof(choice->'developmentObjectId') is distinct from 'string')
  then raise exception 'Invalid option' using errcode='22023';end if;
  object_id:=null;
  if choice ? 'developmentObjectId' then
   object_id:=(choice->>'developmentObjectId')::uuid;
   if object_id=any(ids) then raise exception 'Duplicate Object option' using errcode='22023';end if;
   ids:=array_append(ids,object_id);
   select * into obj from public.development_objects where id=object_id and project_id=a.project_id and workspace_id=a.workspace_id for share;
   if not found or obj.archived_at is not null or obj.object_type not in ('PROBLEM','SOLUTION','FEATURE') then raise exception 'Resource unavailable' using errcode='42501';end if;
  end if;
  ordinal:=ordinal+1;
  insert into public.voting_options(voting_session_id,development_object_id,label,description,sequence)
  values(s.id,object_id,choice->>'label',choice->>'description',ordinal);
 end loop;
 -- Recheck temporal authority at the write boundary; immutable config and scope locks remain held.
 perform private.require_voting_creation(a.id);
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by)
 values(a.project_id,'VOTING_SESSION',s.id,'VOTING_SESSION_CREATED','Voting Session created',actor);
 select jsonb_agg(to_jsonb(o) order by o.sequence) into result from public.voting_options o where o.voting_session_id=s.id;
 return jsonb_build_object('session',to_jsonb(s),'options',result);
end $$;
revoke all on function public.create_voting_session(uuid,text,integer,boolean,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_voting_session(uuid,text,integer,boolean,text,jsonb) to authenticated;
commit;
