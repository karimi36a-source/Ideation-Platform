begin;
-- Read-only policy predicate: canonical Activity/Project/Workspace authorization
-- remains authoritative. Owner execution avoids Session-policy recursion.
create function public.can_read_voting_session(target_session uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.voting_sessions s
 join public.activity_instances a on a.id=s.activity_instance_id
 join public.workspaces w on w.id=a.workspace_id
 where s.id=target_session and public.can_read_activity_instance(a.id)
 and ((w.workspace_type='PERSONAL' and w.owner_user_id=public.current_platform_user_id() and a.team_id is null)
 or (w.workspace_type='TEAM' and a.team_id=w.team_id and
 (public.get_team_workspace_access(w.id) in ('member','team_lead')
 or public.has_active_role_in_cohort('MASTER',a.cohort_id)
 or public.has_active_role_in_team('MASTER',a.team_id)))));
$$;
revoke all on function public.can_read_voting_session(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_voting_session(uuid) to authenticated;

alter table public.voting_sessions enable row level security;
alter table public.voting_options enable row level security;
alter table public.votes enable row level security;
revoke all on public.voting_sessions,public.voting_options,public.votes from public,anon,authenticated,service_role;
grant select on public.voting_sessions,public.voting_options to authenticated;
create policy voting_sessions_read on public.voting_sessions for select to authenticated using(public.can_read_voting_session(id));
create policy voting_sessions_read_guard on public.voting_sessions as restrictive for select to authenticated using(public.can_read_voting_session(id));
create policy voting_options_read on public.voting_options for select to authenticated using(public.can_read_voting_session(voting_session_id));
create policy voting_options_read_guard on public.voting_options as restrictive for select to authenticated using(public.can_read_voting_session(voting_session_id));
-- Restrictive guards retain denial even if a future migration accidentally
-- adds table grants or permissive write policies. Controlled RPCs use owner rights.
create policy voting_sessions_insert_deny on public.voting_sessions as restrictive for insert to authenticated with check(false);
create policy voting_sessions_update_deny on public.voting_sessions as restrictive for update to authenticated using(false) with check(false);
create policy voting_sessions_delete_deny on public.voting_sessions as restrictive for delete to authenticated using(false);
create policy voting_options_insert_deny on public.voting_options as restrictive for insert to authenticated with check(false);
create policy voting_options_update_deny on public.voting_options as restrictive for update to authenticated using(false) with check(false);
create policy voting_options_delete_deny on public.voting_options as restrictive for delete to authenticated using(false);
create policy votes_client_deny on public.votes as restrictive for all to authenticated using(false) with check(false);
comment on function public.can_read_voting_session(uuid) is 'M10.14 authenticated canonical context predicate; no caller user ID. Raw votes remain inaccessible before and after reveal.';
commit;
