begin;
create type public.organization_status as enum ('active','inactive','archived');
create table public.organizations (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(btrim(name)) between 1 and 200),
 slug text not null unique check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
 status public.organization_status not null default 'active',
 settings jsonb not null default '{}'::jsonb check(jsonb_typeof(settings)='object'),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.organizations enable row level security;
revoke all on public.organizations from public,anon,authenticated,service_role;
grant select on public.organizations to authenticated;
create policy organizations_admin_read on public.organizations for select to authenticated
 using(public.has_active_role_in_organization('ADMIN',id));
-- Defense in depth; no direct client UPDATE grant. Only the explicit command below.
create policy organizations_admin_update on public.organizations for update to authenticated
 using(public.has_active_role_in_organization('ADMIN',id))
 with check(public.has_active_role_in_organization('ADMIN',id));
create function public.protect_organization_identity() returns trigger language plpgsql set search_path='' as $$
begin
 if new.id is distinct from old.id or new.slug is distinct from old.slug or new.created_at is distinct from old.created_at then
  raise exception 'Organization identity is immutable' using errcode='23514';
 end if;
 new.updated_at := pg_catalog.clock_timestamp(); return new;
end $$;
revoke all on function public.protect_organization_identity() from public,anon,authenticated,service_role;
create trigger organizations_identity before update on public.organizations for each row execute function public.protect_organization_identity();
create function public.seed_initial_organization() returns void language sql security invoker set search_path='' as $$
 insert into public.organizations(id,name,slug,status) values
 ('00000000-0000-4000-8000-000000000501','FICI','fici','active') on conflict(slug) do nothing;
$$;
revoke all on function public.seed_initial_organization() from public,anon,authenticated,service_role;
select public.seed_initial_organization();
-- Validate existing organization bindings; unresolved legacy UUIDs fail migration.
alter table public.role_assignments add constraint role_assignments_organization_id_fkey
 foreign key(organization_id) references public.organizations(id) on delete restrict;
-- Definer is needed because clients have no generic mutation grant. Explicit
-- verified subject/active profile/valid exact single-scope ADMIN check remains mandatory.
create function public.update_organization(organization_id uuid,new_name text,new_status public.organization_status)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result public.organizations;
begin
 if not public.has_active_role_in_organization('ADMIN',organization_id) then
  raise exception 'Access denied' using errcode='42501';
 end if;
 if new_name is null or length(btrim(new_name)) not between 1 and 200 or new_status is null then
  raise exception 'Invalid organization update' using errcode='22023';
 end if;
 update public.organizations set name=btrim(new_name),status=new_status where id=organization_id returning * into result;
 if not found then raise exception 'Access denied' using errcode='42501'; end if;
 return pg_catalog.to_jsonb(result);
end $$;
revoke all on function public.update_organization(uuid,text,public.organization_status) from public,anon,authenticated,service_role;
grant execute on function public.update_organization(uuid,text,public.organization_status) to authenticated;
commit;

