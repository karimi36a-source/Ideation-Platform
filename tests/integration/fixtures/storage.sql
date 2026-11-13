-- Test-only subset of the provider-owned Storage metadata contract.
-- This is NOT a Storage HTTP service and cannot prove public-URL behavior.
create schema storage;
grant usage on schema storage to anon,authenticated,service_role;
create table storage.buckets(id text primary key,name text not null,public boolean not null default false);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text not null,metadata jsonb,unique(bucket_id,name));
alter table storage.buckets enable row level security;
alter table storage.objects enable row level security;
grant select,insert,update,delete on storage.objects,storage.buckets to anon,authenticated,service_role;
-- Deliberately broad pre-existing fixture policies prove that the bucket-scoped
-- restrictive migration still denies access, without changing unrelated buckets.
create policy storage_fixture_baseline on storage.objects for all to anon,authenticated using(true) with check(true);
create policy storage_bucket_fixture_baseline on storage.buckets for all to anon,authenticated using(true) with check(true);
insert into storage.buckets(id,name) values('fici-private-files','fici-private-files'),('unrelated-fixture','unrelated-fixture');
