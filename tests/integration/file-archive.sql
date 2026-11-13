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
create temporary table archive_history as select
 (select jsonb_agg(to_jsonb(l) order by id) from public.file_links l) links,
 (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,
 (select jsonb_agg(to_jsonb(m) order by id) from public.chat_messages m) messages,
 (select jsonb_agg(to_jsonb(s) order by id) from storage.objects s) objects;
create function pg_temp.archive_bad(statement text,expected text) returns void language plpgsql as $$begin execute statement;raise exception 'Archive attack accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
set local role authenticated;
do $$declare n int;begin
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  perform pg_temp.archive_bad(format('select public.archive_file(%L)',(select id from archive_cases where label='Team')),'42501');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 perform pg_temp.archive_bad(format('select public.archive_file(%L)',(select id from archive_cases where label='Individual')),'42501');
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 perform pg_temp.archive_bad('select public.archive_file(''00000000-0000-4000-8000-999999999999'')','42501');
end$$;
savepoint archive_rollback;
select public.archive_file(id) from archive_cases;
rollback to archive_rollback;
do $$begin assert not exists(select 1 from public.files where id in(select id from archive_cases) and status<>'active'),'Rollback preserves active File';end$$;
create temporary table archive_results as select label,public.archive_file(id) payload from archive_cases;
do $$declare c record;f jsonb;begin
 for c in select * from archive_cases loop
  f:=public.archive_file(c.id);
  assert f=(select payload from archive_results where label=c.label),'Retry unchanged';
  assert f->>'status'='archived' and f->>'archived_at' is not null;
  assert f-array['status','archived_at','updated_at','updated_by']=c.before_row-array['status','archived_at','updated_at','updated_by'],'All original metadata/provenance retained';
 end loop;
 assert (select count(*) from public.file_links where file_id=(select id from archive_cases where label='Team'))=5,'All historical target links remain readable';
 assert exists(select 1 from public.evidence where file_id=(select id from archive_cases where label='Team')),'Evidence FK retained';
 perform pg_temp.archive_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from archive_cases where label='Team'),'entityType','EVIDENCE','entityId',(select id from archive_targets where kind='EVIDENCE'),'relationshipType','ATTACHMENT')),'42501');
 perform pg_temp.archive_bad('delete from public.files','42501');
 perform pg_temp.archive_bad('delete from public.file_links','42501');
 begin delete from storage.objects where bucket_id='fici-private-files';assert not found,'Client cannot delete private object';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.archive_bad(format('select public.archive_file(%L)',(select id from archive_cases where label='Team')),'42501');
do $$begin assert not exists(select 1 from public.files where id=(select id from archive_cases where label='Team'));assert exists(select 1 from public.files where id=(select id from archive_cases where label='Individual'));end$$;
set local role anon;
select pg_temp.archive_bad(format('select public.archive_file(%L)',(select id from archive_cases where label='Team')),'42501');
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(l) order by id) from public.file_links l)=(select links from archive_history);
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e)=(select evidence from archive_history);
 assert (select jsonb_agg(to_jsonb(m) order by id) from public.chat_messages m)=(select messages from archive_history);
 assert (select jsonb_agg(to_jsonb(s) order by id) from storage.objects s)=(select objects from archive_history);
 assert has_function_privilege('authenticated','public.archive_file(uuid)','execute');
 assert not has_function_privilege('anon','public.archive_file(uuid)','execute');
 assert not has_function_privilege('service_role','public.archive_file(uuid)','execute');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.archive_file(uuid)'::regprocedure);
end$$;
select 'M12.10 Personal/Team archive/current mutation/role-only/removal/idempotency/rollback/metadata/all-five-links/Evidence/Storage/history/direct-delete/grants PASS';
rollback;
