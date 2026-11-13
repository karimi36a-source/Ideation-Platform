\set ON_ERROR_STOP on
begin;
create temporary table role_seed_snapshot as select * from public.roles;
select public.seed_system_roles();
select public.seed_system_roles();
do $$ begin
  assert (select count(*) from public.roles) = 4, 'exactly four system roles';
  assert (select count(distinct code) from public.roles) = 4, 'codes unique';
  assert (select array_agg(code order by code) from public.roles) = array['ADMIN','MASTER','MENTOR','STUDENT'], 'approved codes only';
  assert (select bool_and(is_system_role) from public.roles), 'all seed roles are system configuration';
  assert not exists((select * from public.roles except select * from role_seed_snapshot)
    union all (select * from role_seed_snapshot except select * from public.roles)), 'seed retries preserve IDs, labels and timestamps';
  assert (select relrowsecurity from pg_class where oid = 'public.roles'::regclass), 'roles RLS enabled';
  assert not exists(select 1 from pg_policies where schemaname = 'public' and tablename = 'roles' and permissive = 'PERMISSIVE'), 'no permissive client policy';
  assert (select id from public.roles where code = 'ADMIN') = '00000000-0000-4000-8000-000000000101', 'stable seeded identity';
  begin
    insert into public.roles(id,code,name,description) values ('00000000-0000-4000-8000-000000000199','ADMIN','Duplicate','Duplicate');
    raise exception 'duplicate code accepted';
  exception when unique_violation then null; end;
  begin
    update public.roles set code = 'MASTER' where code = 'ADMIN';
    raise exception 'system code changed';
  exception when check_violation then null; end;
  begin
    update public.roles set id = '00000000-0000-4000-8000-000000000199' where code = 'ADMIN';
    raise exception 'system identity changed';
  exception when check_violation then null; end;
end $$;

-- Browser-controlled role claims do not grant table/function privileges.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated","user_metadata":{"role":"ADMIN"}}', true);
set local role authenticated;
do $$ begin
  begin
    insert into public.roles(id,code,name,description) values ('00000000-0000-4000-8000-000000000199','CUSTOM','Escalated','Untrusted');
    raise exception 'client role creation accepted';
  exception when insufficient_privilege then null; end;
  begin update public.roles set name = 'Untrusted'; raise exception 'client role update accepted';
  exception when insufficient_privilege then null; end;
  begin delete from public.roles; raise exception 'client role deletion accepted';
  exception when insufficient_privilege then null; end;
  begin perform * from public.roles; raise exception 'unapproved catalog read accepted';
  exception when insufficient_privilege then null; end;
  begin perform public.seed_system_roles(); raise exception 'client seed RPC accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
-- RLS independently denies access even if a later accidental grant is added.
-- Test-only grants are rolled back and never affect a deployed environment.
grant select, insert, update, delete on public.roles to authenticated;
set local role authenticated;
do $$ declare changed integer; begin
  assert (select count(*) from public.roles) = 0, 'RLS denies catalog reads despite table grant';
  begin
    insert into public.roles(id,code,name,description) values ('00000000-0000-4000-8000-000000000199','ADMIN','Untrusted','Untrusted');
    raise exception 'RLS allowed role insert despite accidental grant';
  exception when insufficient_privilege then null; end;
  update public.roles set name = 'Untrusted';
  get diagnostics changed = row_count;
  assert changed = 0, 'RLS denies update despite table grant';
  delete from public.roles;
  get diagnostics changed = row_count;
  assert changed = 0, 'RLS denies deletion despite table grant';
end $$;
reset role;
revoke all on public.roles from authenticated;
set local role anon;
do $$ begin
  begin insert into public.roles(id,code,name,description) values ('00000000-0000-4000-8000-000000000199','CUSTOM','Untrusted','Untrusted'); raise exception 'anonymous insert accepted';
  exception when insufficient_privilege then null; end;
  begin perform public.seed_system_roles(); raise exception 'anonymous seed RPC accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role service_role;
do $$ begin
  begin perform public.seed_system_roles(); raise exception 'application key seeded configuration';
  exception when insufficient_privilege then null; end;
  begin insert into public.roles(id,code,name,description) values ('00000000-0000-4000-8000-000000000199','CUSTOM','Untrusted','Untrusted'); raise exception 'application key inserted configuration';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
\echo System role seed, immutability and client-denial assertions passed

