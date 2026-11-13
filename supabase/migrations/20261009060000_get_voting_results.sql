begin;
-- Owner execution is needed only to aggregate default-denied Vote rows. All authority
-- comes from the authenticated context and existing canonical scope helpers.
-- STABLE keeps every SELECT in the calling statement's one MVCC snapshot.
create function public.get_voting_results(target_session uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();s public.voting_sessions;a public.activity_instances;
 total bigint;shown bigint;stamps bigint;stamp timestamptz;events bigint;event_stamp timestamptz;
 revealed boolean:=false;visible boolean;choices jsonb;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into s from public.voting_sessions where id=target_session;
 if not found or not public.can_read_activity_instance(s.activity_instance_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into a from public.activity_instances where id=s.activity_instance_id;
 if a.team_id is null or a.status not in ('active','completed','archived')
 or not public.can_read_development_project(a.project_id)
 or not (public.get_team_workspace_access(a.workspace_id) in ('member','team_lead') or exists(
 select 1 from public.role_assignments ra join public.roles rr on rr.id=ra.role_id
 where ra.user_id=actor and rr.code='MASTER' and ra.status='active'
 and ra.starts_at<=statement_timestamp() and (ra.ends_at is null or ra.ends_at>statement_timestamp())
 and ra.organization_id is null and ra.program_id is null and ra.project_id is null
 and ((ra.cohort_id=a.cohort_id and ra.team_id is null) or (ra.team_id=a.team_id and ra.cohort_id is null))))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 if s.voting_type<>'DOT_VOTE' then raise exception 'Unsupported voting configuration' using errcode='0A000';end if;
 select count(*),count(revealed_at),count(distinct revealed_at),min(revealed_at)
 into total,shown,stamps,stamp from public.votes where voting_session_id=s.id;
 select count(*),min(created_at) into events,event_stamp from public.change_log
 where entity_type='VOTING_SESSION' and entity_id=s.id and change_type='VOTING_SESSION_REVEALED';
 if s.reveal_mode='HIDDEN_UNTIL_REVEAL' then
  if events>1 or (shown>0 and (shown<>total or stamps<>1 or events<>1 or stamp is distinct from event_stamp))
  or (events=1 and (shown<>total or s.status<>'CLOSED'))
  then raise exception 'Inconsistent reveal state' using errcode='55000';end if;
  revealed:=events=1 and s.status='CLOSED';
 end if;
 visible:=(s.reveal_mode='LIVE' and s.status in ('OPEN','CLOSED')) or revealed;
 -- Match canonical Object read rules: same Project/primary Workspace plus current
 -- Project AND Workspace access. Never treat an Option FK as authorization.
 if exists(select 1 from public.voting_options o left join public.development_objects d on d.id=o.development_object_id
 where o.voting_session_id=s.id and o.development_object_id is not null and
 (d.id is null or d.project_id<>a.project_id or d.workspace_id<>a.workspace_id
 or not public.can_read_development_project(d.project_id) or public.get_team_workspace_access(d.workspace_id) is null))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'sequence',o.sequence,'label',o.label,'description',o.description,
 'developmentObject',case when d.id is null then null else jsonb_build_object('id',d.id,'objectType',d.object_type,'title',d.title,'status',d.status) end,
 'voteCount',case when visible then (select count(*) from public.votes v where v.voting_session_id=s.id and v.voting_option_id=o.id) else null end)
 order by o.sequence),'[]'::jsonb) into choices
 from public.voting_options o left join public.development_objects d on d.id=o.development_object_id where o.voting_session_id=s.id;
 return jsonb_build_object('session',jsonb_build_object('id',s.id,'status',s.status,'votingType',s.voting_type,
 'voteLimit',s.vote_limit,'anonymous',s.anonymous,'revealMode',s.reveal_mode,'openedAt',s.opened_at,'closedAt',s.closed_at,'revealed',revealed),
 'options',choices,'totalVotes',case when visible then total else null end);
end $$;
revoke all on function public.get_voting_results(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_voting_results(uuid) to authenticated;
commit;
