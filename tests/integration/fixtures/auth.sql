-- Test-only subset of Supabase Auth contracts, never a production migration.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create role supabase_auth_admin nologin;
create schema auth;
grant usage on schema public, auth to anon, authenticated, service_role, supabase_auth_admin;
create table auth.users (
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);
grant select, insert, update, delete on auth.users to supabase_auth_admin;
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid;
$$;
-- Exercise migration backfill for an existing Auth identity.
insert into auth.users(id, email) values ('00000000-0000-4000-8000-000000000001', 'a@example.test');
