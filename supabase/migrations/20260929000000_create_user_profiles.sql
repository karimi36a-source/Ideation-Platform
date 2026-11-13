-- M1.2: platform profiles, with identity owned by Supabase Auth.
begin;

create type public.account_status as enum ('invited', 'active', 'suspended', 'archived');

create table public.users (
  id uuid primary key references auth.users(id) on delete restrict,
  email text,
  display_name text,
  first_name text,
  last_name text,
  profile_image text,
  account_status public.account_status not null,
  timezone text,
  locale text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.users enable row level security;
revoke all on public.users from public, anon, authenticated;
grant select on public.users to authenticated;
grant update (display_name, profile_image, timezone, locale) on public.users to authenticated;

create policy users_select_own on public.users for select to authenticated
  using ((select auth.uid()) = id);
create policy users_update_own on public.users for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create function public.set_user_profile_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;
revoke all on function public.set_user_profile_updated_at() from public, anon, authenticated;
create trigger users_updated_at before update on public.users
  for each row execute function public.set_user_profile_updated_at();

-- Status must be chosen explicitly by a trusted provisioner. There is no implicit
-- invitation/activation policy, no user-metadata authority, and no caller email.
create function public.provision_user_profile(auth_user_id uuid, initial_status public.account_status)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if initial_status is null then
    raise exception 'An explicit initial account status is required' using errcode = '22023';
  end if;
  perform 1 from auth.users where id = auth_user_id for update;
  if not found then
    raise exception 'Auth identity unavailable' using errcode = '23503';
  end if;
  insert into public.users (id, email, account_status)
    select id, email, initial_status from auth.users where id = auth_user_id
    on conflict (id) do nothing;
end;
$$;
revoke all on function public.provision_user_profile(uuid, public.account_status) from public, anon, authenticated;
grant execute on function public.provision_user_profile(uuid, public.account_status) to service_role;

-- Mirror only the provider-controlled email; never use raw_user_meta_data for
-- trusted identity or status. No platform email-change endpoint is introduced.
create function public.sync_user_profile_email()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.users set email = new.email where id = new.id;
  return new;
end;
$$;
revoke all on function public.sync_user_profile_email() from public, anon, authenticated;
create trigger fici_sync_profile_email after update of email on auth.users
  for each row when (old.email is distinct from new.email)
  execute function public.sync_user_profile_email();

commit;

