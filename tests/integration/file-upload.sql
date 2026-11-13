reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table upload_cases(label text primary key,payload jsonb);
grant select,insert on upload_cases to authenticated;
set local role authenticated;
insert into upload_cases select 'Personal',public.request_file_upload((payload->>'primary_workspace_id')::uuid,(payload->>'id')::uuid,'notes.txt','text/plain',1) from logged_projects where label='Individual';
insert into upload_cases select 'Team',public.request_file_upload((payload->>'primary_workspace_id')::uuid,(payload->>'id')::uuid,'notes.txt','text/plain',1) from logged_projects where label='Team';
insert into upload_cases select 'Boundary',public.request_file_upload((payload->>'primary_workspace_id')::uuid,null,'notes.txt','text/plain',26214400) from logged_projects where label='Team';
reset role;
create function pg_temp.upload_bad(statement text,expected text) returns void language plpgsql as $$begin execute statement;raise exception 'Upload attack accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
do $$declare w uuid;p uuid;begin
 select (payload->>'primary_workspace_id')::uuid,(payload->>'id')::uuid into w,p from logged_projects where label='Team';
 perform pg_temp.upload_bad(format('select public.request_file_upload(%L,%L,''x'',''text/plain'',0)',w,p),'23514');
 perform pg_temp.upload_bad(format('select public.request_file_upload(%L,%L,''x'',''text/plain'',26214401)',w,p),'23514');
 perform pg_temp.upload_bad(format('select public.request_file_upload(%L,%L,''x'',''image/svg+xml'',1)',w,p),'23514');
 perform pg_temp.upload_bad(format('select public.request_file_upload(%L,%L,''../x'',''text/plain'',1)',w,p),'23514');
 perform pg_temp.upload_bad(format('select public.request_file_upload(%L,%L,''x'',''text/plain'',1)',w,(select payload->>'id' from logged_projects where label='Individual')),'42501');
 perform pg_temp.upload_bad(format('select public.register_uploaded_file(%L)',(select payload->>'id' from upload_cases where label='Personal')),'22023');
end$$;
-- Read-only provider metadata fixture, never a production Storage write path.
insert into storage.objects(bucket_id,name,metadata) select 'fici-private-files',payload->>'storage_reference','{"size":1,"mimetype":"text/plain"}' from upload_cases where label in ('Personal','Team');
set local role authenticated;
select public.register_uploaded_file((payload->>'id')::uuid) from upload_cases where label='Personal';
select public.register_uploaded_file((payload->>'id')::uuid) from upload_cases where label='Team';
select public.register_uploaded_file((payload->>'id')::uuid) from upload_cases where label='Team';
reset role;
do $$begin
 assert (select count(*) from public.files where id in(select (payload->>'file_id')::uuid from upload_cases))=2;
 assert not exists(select 1 from public.files where id in(select (payload->>'file_id')::uuid from upload_cases) and (uploaded_by<>'00000000-0000-4000-8000-000000006004' or status<>'active' or size<>1));
end$$;
-- User A2 cannot claim A1's intent even when it was already registered.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
set local role authenticated;
select pg_temp.upload_bad(format('select public.register_uploaded_file(%L)',payload->>'id'),'42501') from upload_cases;
select pg_temp.upload_bad('select * from public.file_upload_requests','42501');
reset role;
-- Metadata mismatch is rejected without a File; then a valid pending request loses
-- authorization after canonical removal. Stale provider objects cannot grant access.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into upload_cases select 'Mismatch',public.request_file_upload((payload->>'primary_workspace_id')::uuid,(payload->>'id')::uuid,'x.txt','text/plain',3) from logged_projects where label='Team';
insert into storage.objects(bucket_id,name,metadata) select 'fici-private-files',payload->>'storage_reference','{"size":2,"mimetype":"text/plain"}' from upload_cases where label='Mismatch';
select pg_temp.upload_bad(format('select public.register_uploaded_file(%L)',payload->>'id'),'22023') from upload_cases where label='Mismatch';
update storage.objects set metadata='{"size":3,"mimetype":"text/html"}' where name=(select payload->>'storage_reference' from upload_cases where label='Mismatch');
select pg_temp.upload_bad(format('select public.register_uploaded_file(%L)',payload->>'id'),'22023') from upload_cases where label='Mismatch';
do $$begin assert not exists(select 1 from public.files where id=(select (payload->>'file_id')::uuid from upload_cases where label='Mismatch'));end$$;
-- Unknown/foreign IDs, arbitrary objects, expired requests, and rollback.
select pg_temp.upload_bad('select public.register_uploaded_file(gen_random_uuid())','42501');
insert into storage.objects(bucket_id,name,metadata) values('fici-private-files','arbitrary-no-intent','{"size":1,"mimetype":"text/plain"}');
insert into upload_cases select 'Expired',public.request_file_upload((payload->>'primary_workspace_id')::uuid,null,'x.txt','text/plain',1) from logged_projects where label='Team';
update public.file_upload_requests set created_at=clock_timestamp()-interval '3 hours',expires_at=clock_timestamp()-interval '1 hour' where id=(select (payload->>'id')::uuid from upload_cases where label='Expired');
select pg_temp.upload_bad(format('select public.register_uploaded_file(%L)',payload->>'id'),'22023') from upload_cases where label='Expired';
insert into upload_cases select 'Rollback',public.request_file_upload((payload->>'primary_workspace_id')::uuid,null,'x.txt','text/plain',1) from logged_projects where label='Team';
insert into storage.objects(bucket_id,name,metadata) select 'fici-private-files',payload->>'storage_reference','{"size":1,"mimetype":"text/plain"}' from upload_cases where label='Rollback';
create function pg_temp.reject_consumption() returns trigger language plpgsql as $$begin raise exception 'Forced consumption failure' using errcode='P0001';end$$;
create trigger test_consumption_failure before update on public.file_upload_requests for each row execute function pg_temp.reject_consumption();
select pg_temp.upload_bad(format('select public.register_uploaded_file(%L)',payload->>'id'),'P0001') from upload_cases where label='Rollback';
drop trigger test_consumption_failure on public.file_upload_requests;
do $$begin
 assert not exists(select 1 from public.files where id=(select (payload->>'file_id')::uuid from upload_cases where label='Rollback'));
 assert (select registered_at is null from public.file_upload_requests where id=(select (payload->>'id')::uuid from upload_cases where label='Rollback'));
 assert not has_table_privilege('authenticated','public.file_upload_requests','INSERT');
 assert not has_table_privilege('authenticated','public.file_upload_requests','SELECT');
 assert not has_function_privilege('anon','public.request_file_upload(uuid,uuid,text,text,bigint)','execute');
 assert not has_function_privilege('authenticated','private.require_file_upload_scope(uuid,uuid)','execute');
 assert (select bool_and(prosecdef and proconfig=array['search_path=""']) from pg_proc where pronamespace='public'::regnamespace and proname in ('request_file_upload','get_file_upload_request','register_uploaded_file'));
end$$;
-- Current authorization, not request-time history, is authoritative.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'owner_team_id')::uuid from logged_projects where label='Team'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.upload_bad(format('select public.register_uploaded_file(%L)',payload->>'id'),'42501') from upload_cases where label in ('Team','Rollback');
select pg_temp.upload_bad(format('select public.request_file_upload(%L,null,''x.txt'',''text/plain'',1)',payload->>'primary_workspace_id'),'42501') from logged_projects where label='Team';
reset role;
select 'M12.7 upload intents Personal/Team/boundaries/scope/metadata/idempotency/identity/direct-denial PASS';
rollback;
