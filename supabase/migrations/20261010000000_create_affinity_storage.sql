begin;
create table public.affinity_groups (
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 name text not null check (length(btrim(name)) > 0),
 description text,
 sequence integer not null check (sequence > 0),
 created_by uuid not null references public.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 constraint affinity_group_sequence unique(activity_instance_id,sequence)
);
create table public.affinity_group_items (
 id uuid primary key default gen_random_uuid(),
 affinity_group_id uuid not null references public.affinity_groups(id) on delete restrict,
 development_object_id uuid references public.development_objects(id) on delete restrict,
 brainstorm_entry_id uuid references public.brainstorm_entries(id) on delete restrict,
 position integer not null check(position > 0),
 added_by uuid not null references public.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 constraint affinity_item_source check(num_nonnulls(development_object_id,brainstorm_entry_id)=1),
 constraint affinity_item_position unique(affinity_group_id,position)
);
create unique index affinity_item_object_unique on public.affinity_group_items(affinity_group_id,development_object_id) where development_object_id is not null;
create unique index affinity_item_brainstorm_unique on public.affinity_group_items(affinity_group_id,brainstorm_entry_id) where brainstorm_entry_id is not null;
create index affinity_group_creator on public.affinity_groups(created_by);
create index affinity_item_object_lookup on public.affinity_group_items(development_object_id) where development_object_id is not null;
create index affinity_item_brainstorm_lookup on public.affinity_group_items(brainstorm_entry_id) where brainstorm_entry_id is not null;
create index affinity_item_actor on public.affinity_group_items(added_by);
alter table public.affinity_groups enable row level security;
alter table public.affinity_group_items enable row level security;
revoke all on public.affinity_groups,public.affinity_group_items from public,anon,authenticated,service_role;
create policy affinity_groups_client_deny on public.affinity_groups as restrictive for all to authenticated using(false) with check(false);
create policy affinity_items_client_deny on public.affinity_group_items as restrictive for all to authenticated using(false) with check(false);
comment on table public.affinity_groups is 'M11.1 schema only. Scope derives from Activity; creator is provenance. No client operations.';
comment on table public.affinity_group_items is 'Canonical source links only. Exact-scope authorization belongs to later M11 operations/RLS; no copied content or client access.';
commit;
