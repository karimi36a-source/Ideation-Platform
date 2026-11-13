begin;
-- No owner metadata editing/lifecycle policy has been approved. These restrictive
-- guards also survive an accidentally added permissive client-write policy.
revoke insert,update,delete,truncate,references,trigger on public.workspaces from anon,authenticated;
create policy workspaces_client_insert_denied on public.workspaces as restrictive for insert to authenticated with check(false);
create policy workspaces_client_update_denied on public.workspaces as restrictive for update to authenticated using(false) with check(false);
create policy workspaces_client_delete_denied on public.workspaces as restrictive for delete to authenticated using(false);
-- Existing owner-only SELECT and narrow identity-bound definer provisioning remain.
commit;
