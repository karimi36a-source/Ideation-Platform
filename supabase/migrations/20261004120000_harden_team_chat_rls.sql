begin;
-- Reuse verified-context helpers; no new identity or scope oracle is introduced.
-- Metadata read is distinct from private Workspace/Chat content access.
create policy teams_active_member_metadata_read on public.teams for select to authenticated
 using(public.get_team_workspace_access(workspace_id) is not null);
create policy teams_read_scope_guard on public.teams as restrictive for select to authenticated
 using(public.can_manage_team(id) or public.get_team_workspace_access(workspace_id) is not null);
create policy workspaces_team_read_scope_guard on public.workspaces as restrictive for select to authenticated
 using(workspace_type<>'TEAM' or public.get_team_workspace_access(id) is not null);
create policy chat_channels_read_scope_guard on public.chat_channels as restrictive for select to authenticated
 using(public.can_access_team_chat(id));
create policy chat_memberships_read_scope_guard on public.chat_memberships as restrictive for select to authenticated
 using(user_id=public.current_platform_user_id() and left_at is null and public.can_access_team_chat(chat_channel_id));
create policy chat_messages_read_scope_guard on public.chat_messages as restrictive for select to authenticated
 using(public.can_access_team_chat(chat_channel_id));
-- No roster/history read policy was approved. Keep memberships server-only.
create policy team_memberships_client_read_deny on public.team_memberships as restrictive for select to authenticated using(false);
alter table public.teams enable row level security;
revoke all on public.teams from public,anon,authenticated,service_role;
create policy teams_client_insert_deny on public.teams as restrictive for insert to authenticated with check(false);
create policy teams_client_update_deny on public.teams as restrictive for update to authenticated using(false) with check(false);
create policy teams_client_delete_deny on public.teams as restrictive for delete to authenticated using(false);
alter table public.team_memberships enable row level security;
revoke all on public.team_memberships from public,anon,authenticated,service_role;
create policy team_memberships_client_insert_deny on public.team_memberships as restrictive for insert to authenticated with check(false);
create policy team_memberships_client_update_deny on public.team_memberships as restrictive for update to authenticated using(false) with check(false);
create policy team_memberships_client_delete_deny on public.team_memberships as restrictive for delete to authenticated using(false);
alter table public.chat_channels enable row level security;
revoke all on public.chat_channels from public,anon,authenticated,service_role;
create policy chat_channels_client_insert_deny on public.chat_channels as restrictive for insert to authenticated with check(false);
create policy chat_channels_client_update_deny on public.chat_channels as restrictive for update to authenticated using(false) with check(false);
create policy chat_channels_client_delete_deny on public.chat_channels as restrictive for delete to authenticated using(false);
alter table public.chat_memberships enable row level security;
revoke all on public.chat_memberships from public,anon,authenticated,service_role;
create policy chat_memberships_client_insert_deny on public.chat_memberships as restrictive for insert to authenticated with check(false);
create policy chat_memberships_client_update_deny on public.chat_memberships as restrictive for update to authenticated using(false) with check(false);
create policy chat_memberships_client_delete_deny on public.chat_memberships as restrictive for delete to authenticated using(false);
alter table public.chat_messages enable row level security;
revoke all on public.chat_messages from public,anon,authenticated,service_role;
create policy chat_messages_client_insert_deny on public.chat_messages as restrictive for insert to authenticated with check(false);
create policy chat_messages_client_update_deny on public.chat_messages as restrictive for update to authenticated using(false) with check(false);
create policy chat_messages_client_delete_deny on public.chat_messages as restrictive for delete to authenticated using(false);
alter table public.workspaces enable row level security;
-- M4 restrictive Workspace writes remain unchanged. Only existing identity-bound
-- narrow definer RPCs can mutate Team/Chat tables; sender and timestamps derive
-- inside send_team_chat_message, not from direct client INSERT payloads.
grant select on public.teams,public.chat_channels,public.chat_memberships,public.chat_messages to authenticated;
-- Anonymous guards remain protective even if an accidental policy/grant is added.
create policy teams_anonymous_deny on public.teams as restrictive for all to anon using(false) with check(false);
create policy team_memberships_anonymous_deny on public.team_memberships as restrictive for all to anon using(false) with check(false);
create policy chat_channels_anonymous_deny on public.chat_channels as restrictive for all to anon using(false) with check(false);
create policy chat_memberships_anonymous_deny on public.chat_memberships as restrictive for all to anon using(false) with check(false);
create policy chat_messages_anonymous_deny on public.chat_messages as restrictive for all to anon using(false) with check(false);
create policy workspaces_team_anonymous_deny on public.workspaces as restrictive for all to anon
 using(workspace_type<>'TEAM') with check(workspace_type<>'TEAM');
-- Audit tables do not exist yet; do not create M5.12 structures.
commit;
