-- M2.1: configuration catalog only; roles do not confer authorization.
begin;

create table public.roles (
  id uuid primary key,
  code text not null unique check (code in ('ADMIN', 'MASTER', 'MENTOR', 'STUDENT')),
  name text not null check (length(btrim(name)) > 0),
  description text not null,
  is_system_role boolean not null default true check (is_system_role),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.roles enable row level security;
-- No catalog-read or role-management product policy is introduced in M2.1.
revoke all on public.roles from public, anon, authenticated, service_role;

create function public.protect_system_role_identity()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.id is distinct from old.id or new.code is distinct from old.code
     or new.is_system_role is distinct from old.is_system_role
     or new.created_at is distinct from old.created_at then
    raise exception 'System role identity is immutable' using errcode = '23514';
  end if;
  new.updated_at := clock_timestamp();
  return new;
end;
$$;
revoke all on function public.protect_system_role_identity() from public, anon, authenticated, service_role;
create trigger roles_protect_identity before update on public.roles
  for each row execute function public.protect_system_role_identity();

-- One canonical, parameter-free seed. SECURITY INVOKER and no execute grants:
-- only the migration/database owner may run it, not a browser or application key.
create function public.seed_system_roles()
returns void language sql set search_path = '' as $$
  insert into public.roles (id, code, name, description, is_system_role) values
    ('00000000-0000-4000-8000-000000000101', 'ADMIN', 'Admin', 'Platform or organization operational administration.', true),
    ('00000000-0000-4000-8000-000000000102', 'MASTER', 'Master / Instructor', 'Instruction and oversight within assigned scope.', true),
    ('00000000-0000-4000-8000-000000000103', 'MENTOR', 'Mentor / Coach', 'Mentoring within assigned scope.', true),
    ('00000000-0000-4000-8000-000000000104', 'STUDENT', 'Student / User', 'Learning and development participation within assigned scope.', true)
  on conflict (code) do nothing;
$$;
revoke all on function public.seed_system_roles() from public, anon, authenticated, service_role;

select public.seed_system_roles();
commit;
