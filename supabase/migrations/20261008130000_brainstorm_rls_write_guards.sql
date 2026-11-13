begin;
-- Preserve accepted creator/revealed-pool SELECT and all RPC grants.
-- Mutation remains RPC-only even if a permissive policy/grant is added.
alter table public.brainstorm_entries enable row level security;
create policy brainstorm_client_insert_guard on public.brainstorm_entries
 as restrictive for insert to authenticated,anon with check(false);
create policy brainstorm_client_update_guard on public.brainstorm_entries
 as restrictive for update to authenticated,anon using(false) with check(false);
create policy brainstorm_client_delete_guard on public.brainstorm_entries
 as restrictive for delete to authenticated,anon using(false);
comment on policy brainstorm_client_insert_guard on public.brainstorm_entries is
 'M9.16 identity-bound creation RPC only; no second client insertion path.';
comment on policy brainstorm_client_update_guard on public.brainstorm_entries is
 'M9.16 no direct reveal, scope, creator, parent, Object, lifecycle or content mutation.';
comment on policy brainstorm_client_delete_guard on public.brainstorm_entries is
 'M9.16 preserve methodology history; no ordinary hard-delete path.';
commit;
