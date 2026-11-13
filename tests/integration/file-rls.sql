reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table archive_cases(label text primary key,id uuid,before_row jsonb);
create temporary table archive_targets(kind public.file_link_entity_type,id uuid);
grant select,insert,update on archive_cases,archive_targets to authenticated;
grant select on archive_cases to anon;
do $$declare p record;r jsonb;f jsonb;begin
 for p in select label,payload from logged_projects where label in ('Team','Individual') loop
  r:=public.request_file_upload((p.payload->>'primary_workspace_id')::uuid,(p.payload->>'id')::uuid,'archive.txt','text/plain',3);
  insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',r->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
  f:=public.register_uploaded_file((r->>'id')::uuid);insert into archive_cases values(p.label,(f->>'id')::uuid,f);
 end loop;
end$$;
insert into archive_targets values
 ('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team')),
 ('DEVELOPMENT_OBJECT',(select id from public.development_objects where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') limit 1)),
 ('ACTIVITY_INSTANCE',(select id from instances where label='Team')),
 ('CHAT_MESSAGE',(public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'Retained archive attachment',null)->>'id')::uuid);
-- Trusted composition fixture binds an existing File; no new Evidence API.
with e as(insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name,file_id)
 select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'MEASUREMENT','Preserved File source','Measured values','Notebook',(select id from archive_cases where label='Team') from logged_projects where label='Team' returning id)
 insert into archive_targets select 'EVIDENCE',id from e;
set local role authenticated;
select public.link_file(jsonb_build_object('fileId',(select id from archive_cases where label='Team'),'entityType',kind,'entityId',id,'relationshipType',case when kind='CHAT_MESSAGE' then 'CHAT_ATTACHMENT' else 'REFERENCE' end)) from archive_targets;
reset role;

create function pg_temp.file_security_bad(statement text,expected text) returns void language plpgsql as $$begin execute statement;raise exception 'File security attack accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
create temporary table security_history as select
 (select jsonb_agg(to_jsonb(f) order by id) from public.files f) files,
 (select jsonb_agg(to_jsonb(l) order by id) from public.file_links l) links,
 (select jsonb_agg(to_jsonb(o) order by id) from storage.objects o) objects;
set local role authenticated;
do $$declare n integer;begin
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  assert not exists(select 1 from public.files where id=(select id from archive_cases where label='Team')),'Known File ID denied';
  assert not exists(select 1 from public.files where storage_reference=(select before_row->>'storage_reference' from archive_cases where label='Team')),'Known path denied';
  assert not exists(select 1 from public.file_links where file_id=(select id from archive_cases where label='Team')),'Link enumeration denied';
  assert not exists(select 1 from public.evidence e join public.file_links l on l.entity_id=e.id join public.files f on f.id=l.file_id),'Join does not bypass File privacy';
  perform pg_temp.file_security_bad(format('select public.archive_file(%L)',(select id from archive_cases where label='Team')),'42501');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 assert not exists(select 1 from public.files where id=(select id from archive_cases where label='Individual')),'Personal peer denied';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 assert (select count(*) from public.files where id in(select id from archive_cases))=2,'Authorized positive controls';
 assert (select count(*) from public.file_links where file_id=(select id from archive_cases where label='Team'))=5;
end$$;
reset role;
-- Prove independent target authorization even when File remains readable.
savepoint target_boundary;
create policy m1221_test_target_denial on public.evidence as restrictive for select to authenticated using(false);
set local role authenticated;
do $$begin
 assert exists(select 1 from public.files where id=(select id from archive_cases where label='Team'));
 assert not exists(select 1 from public.file_links where entity_type='EVIDENCE');
 assert exists(select 1 from public.file_links where entity_type='ARTIFACT');
end$$;
rollback to target_boundary;
-- Workspace access alone cannot recover Project-bound File access.
savepoint project_boundary;
update public.project_memberships set status='inactive',ends_at=statement_timestamp() where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') and user_id='00000000-0000-4000-8000-000000006004' and status='active';
set local role authenticated;
do $$begin
 assert public.get_team_workspace_access((select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team')) is not null;
 assert not exists(select 1 from public.files where id=(select id from archive_cases where label='Team'));
 assert not exists(select 1 from public.file_links where file_id=(select id from archive_cases where label='Team'));
 assert exists(select 1 from public.files where id=(select id from archive_cases where label='Individual'));
end$$;
rollback to project_boundary;
-- Temporary privileges prove RLS itself blocks DML, not merely missing grants.
grant insert,update,delete on public.files,public.file_links to authenticated;
set local role authenticated;
do $$begin
 update public.files set filename='attacker.txt';assert not found;
 delete from public.files;assert not found;
 update public.file_links set entity_id=gen_random_uuid();assert not found;
 delete from public.file_links;assert not found;
 perform pg_temp.file_security_bad(format('insert into public.files(workspace_id,filename,mime_type,size) values(%L,''spoof.txt'',''text/plain'',3)',(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team')),'42501');
 perform pg_temp.file_security_bad(format('insert into public.file_links(file_id,entity_type,entity_id,relationship_type) values(%L,''EVIDENCE'',%L,''REFERENCE'')',(select id from archive_cases where label='Team'),(select id from archive_targets where kind='EVIDENCE')),'42501');
 perform pg_temp.file_security_bad('update public.files set storage_reference=''https://example.test/storage/v1/object/sign/private?token=forged''','428C9');
 -- Deliberately broad baseline Storage policies cannot override restrictive deny.
 assert not exists(select 1 from storage.objects where bucket_id='fici-private-files');
 update storage.objects set name='attacker-path' where bucket_id='fici-private-files';assert not found;
 delete from storage.objects where bucket_id='fici-private-files';assert not found;
 update storage.buckets set public=true where id='fici-private-files';assert not found;
 perform pg_temp.file_security_bad('insert into storage.objects(bucket_id,name) values(''fici-private-files'',''guessed'')','42501');
end$$;
reset role;
revoke insert,update,delete on public.files,public.file_links from authenticated;
do $$begin
 assert (select jsonb_agg(to_jsonb(f) order by id) from public.files f)=(select files from security_history);
 assert (select jsonb_agg(to_jsonb(l) order by id) from public.file_links l)=(select links from security_history);
 assert (select jsonb_agg(to_jsonb(o) order by id) from storage.objects o)=(select objects from security_history);
 assert not exists(select 1 from information_schema.columns where table_schema='public' and table_name in ('files','file_links','file_upload_requests') and column_name ~ '(signed_url|token|download_url)');
 assert (select public=false from storage.buckets where id='fici-private-files');
end$$;
select 'M12.21 File exact-ID/path/joins/Personal/TeamB/role-only/independent-target/Project-authority/RLS-DML/storage-denial/no-token-persistence PASS';
rollback;
