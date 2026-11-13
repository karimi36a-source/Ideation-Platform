-- Trusted schema fixtures only: no upload/registration/link/download API.
reset role;
create temporary table file_cases(label text primary key,id uuid);
create temporary table file_scope_counts as select (select count(*) from public.development_projects) projects,(select count(*) from public.workspaces) workspaces;
grant select on file_cases to authenticated;
create function pg_temp.insert_file(label text,project_label text,scoped boolean default true) returns uuid language plpgsql as $$
declare result uuid;begin
 insert into public.files(workspace_id,project_id,filename,mime_type,size,created_at)
 select (payload->>'primary_workspace_id')::uuid,case when scoped then (payload->>'id')::uuid end,
 'Canonical drawing.svg','image/svg+xml',4096,'2000-01-01' from logged_projects where logged_projects.label=project_label returning id into result;
 insert into file_cases values(label,result);return result;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.insert_file('Team','Team');select pg_temp.insert_file('Team Workspace','Team',false);
select pg_temp.insert_file('Personal','Individual');select pg_temp.insert_file('Personal Workspace','Individual',false);
select pg_temp.insert_file('Archived','Team');
create temporary table file_baseline as select to_jsonb(f) payload from public.files f;
do $$begin
 assert (select count(*) from public.files)=5;
 assert not exists(select 1 from public.files where uploaded_by<>'00000000-0000-4000-8000-000000006004' or updated_by<>uploaded_by or status<>'active' or archived_at is not null or created_at<'2026-01-01');
 assert not exists(select 1 from public.files where storage_reference<>'workspaces/'||workspace_id::text||'/files/'||id::text or filename<>'Canonical drawing.svg' or mime_type<>'image/svg+xml' or size<>4096);
end$$;
create function pg_temp.file_bad(statement text,expected text) returns void language plpgsql as $$
begin execute statement;raise exception 'Invalid File write accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
do $$declare w uuid;p uuid;prefix text;begin
 select (payload->>'primary_workspace_id')::uuid,(payload->>'id')::uuid into w,p from logged_projects where label='Team';
 prefix:=format('insert into public.files(workspace_id,project_id,filename,mime_type,size)',w,p);
 perform pg_temp.file_bad(prefix||format(' values(%L,%L,''../private'',''text/plain'',1)',w,p),'23514');
 perform pg_temp.file_bad(prefix||format(' values(%L,%L,E''..\\\\private'',''text/plain'',1)',w,p),'23514');
 perform pg_temp.file_bad(prefix||format(' values(%L,%L,''safe'',''invalid'',1)',w,p),'23514');
 perform pg_temp.file_bad(prefix||format(' values(%L,%L,''safe'',''../image'',1)',w,p),'23514');
 perform pg_temp.file_bad(prefix||format(' values(%L,%L,''safe'',''text/plain'',-1)',w,p),'23514');
 perform pg_temp.file_bad(format('insert into public.files(workspace_id,filename,mime_type,size,uploaded_by) values(%L,''safe'',''text/plain'',1,%L)',w,'00000000-0000-4000-8000-000000006005'),'42501');
 perform pg_temp.file_bad(format('insert into public.files(workspace_id,filename,mime_type,size,storage_reference) values(%L,''safe'',''text/plain'',1,''https://example.test/other'')',w),'428C9');
 perform pg_temp.file_bad(format('insert into public.files(workspace_id,project_id,filename,mime_type,size) values(%L,%L,''safe'',''text/plain'',1)',(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),p),'42501');
 perform pg_temp.file_bad(format('update public.files set archived_at=clock_timestamp() where id=%L',(select id from file_cases where label='Team')),'23514');
 perform pg_temp.file_bad(format('update public.files set status=''archived'' where id=%L',(select id from file_cases where label='Team')),'23514');
 perform pg_temp.file_bad(format('update public.files set status=''pending'' where id=%L',(select id from file_cases where label='Team')),'22P02');
 perform pg_temp.file_bad(format('update public.files set uploaded_by=%L where id=%L','00000000-0000-4000-8000-000000006005',(select id from file_cases where label='Team')),'23514');
 perform pg_temp.file_bad(format('delete from public.files where id=%L',(select id from file_cases where label='Team')),'55000');
end$$;
update public.files set status='archived',archived_at=clock_timestamp() where id=(select id from file_cases where label='Archived');
select pg_temp.file_bad(format('update public.files set status=''active'',archived_at=null where id=%L',(select id from file_cases where label='Archived')),'55000');
-- File linkage is schema-only and must not create visibility through either side.
insert into public.file_links(file_id,entity_type,entity_id,relationship_type)
 select id,'ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),'REFERENCE' from file_cases where label='Team';
select pg_temp.file_bad(format('insert into public.file_links(file_id,entity_type,entity_id,relationship_type) select file_id,entity_type,entity_id,relationship_type from public.file_links limit 1'),'23505');
insert into public.file_links(file_id,entity_type,entity_id,relationship_type)
 select file_id,entity_type,entity_id,'ATTACHMENT' from public.file_links limit 1;
update public.file_links set archived_at=clock_timestamp() where relationship_type='REFERENCE';
insert into public.file_links(file_id,entity_type,entity_id,relationship_type)
 select file_id,entity_type,entity_id,relationship_type from public.file_links where archived_at is not null;
select pg_temp.file_bad('delete from public.file_links','55000');
-- Evidence FK resolves now; ordinary createEvidence non-null input stays deferred.
insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name,file_id)
 select (p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,'MEASUREMENT','File-backed fixture','Recorded source','Named notebook',f.id from logged_projects p join file_cases f on f.label='Team Workspace' where p.label='Team';
do $$declare p jsonb;begin
 select payload into p from logged_projects where label='Team';
 perform pg_temp.file_bad(format('insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name,file_id) values(%L,%L,''OTHER'',''T'',''D'',''S'',%L)',p->>'id',p->>'primary_workspace_id',(select id from file_cases where label='Personal')),'42501');
 perform pg_temp.file_bad(format('insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name,file_id) values(%L,%L,''OTHER'',''T'',''D'',''S'',%L)',p->>'id',p->>'primary_workspace_id',(select id from file_cases where label='Archived')),'42501');
 perform pg_temp.file_bad(format('select public.create_evidence(%L,%L,''OTHER'',''T'',''D'',''S'',null,%L)',p->>'id',p->>'primary_workspace_id',(select id from file_cases where label='Team')),'0A000');
end$$;
-- A pure role-only Mentor fixture, distinct from the accepted contextual Team Mentor.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006009','file-role-mentor@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006009','active');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000006009','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000006001');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert (select count(*) from public.files)=5,'M12.10 current scope permits retained archived metadata';
 assert (select count(*) from public.files where project_id is null)=2;
 assert not exists(select 1 from public.file_links);
 assert not exists(select 1 from public.file_links l join public.files f on f.id=l.file_id);
end$$;
select 'FILE_SCHEMA_ROW='||to_jsonb(f)::text from public.files f where id=(select id from file_cases where label='Team');
do $$declare n int;begin
 foreach n in array array[6007,6002,6003,6001,6009] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  assert not exists(select 1 from public.files);
  assert not exists(select 1 from public.files where id=(select id from file_cases where label='Team'));
  assert not exists(select 1 from public.files where storage_reference like 'workspaces/%');
  assert not exists(select 1 from public.file_links);
  assert not exists(select 1 from public.file_links l join public.artifacts a on a.id=l.entity_id);
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert exists(select 1 from public.files where id=(select id from file_cases where label='Team'));
 assert not exists(select 1 from public.files where id=(select id from file_cases where label='Personal'));
 assert not exists(select 1 from public.file_links),'File access does not reveal private targets';
end$$;
do $$declare statement text;begin
 foreach statement in array array[
  'insert into public.files default values',
  'insert into public.files(uploaded_by,workspace_id,filename,mime_type,size) select ''00000000-0000-4000-8000-000000006007'',(payload->>''workspaceId'')::uuid,''fake'',''text/plain'',1 from acceptance_teams where label=''B''',
  'insert into public.files(storage_reference) values(''workspaces/other/files/guessed'')',
  'update public.files set uploaded_by=''00000000-0000-4000-8000-000000006007''',
  'update public.files set storage_reference=''https://example.test/public''',
  'delete from public.files',
  'insert into public.file_links default values','update public.file_links set relationship_type=''REFERENCE''','delete from public.file_links'
 ] loop
  -- PostgreSQL rejects assignments to generated columns during analysis,
  -- before the ordinary table privilege check. Both outcomes deny mutation.
  perform pg_temp.file_bad(statement,case when statement like '%storage_reference%' then '428C9' else '42501' end);
 end loop;
end$$;
reset role;
create temporary table files_before_removal as select jsonb_agg(to_jsonb(f) order by id) payload from public.files f;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.files where id=(select id from file_cases where label='Team'));
 assert not exists(select 1 from public.files where id=(select id from file_cases where label='Team Workspace'));
 assert exists(select 1 from public.files where id=(select id from file_cases where label='Personal'));
 assert not exists(select 1 from public.file_links);
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert exists(select 1 from public.files where id=(select id from file_cases where label='Team')),'Remaining authorized Team member retains metadata access';end$$;
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(f) order by id) from public.files f)=(select payload from files_before_removal);
 assert (select count(*) from public.development_projects)=(select projects from file_scope_counts);
 assert (select count(*) from public.workspaces)=(select workspaces from file_scope_counts);
 assert exists(select 1 from pg_constraint where conrelid='public.evidence'::regclass and conname='evidence_file_reference' and confrelid='public.files'::regclass and confdeltype='r');
 assert exists(select 1 from pg_constraint where conrelid='public.files'::regclass and conname='files_project_workspace' and confrelid='public.development_projects'::regclass);
 assert not has_table_privilege('authenticated','public.files','INSERT');
 assert not has_table_privilege('authenticated','public.files','UPDATE');
 assert not has_table_privilege('authenticated','public.file_links','INSERT');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.can_read_file_scope(uuid,uuid)'::regprocedure);
 assert not has_function_privilege('anon','public.can_read_file_scope(uuid,uuid)','execute');
 assert not has_function_privilege('authenticated','private.preserve_file_history()','execute');
 assert exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey) where c.conrelid='public.files'::regclass and c.contype='u' and a.attname='storage_reference');
 -- M12.7 now owns narrow upload/registration RPCs; linking/download remain deferred.
 assert not exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname='request_download');
 assert has_function_privilege('authenticated','public.link_file(jsonb)','execute');
 assert not has_function_privilege('anon','public.link_file(jsonb)','execute');
 assert has_function_privilege('authenticated','public.register_uploaded_file(uuid)','execute');
 assert not has_function_privilege('anon','public.register_uploaded_file(uuid)','execute');
 assert (select count(*) from public.file_links)=3,'Archived link and different relationships preserved';
end$$;
select 'FILE_LINK_SCHEMA_ROW='||to_jsonb(l)::text from public.file_links l order by id limit 1;
select 'FILE_VOCABULARY='||jsonb_build_object('status',enum_range(null::public.file_status),'entities',enum_range(null::public.file_link_entity_type),'relationships',enum_range(null::public.file_relationship_type))::text;
-- Storage metadata contract only. Actual public HTTP proof requires a provider.
insert into storage.objects(bucket_id,name) values('fici-private-files','disposable-fixture'),('unrelated-fixture','unrelated-fixture');
set local role anon;
do $$begin
 assert not exists(select 1 from storage.objects where bucket_id='fici-private-files');
 assert not exists(select 1 from storage.buckets where id='fici-private-files');
 assert exists(select 1 from storage.objects where bucket_id='unrelated-fixture'),'Unrelated bucket policy untouched';
 begin perform count(*) from public.files;raise exception 'Anonymous metadata';exception when insufficient_privilege then null;end;
 begin perform count(*) from public.file_links;raise exception 'Anonymous links';exception when insufficient_privilege then null;end;
 begin insert into storage.objects(bucket_id,name) values('fici-private-files','spoof');raise exception 'Anonymous object insert';exception when insufficient_privilege then null;end;
end$$;
set local role authenticated;
do $$begin
 assert not exists(select 1 from storage.objects where bucket_id='fici-private-files');
 update storage.buckets set public=true where id='fici-private-files';
 assert not found,'Client cannot change private bucket visibility';
 begin insert into storage.objects(bucket_id,name) values('fici-private-files','spoof');raise exception 'Premature client upload';exception when insufficient_privilege then null;end;
end$$;
reset role;
do $$begin assert (select public=false from storage.buckets where id='fici-private-files');end$$;
select 'M12.6 files/links/Personal/Team/workspace-only/project/scope/spoof/history/archive/FK/deny-links/storage-policy-contract PASS';
rollback;
