begin;
-- Raw records include internal scope and immutable provenance. Authorized reads
-- remain on the caller-bound projection/history RPCs; no raw client table ACL.
alter table public.shares enable row level security;
alter table public.share_snapshots enable row level security;
revoke all on public.shares,public.share_snapshots from public,anon,authenticated,service_role;
-- Restrictive guards preserve this boundary even if a later migration grants
-- table privileges or adds a permissive policy. Canonical SECURITY DEFINER
-- functions retain their existing current-actor authorization and transaction.
create policy shares_client_raw_deny on public.shares as restrictive
 for all to authenticated using(false) with check(false);
create policy share_snapshots_client_raw_deny on public.share_snapshots as restrictive
 for all to authenticated using(false) with check(false);
comment on table public.shares is 'Private object-specific Share state. Canonical create/revoke/history and projected recipient RPCs only; no raw client read or mutation, no ownership transfer.';
comment on table public.share_snapshots is 'Immutable frozen payload and internal provenance. Current recipients use the safe resolver projection; source history uses its canonical RPC. No raw client access or mutation.';
commit;
