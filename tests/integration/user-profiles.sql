\set ON_ERROR_STOP on
begin;
-- Trigger execution must work under the real Auth service's unprivileged role.
set local role supabase_auth_admin;
insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-4000-8000-000000000002', 'b@example.test', '{"account_status":"active","email":"spoof@example.test"}'),
 ('00000000-0000-4000-8000-000000000003', 'missing@example.test', '{"account_status":"active"}');
reset role;
set local role service_role;
select public.provision_user_profile('00000000-0000-4000-8000-000000000001', 'invited');
select public.provision_user_profile('00000000-0000-4000-8000-000000000002', 'suspended');
-- Retrying provisioning cannot reactivate or overwrite a profile.
select public.provision_user_profile('00000000-0000-4000-8000-000000000002', 'active');
reset role;
do $$ begin
  assert (select count(*) from public.users) = 2, 'one profile per Auth identity';
  assert not exists(select 1 from public.users where id = '00000000-0000-4000-8000-000000000003'), 'Auth creation cannot auto-provision or activate';
  assert (select account_status from public.users where email = 'b@example.test') = 'suspended', 'status must not reset';
  assert not exists(select 1 from public.users where email = 'spoof@example.test'), 'metadata cannot set email';
  assert (select relrowsecurity from pg_class where oid = 'public.users'::regclass), 'RLS must be enabled';
  begin
    perform public.provision_user_profile('00000000-0000-4000-8000-000000000099', 'active');
    raise exception 'unknown identity accepted';
  exception when foreign_key_violation then null; end;
  begin
    perform public.provision_user_profile('00000000-0000-4000-8000-000000000001', null);
    raise exception 'implicit status accepted';
  exception when invalid_parameter_value then null; end;
end $$;

-- Both fixtures are active for direct cross-user denial assertions, independently
-- of status restrictions. Only a trusted operator can activate these accounts.
update public.users set account_status = 'active' where id in (
  '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
do $$
declare rows_changed integer; protected_column text; old_updated timestamptz;
begin
  assert (select count(*) from public.users) = 1, 'only own profile visible';
  assert not exists(select 1 from public.users where id = '00000000-0000-4000-8000-000000000002'), 'direct-ID read denied';
  select updated_at into old_updated from public.users;
  update public.users set display_name = 'Alice', profile_image = 'reference', timezone = 'UTC', locale = 'en';
  assert (select display_name from public.users) = 'Alice', 'allowed self fields update';
  assert (select updated_at from public.users) > old_updated, 'timestamp maintained by database';
  update public.users set display_name = 'attacker' where id = '00000000-0000-4000-8000-000000000002';
  get diagnostics rows_changed = row_count;
  assert rows_changed = 0, 'cross-user update denied';
  foreach protected_column in array array['id','email','account_status','first_name','last_name','created_at','updated_at'] loop
    begin
      execute format('update public.users set %I = %I', protected_column, protected_column);
      raise exception 'protected column % writable', protected_column;
    exception when insufficient_privilege then null; end;
  end loop;
  begin
    insert into public.users(id, account_status) values ('00000000-0000-4000-8000-000000000003', 'active');
    raise exception 'self insert accepted';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.users;
    raise exception 'self delete accepted';
  exception when insufficient_privilege then null; end;
  begin
    perform public.provision_user_profile('00000000-0000-4000-8000-000000000001', 'active');
    raise exception 'self provisioning accepted';
  exception when insufficient_privilege then null; end;
end $$;
-- Even an authenticated role without a subject sees no rows.
select set_config('request.jwt.claim.sub', '', true);
do $$ begin assert (select count(*) from public.users) = 0, 'missing subject denied'; end $$;
reset role;

-- A valid Auth subject never overrides the platform lifecycle state.
do $$
declare blocked_status public.account_status; changed integer;
begin
  foreach blocked_status in array array['invited','suspended','archived']::public.account_status[] loop
    update public.users set account_status = blocked_status where id = '00000000-0000-4000-8000-000000000001';
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
    assert (select count(*) from public.users) = 1, 'own account state remains readable';
    update public.users set display_name = 'blocked edit';
    get diagnostics changed = row_count;
    assert changed = 0, 'inactive own-profile write denied by RLS';
    execute 'reset role';
    perform public.provision_user_profile('00000000-0000-4000-8000-000000000001', 'active');
    assert (select account_status from public.users where id = '00000000-0000-4000-8000-000000000001') = blocked_status, 'provisioning cannot reactivate existing account';
  end loop;
  update public.users set account_status = 'active' where id = '00000000-0000-4000-8000-000000000001';
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000003', true);
do $$ begin
  assert (select count(*) from public.users) = 0, 'authenticated identity without a platform profile gets no rows';
  begin
    perform public.provision_user_profile('00000000-0000-4000-8000-000000000003', 'active');
    raise exception 'unprovisioned account self-activated';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

set local role anon;
do $$ begin
  begin perform * from public.users; raise exception 'anonymous read accepted';
  exception when insufficient_privilege then null; end;
  begin perform public.provision_user_profile('00000000-0000-4000-8000-000000000001', 'active'); raise exception 'anonymous provision accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

set local role supabase_auth_admin;
update auth.users set email = 'updated@example.test' where id = '00000000-0000-4000-8000-000000000001';
reset role;
do $$ begin
  assert (select email from public.users where id = '00000000-0000-4000-8000-000000000001') = 'updated@example.test', 'Auth email sync';
  assert (select display_name from public.users where id = '00000000-0000-4000-8000-000000000001') = 'Alice', 'email sync preserves profile';
  begin
    delete from auth.users where id = '00000000-0000-4000-8000-000000000001';
    raise exception 'Auth deletion destroyed profile history';
  exception when foreign_key_violation then null; end;
  assert (select count(*) from unnest(enum_range(null::public.account_status))) = 4, 'all four statuses available';
end $$;
rollback;
\echo Profile security assertions passed
