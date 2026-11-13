begin;
-- Supabase owns these tables. Bucket creation/configuration uses the Storage
-- API via the local-only setup script; this migration changes RLS policies only.
-- No upload, registration, read/download or signed-access permission is added.
do $$begin
 if not (select relrowsecurity from pg_class where oid='storage.objects'::regclass)
 or not (select relrowsecurity from pg_class where oid='storage.buckets'::regclass)
 then raise exception 'Private Storage requires provider RLS' using errcode='55000';end if;
end$$;
create policy fici_private_file_objects_deny on storage.objects as restrictive for all to anon,authenticated
 using(bucket_id<>'fici-private-files') with check(bucket_id<>'fici-private-files');
create policy fici_private_file_bucket_deny on storage.buckets as restrictive for all to anon,authenticated
 using(id<>'fici-private-files') with check(id<>'fici-private-files');
commit;
