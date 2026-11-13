-- M2.5: explicitly consolidate base grants and add restrictive mutation guards.
begin;
alter table public.users enable row level security;
alter table public.roles enable row level security;
alter table public.role_assignments enable row level security;

-- Preserve M1 self-service fields and blocked-account own-read behavior.
revoke all on public.users from public, anon, authenticated, service_role;
grant select on public.users to authenticated;
grant update(display_name,profile_image,timezone,locale) on public.users to authenticated;
-- Restrictive guards compose with the existing permissive ownership policies.
create policy users_select_ownership_guard on public.users as restrictive
 for select to authenticated using ((select auth.uid())=id);
create policy users_update_ownership_guard on public.users as restrictive
 for update to authenticated
 using ((select auth.uid())=id and account_status='active')
 with check ((select auth.uid())=id and account_status='active');

revoke all on public.roles from public, anon, authenticated, service_role;
-- No browser catalog requirement exists. Explicit denial also survives accidental grants.
create policy roles_client_deny on public.roles as restrictive
 for all to anon, authenticated using (false) with check (false);

revoke all on public.role_assignments from public, anon, authenticated, service_role;
grant select on public.role_assignments to authenticated;
-- Existing own effective-assignment SELECT policy is preserved.
-- No product Admin role can invoke generic CRUD. Trusted migration owner only.
create policy role_assignments_client_insert_deny on public.role_assignments as restrictive
 for insert to anon, authenticated with check (false);
create policy role_assignments_client_update_deny on public.role_assignments as restrictive
 for update to anon, authenticated using (false) with check (false);
create policy role_assignments_client_delete_deny on public.role_assignments as restrictive
 for delete to anon, authenticated using (false);
-- Existing service_role provisioning RPC is retained; direct table privileges are absent.
-- Owner/definer paths bypass RLS intentionally. No new administrative RPC is created.
commit;
