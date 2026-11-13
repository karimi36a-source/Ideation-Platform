-- M1.5: lifecycle enforcement for self-service profile writes.
-- Own-profile reads remain available to resolve blocked account state safely.
begin;
drop policy users_update_own on public.users;
create policy users_update_own on public.users for update to authenticated
  using ((select auth.uid()) = id and account_status = 'active')
  with check ((select auth.uid()) = id and account_status = 'active');
-- Identity/status column grants and trusted provisioning remain unchanged.
commit;
