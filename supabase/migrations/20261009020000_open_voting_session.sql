alter type public.project_change_type add value 'VOTING_SESSION_OPENED';
begin;
create or replace function public.validate_project_change_log() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op<>'INSERT' then raise exception 'Project change history is append-only' using errcode='23514';end if;
 if (new.entity_type='PROJECT' and (new.entity_id<>new.project_id or new.change_type::text not like 'PROJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT' and (not exists(select 1 from public.development_objects o where o.id=new.entity_id and o.project_id=new.project_id) or new.change_type::text not like 'OBJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT_RELATIONSHIP' and (not exists(select 1 from public.development_object_relationships e where e.id=new.entity_id and e.project_id=new.project_id) or new.change_type::text not like 'RELATIONSHIP_%')) then raise exception 'Invalid change entity/Project' using errcode='23514';end if;
 if new.entity_type='VOTING_SESSION' and (new.change_type not in ('VOTING_SESSION_CREATED','VOTING_SESSION_OPENED')
 or not exists(select 1 from public.voting_sessions s join public.activity_instances a on a.id=s.activity_instance_id where s.id=new.entity_id and a.project_id=new.project_id and ((new.change_type='VOTING_SESSION_CREATED' and s.created_by=new.changed_by) or (new.change_type='VOTING_SESSION_OPENED' and s.status='OPEN' and s.opened_at is not null and s.closed_at is null and new.changed_by=public.current_platform_user_id())))
 or new.previous_version_id is not null or new.new_version_id is not null or new.related_decision_id is not null or new.related_evidence_id is not null or new.related_ai_output_id is not null or new.reason is not null)
 then raise exception 'Invalid Voting Session change context' using errcode='23514';end if;
 return new;
end $$;


-- Narrow owner-executed transition on otherwise default-denied voting tables.
-- Reuse immutable M10.2 authority and its canonical scope locks before the Session lock.
create function public.open_voting_session(target_session uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare s public.voting_sessions;a public.activity_instances;o public.voting_options;obj public.development_objects;
 actor uuid;ordinal integer:=0;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into s from public.voting_sessions where id=target_session;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_voting_creation(s.activity_instance_id);
 select * into s from public.voting_sessions where id=target_session for update;
 if not found or s.activity_instance_id<>a.id then raise exception 'Resource unavailable' using errcode='42501';end if;
 if s.status='CLOSED' or s.closed_at is not null or (s.status='DRAFT' and s.opened_at is not null)
 or (s.status='OPEN' and s.opened_at is null) then raise exception 'Session cannot open' using errcode='55000';end if;
 if s.voting_type<>'DOT_VOTE' or s.vote_limit is null or s.vote_limit<0 then raise exception 'Unsupported voting configuration' using errcode='22023';end if;
 for o in select * from public.voting_options where voting_session_id=s.id order by sequence for share loop
  ordinal:=ordinal+1;
  if o.sequence<>ordinal or o.label is null or length(regexp_replace(o.label,'^\s+|\s+$','','g'))=0
  then raise exception 'Invalid option configuration' using errcode='22023';end if;
  if o.development_object_id is not null then
   select * into obj from public.development_objects where id=o.development_object_id and project_id=a.project_id and workspace_id=a.workspace_id for share;
   if not found or obj.archived_at is not null or obj.object_type not in ('PROBLEM','SOLUTION','FEATURE') then raise exception 'Resource unavailable' using errcode='42501';end if;
  end if;
 end loop;
 if ordinal=0 then raise exception 'No voting options' using errcode='22023';end if;
 perform private.require_voting_creation(a.id);
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Authorized retry still validates current scope/configuration/options, but writes nothing.
 if s.status='OPEN' then return to_jsonb(s);end if;
 update public.voting_sessions set status='OPEN',opened_at=clock_timestamp() where id=s.id returning * into s;
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by)
 values(a.project_id,'VOTING_SESSION',s.id,'VOTING_SESSION_OPENED','Voting Session opened',actor);
 return to_jsonb(s);
end $$;
revoke all on function public.open_voting_session(uuid) from public,anon,authenticated,service_role;
grant execute on function public.open_voting_session(uuid) to authenticated;
commit;
