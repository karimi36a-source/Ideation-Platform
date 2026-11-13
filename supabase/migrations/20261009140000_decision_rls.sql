begin;
-- Owner execution avoids recursive Decision/child policies. Identity is resolved
-- by canonical current Project/Workspace helpers, never by owner/participant rows.
create function public.can_read_decision(target_decision uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.decisions d join public.development_projects p on p.id=d.project_id and p.primary_workspace_id=d.workspace_id
 join public.workspaces w on w.id=d.workspace_id
 where d.id=target_decision and public.can_read_development_project(p.id)
 and ((w.workspace_type='PERSONAL' and w.owner_user_id=public.current_platform_user_id())
 or (w.workspace_type='TEAM' and w.team_id=p.owner_team_id and public.get_team_workspace_access(w.id) is not null)));
$$;
revoke all on function public.can_read_decision(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_decision(uuid) to authenticated;
alter table public.decisions enable row level security;
revoke all on public.decisions from public,anon,authenticated,service_role;
grant select on public.decisions to authenticated;
drop policy decisions_client_deny on public.decisions;
create policy decisions_read on public.decisions for select to authenticated using(public.can_read_decision(id));
create policy decisions_read_guard on public.decisions as restrictive for select to authenticated using(public.can_read_decision(id));
create policy decisions_insert_deny on public.decisions as restrictive for insert to authenticated with check(false);
create policy decisions_update_deny on public.decisions as restrictive for update to authenticated using(false) with check(false);
create policy decisions_delete_deny on public.decisions as restrictive for delete to authenticated using(false);
alter table public.decision_options enable row level security;
revoke all on public.decision_options from public,anon,authenticated,service_role;
grant select on public.decision_options to authenticated;
drop policy decision_options_client_deny on public.decision_options;
create policy decision_options_read on public.decision_options for select to authenticated using(public.can_read_decision(decision_id));
create policy decision_options_read_guard on public.decision_options as restrictive for select to authenticated using(public.can_read_decision(decision_id));
create policy decision_options_insert_deny on public.decision_options as restrictive for insert to authenticated with check(false);
create policy decision_options_update_deny on public.decision_options as restrictive for update to authenticated using(false) with check(false);
create policy decision_options_delete_deny on public.decision_options as restrictive for delete to authenticated using(false);
alter table public.decision_participants enable row level security;
revoke all on public.decision_participants from public,anon,authenticated,service_role;
grant select on public.decision_participants to authenticated;
drop policy decision_participants_client_deny on public.decision_participants;
create policy decision_participants_read on public.decision_participants for select to authenticated using(public.can_read_decision(decision_id));
create policy decision_participants_read_guard on public.decision_participants as restrictive for select to authenticated using(public.can_read_decision(decision_id));
create policy decision_participants_insert_deny on public.decision_participants as restrictive for insert to authenticated with check(false);
create policy decision_participants_update_deny on public.decision_participants as restrictive for update to authenticated using(false) with check(false);
create policy decision_participants_delete_deny on public.decision_participants as restrictive for delete to authenticated using(false);
alter table public.decision_links enable row level security;
revoke all on public.decision_links from public,anon,authenticated,service_role;
grant select on public.decision_links to authenticated;
drop policy decision_links_client_deny on public.decision_links;
create policy decision_links_read on public.decision_links for select to authenticated using(public.can_read_decision(decision_id));
create policy decision_links_read_guard on public.decision_links as restrictive for select to authenticated using(public.can_read_decision(decision_id));
create policy decision_links_insert_deny on public.decision_links as restrictive for insert to authenticated with check(false);
create policy decision_links_update_deny on public.decision_links as restrictive for update to authenticated using(false) with check(false);
create policy decision_links_delete_deny on public.decision_links as restrictive for delete to authenticated using(false);
alter table public.artifact_decision_sources enable row level security;
revoke all on public.artifact_decision_sources from public,anon,authenticated,service_role;
grant select on public.artifact_decision_sources to authenticated;
-- Retain M10.13 Version checks and immutable history; require BOTH sides too.
create policy artifact_decision_sources_both_sides on public.artifact_decision_sources as restrictive for select to authenticated using(
 public.can_read_decision(decision_id) and exists(select 1 from public.artifacts a where a.id=artifact_id));
create policy artifact_decision_sources_insert_deny on public.artifact_decision_sources as restrictive for insert to authenticated with check(false);
create policy artifact_decision_sources_update_deny on public.artifact_decision_sources as restrictive for update to authenticated using(false) with check(false);
create policy artifact_decision_sources_delete_deny on public.artifact_decision_sources as restrictive for delete to authenticated using(false);
comment on function public.can_read_decision(uuid) is 'M10.15 current canonical parent scope only. Owner and participant provenance are not independent access grants.';
commit;
