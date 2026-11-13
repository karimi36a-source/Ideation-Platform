begin;
-- Narrow session-bound write to otherwise inaccessible vote storage. Owner
-- execution avoids RLS recursion; no actor or scope is accepted from callers.
create function public.cast_vote(target_session uuid,target_option uuid,dot_value integer)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();s public.voting_sessions;
 a public.activity_instances;o public.voting_options;obj public.development_objects;v public.votes;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if current_setting('transaction_isolation')<>'read committed' then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into s from public.voting_sessions where id=target_session;
 if not found or not public.can_read_activity_instance(s.activity_instance_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into a from public.activity_instances where id=s.activity_instance_id;
 -- Existing validator locks current profile, Team, enrollment, Project
 -- participation and Workspace and requires canonical member/lead write access.
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 perform 1 from public.project_program_links where project_id=a.project_id for share;
 select * into a from public.activity_instances where id=a.id for share;
 if a.team_id is null or not exists(select 1 from public.team_memberships m
 where m.team_id=a.team_id and m.user_id=actor and m.status='active'
 and m.membership_role in ('member','team_lead') and m.left_at is null and m.joined_at<=clock_timestamp())
 or not exists(select 1 from public.enrollments e where e.user_id=actor and e.cohort_id=a.cohort_id and e.status='active' and e.enrollment_role='participant')
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 if a.status<>'active' then raise exception 'Activity not writable' using errcode='55000';end if;
 if a.configuration_snapshot->>'method_type' is distinct from 'voting'
 or a.configuration_snapshot #> '{configuration,voting,enabled}' is distinct from 'true'::jsonb
 or a.configuration_snapshot #>> '{configuration,voting,voting_type}' is distinct from 'DOT_VOTE'
 then raise exception 'Required Activity configuration unavailable' using errcode='0A000';end if;
 -- Session lock serializes ALL casts (including distinct options/users) and
 -- future close transitions. Fresh READ COMMITTED count follows lock acquisition.
 select * into s from public.voting_sessions where id=target_session for update;
 if not found or s.activity_instance_id<>a.id then raise exception 'Resource unavailable' using errcode='42501';end if;
 if s.status<>'OPEN' or s.opened_at is null or s.closed_at is not null then raise exception 'Session not open' using errcode='55000';end if;
 if s.voting_type<>'DOT_VOTE' or dot_value is distinct from 1 then raise exception 'Invalid dot vote' using errcode='22023';end if;
 select * into o from public.voting_options where id=target_option and voting_session_id=s.id for share;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 if o.development_object_id is not null then
  select * into obj from public.development_objects where id=o.development_object_id and project_id=a.project_id and workspace_id=a.workspace_id for share;
  if not found or obj.archived_at is not null or obj.object_type not in ('PROBLEM','SOLUTION','FEATURE') then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 if exists(select 1 from public.votes where voting_session_id=s.id and voting_option_id=o.id and user_id=actor) then raise exception 'Vote conflict' using errcode='23505';end if;
 if s.vote_limit is null or s.vote_limit<0 then raise exception 'Invalid vote limit' using errcode='22023';end if;
 if (select count(*) from public.votes where voting_session_id=s.id and user_id=actor)>=s.vote_limit then raise exception 'Vote limit reached' using errcode='23505';end if;
 -- Recheck current temporal access after waiting; historical participant rows
 -- and instructional/global roles never substitute for current membership.
 if public.current_platform_user_id() is distinct from actor or not public.can_read_activity_instance(a.id)
 or not exists(select 1 from public.project_memberships m where m.project_id=a.project_id and m.user_id=actor and m.status='active' and m.starts_at<=clock_timestamp() and (m.ends_at is null or m.ends_at>clock_timestamp()))
 or coalesce(public.get_team_workspace_access(a.workspace_id)::text,'') not in ('member','team_lead')
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 insert into public.votes(voting_session_id,voting_option_id,user_id,value,created_at)
 values(s.id,o.id,actor,1,clock_timestamp()) returning * into v;
 return to_jsonb(v);
end $$;
revoke all on function public.cast_vote(uuid,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.cast_vote(uuid,uuid,integer) to authenticated;
commit;
