alter type public.project_change_type add value 'VOTING_SESSION_CLOSED';
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
 return new;
end $$;


-- Same canonical scope locks and immutable authority as existing voting operations.
-- This private helper permits lifecycle-independent authorization, not mutation.
create function private.require_voting_close_context(target_instance uuid) returns public.activity_instances
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
revoke all on function private.require_voting_close_context(uuid) from public,anon,authenticated,service_role;

-- Narrow owner execution closes protected Sessions and appends one lifecycle event.
create function public.close_voting_session(target_session uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare s public.voting_sessions;a public.activity_instances;actor uuid;stamp timestamptz;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into s from public.voting_sessions where id=target_session;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_voting_close_context(s.activity_instance_id);
 select * into s from public.voting_sessions where id=target_session for update;
 if not found or s.activity_instance_id<>a.id or a.team_id is null then raise exception 'Resource unavailable' using errcode='42501';end if;
 if s.voting_type<>'DOT_VOTE' then raise exception 'Unsupported voting configuration' using errcode='0A000';end if;
 if s.status='DRAFT' or s.opened_at is null or (s.status='OPEN' and s.closed_at is not null) or (s.status='CLOSED' and (s.closed_at is null or s.closed_at<s.opened_at))
 then raise exception 'Session cannot close' using errcode='55000';end if;
 -- Revalidate time-sensitive current authority after waiting for the Session lock.
 a:=private.require_voting_close_context(a.id);
 if public.current_platform_user_id() is distinct from actor or not exists(select 1 from public.project_memberships m where m.project_id=a.project_id and m.user_id=actor and m.status='active' and m.starts_at<=clock_timestamp() and (m.ends_at is null or m.ends_at>clock_timestamp()))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 if s.status='CLOSED' then
  if a.status not in ('active','completed','archived') then raise exception 'Activity not available for retry' using errcode='55000';end if;
  return to_jsonb(s);
 end if;
 if a.status<>'active' then raise exception 'Activity not writable' using errcode='55000';end if;
 stamp:=clock_timestamp();
 update public.voting_sessions set status='CLOSED',closed_at=stamp where id=s.id returning * into s;
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by,created_at)
 values(a.project_id,'VOTING_SESSION',s.id,'VOTING_SESSION_CLOSED','Voting Session closed',actor,stamp);
 return to_jsonb(s);
end $$;
revoke all on function public.close_voting_session(uuid) from public,anon,authenticated,service_role;
grant execute on function public.close_voting_session(uuid) to authenticated;
commit;
