alter type public.project_change_type add value 'VOTING_SESSION_REVEALED';
begin;
create or replace function public.validate_project_change_log() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op<>'INSERT' then raise exception 'Project change history is append-only' using errcode='23514';end if;
 if (new.entity_type='PROJECT' and (new.entity_id<>new.project_id or new.change_type::text not like 'PROJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT' and (not exists(select 1 from public.development_objects o where o.id=new.entity_id and o.project_id=new.project_id) or new.change_type::text not like 'OBJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT_RELATIONSHIP' and (not exists(select 1 from public.development_object_relationships e where e.id=new.entity_id and e.project_id=new.project_id) or new.change_type::text not like 'RELATIONSHIP_%')) then raise exception 'Invalid change entity/Project' using errcode='23514';end if;
 if new.entity_type='VOTING_SESSION' and (new.change_type not in ('VOTING_SESSION_CREATED','VOTING_SESSION_OPENED','VOTING_SESSION_REVEALED')
 or not exists(select 1 from public.voting_sessions s join public.activity_instances a on a.id=s.activity_instance_id where s.id=new.entity_id and a.project_id=new.project_id and ((new.change_type='VOTING_SESSION_CREATED' and s.created_by=new.changed_by) or (new.change_type='VOTING_SESSION_OPENED' and s.status='OPEN' and s.opened_at is not null and s.closed_at is null and new.changed_by=public.current_platform_user_id()) or (new.change_type='VOTING_SESSION_REVEALED' and s.status='CLOSED' and s.voting_type='DOT_VOTE' and s.reveal_mode='HIDDEN_UNTIL_REVEAL' and new.changed_by=public.current_platform_user_id() and not exists(select 1 from public.votes v where v.voting_session_id=s.id and v.revealed_at is distinct from new.created_at))))
 or new.previous_version_id is not null or new.new_version_id is not null or new.related_decision_id is not null or new.related_evidence_id is not null or new.related_ai_output_id is not null or new.reason is not null)
 then raise exception 'Invalid Voting Session change context' using errcode='23514';end if;
 return new;
end $$;


-- Narrow owner execution permits authorized reveal on otherwise default-denied rows.
-- Canonical parent locks precede the same Session lock used by casting/opening.
create function public.reveal_voting_session(target_session uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare s public.voting_sessions;a public.activity_instances;actor uuid;stamp timestamptz;
 total bigint;shown bigint;distinct_stamps bigint;events bigint;event_stamp timestamptz;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into s from public.voting_sessions where id=target_session;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_voting_creation(s.activity_instance_id);
 select * into s from public.voting_sessions where id=target_session for update;
 if not found or s.activity_instance_id<>a.id or a.team_id is null then raise exception 'Resource unavailable' using errcode='42501';end if;
 if s.voting_type<>'DOT_VOTE' then raise exception 'Unsupported voting configuration' using errcode='0A000';end if;
 if s.reveal_mode<>'HIDDEN_UNTIL_REVEAL' then raise exception 'Reveal not applicable' using errcode='55000';end if;
 if s.status<>'CLOSED' or s.opened_at is null or s.closed_at is null then raise exception 'Session cannot reveal' using errcode='55000';end if;
 select count(*),count(revealed_at),count(distinct revealed_at),min(revealed_at) into total,shown,distinct_stamps,stamp from public.votes where voting_session_id=s.id;
 select count(*),min(created_at) into events,event_stamp from public.change_log where entity_type='VOTING_SESSION' and entity_id=s.id and change_type='VOTING_SESSION_REVEALED';
 -- Reject manually altered or partially revealed history. The event records lifecycle,
 -- never authority; every retry revalidates the current actor and canonical scope.
 if events>1 or (shown>0 and (shown<>total or distinct_stamps<>1 or events<>1 or stamp is distinct from event_stamp)) or (events=1 and shown<>total)
 then raise exception 'Inconsistent reveal state' using errcode='55000';end if;
 perform private.require_voting_creation(a.id);
 if public.current_platform_user_id() is distinct from actor or not public.can_read_activity_instance(a.id)
 or not exists(select 1 from public.project_memberships m where m.project_id=a.project_id and m.user_id=actor and m.status='active' and m.starts_at<=clock_timestamp() and (m.ends_at is null or m.ends_at>clock_timestamp()))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 if events=1 then return to_jsonb(s);end if;
 stamp:=clock_timestamp();
 update public.votes set revealed_at=stamp where voting_session_id=s.id and revealed_at is null;
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by,created_at)
 values(a.project_id,'VOTING_SESSION',s.id,'VOTING_SESSION_REVEALED','Voting Session revealed',actor,stamp);
 return to_jsonb(s);
end $$;
revoke all on function public.reveal_voting_session(uuid) from public,anon,authenticated,service_role;
grant execute on function public.reveal_voting_session(uuid) to authenticated;
commit;
