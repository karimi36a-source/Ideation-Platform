reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table link_files(label text primary key,id uuid);
create temporary table link_targets(kind public.file_link_entity_type primary key,id uuid);
create temporary table link_results(label text primary key,payload jsonb);
create temporary table link_other_targets(label text primary key,id uuid);
grant select,insert on link_files,link_targets,link_results,link_other_targets to authenticated;
create function pg_temp.register_link_file(label text,project_label text,scoped boolean default true) returns uuid language plpgsql as $$
declare r jsonb;f jsonb;begin
 select public.request_file_upload((payload->>'primary_workspace_id')::uuid,case when scoped then (payload->>'id')::uuid end,'attachment.txt','text/plain',3) into r from logged_projects where logged_projects.label=project_label;
 -- Trusted provider metadata fixture, not a production Storage mutation path.
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',r->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((r->>'id')::uuid);
 insert into link_files values(label,(f->>'id')::uuid);return (f->>'id')::uuid;
end$$;
select pg_temp.register_link_file('Team','Team');select pg_temp.register_link_file('Team2','Team');
select pg_temp.register_link_file('Workspace','Team',false);select pg_temp.register_link_file('Personal','Individual');
insert into link_targets values
 ('EVIDENCE',(public.create_evidence((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),'MEASUREMENT','File source','Recorded values','Notebook')->>'id')::uuid),
 ('ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team')),
 ('DEVELOPMENT_OBJECT',(select id from public.development_objects where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') limit 1)),
 ('ACTIVITY_INSTANCE',(select id from instances where label='Team')),
 ('CHAT_MESSAGE',(public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'File attachment message',null)->>'id')::uuid);
create temporary table link_endpoint_before as select
 (select jsonb_agg(to_jsonb(f) order by id) from public.files f) files,
 (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select to_jsonb(m) from public.chat_messages m where id=(select id from link_targets where kind='CHAT_MESSAGE')) message;
create function pg_temp.file_link_bad(statement text,expected text) returns void language plpgsql as $$begin execute statement;raise exception 'File link attack accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
set local role authenticated;
-- Every allowed AND disallowed pair is exercised against the actual RPC.
do $$declare t record;r public.file_relationship_type;ok boolean;l jsonb;retry jsonb;n integer:=0;begin
 for t in select * from link_targets loop
  foreach r in array enum_range(null::public.file_relationship_type) loop
   ok:=case t.kind when 'EVIDENCE' then r in ('EVIDENCE_SOURCE','ATTACHMENT','REFERENCE') when 'ARTIFACT' then r in ('ARTIFACT_FILE','ATTACHMENT','REFERENCE') when 'CHAT_MESSAGE' then r='CHAT_ATTACHMENT' else r in ('ATTACHMENT','REFERENCE') end;
   if ok then
    l:=public.link_file(jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType',t.kind,'entityId',t.id,'relationshipType',r));
    retry:=public.link_file(jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType',t.kind,'entityId',t.id,'relationshipType',r));
    assert l=retry,'Canonical immutable retry';n:=n+1;
    insert into link_results values(t.kind::text||'/'||r::text,l);
   else
    perform pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType',t.kind,'entityId',t.id,'relationshipType',r)),'22023');
   end if;
  end loop;
 end loop;
 assert n=11;
end$$;
insert into link_results select 'Personal',public.link_file(jsonb_build_object('fileId',f.id,'entityType','DEVELOPMENT_OBJECT','entityId',o.id,'relationshipType','ATTACHMENT')) from link_files f join public.development_objects o on o.project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual') where f.label='Personal' limit 1;
insert into link_results select 'Multiple Files',public.link_file(jsonb_build_object('fileId',f.id,'entityType','EVIDENCE','entityId',t.id,'relationshipType','EVIDENCE_SOURCE')) from link_files f cross join link_targets t where f.label='Team2' and t.kind='EVIDENCE';
-- Both endpoints readable, but incompatible Workspace => denied.
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',f.id,'entityType','EVIDENCE','entityId',t.id,'relationshipType','REFERENCE')),'42501') from link_files f cross join link_targets t where f.label='Personal' and t.kind='EVIDENCE';
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',f.id,'entityType','EVIDENCE','entityId',gen_random_uuid(),'relationshipType','REFERENCE')),'42501') from link_files f where label='Team';
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',f.id,'entityType','ARTIFACT','entityId',f.id,'relationshipType','REFERENCE')),'42501') from link_files f where label='Team';
select pg_temp.file_link_bad('insert into public.file_links(file_id,entity_type,entity_id,relationship_type) select file_id,entity_type,entity_id,relationship_type from public.file_links limit 1','42501');
select pg_temp.file_link_bad('update public.file_links set entity_id=gen_random_uuid()','42501');
select pg_temp.file_link_bad('delete from public.file_links','42501');
reset role;
do $$begin
 assert (select count(*) from public.file_links)=13;
 assert (select jsonb_agg(to_jsonb(f) order by id) from public.files f)=(select files from link_endpoint_before);
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e)=(select evidence from link_endpoint_before);
 assert (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a)=(select artifacts from link_endpoint_before);
 assert (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o)=(select objects from link_endpoint_before);
 assert (select to_jsonb(m) from public.chat_messages m where id=(select id from link_targets where kind='CHAT_MESSAGE'))=(select message from link_endpoint_before);
 assert exists(select 1 from public.file_links where file_id=(select id from link_files where label='Team') group by file_id having count(distinct entity_id)=5);
 assert exists(select 1 from public.file_links where entity_type='EVIDENCE' group by entity_id having count(distinct file_id)=2);
end$$;
-- Team Lead cannot attach to another author's message; A2 cannot discover A1's Personal link.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
set local role authenticated;
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','CHAT_MESSAGE','entityId',id,'relationshipType','CHAT_ATTACHMENT')),'42501') from link_targets where kind='CHAT_MESSAGE';
do $$begin
 assert not exists(select 1 from public.files where id=(select id from link_files where label='Personal'));
 assert not exists(select 1 from public.file_links where id=(select (payload->>'id')::uuid from link_results where label='Personal'));
 assert exists(select 1 from public.file_links where id=(select (payload->>'id')::uuid from link_results where label='CHAT_MESSAGE/CHAT_ATTACHMENT'));
end$$;
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Personal'),'entityType','EVIDENCE','entityId',id,'relationshipType','REFERENCE')),'42501') from link_targets where kind='EVIDENCE';
reset role;
-- A regular member cannot attach to another author's message either.
insert into link_other_targets values('A2 message',(public.send_team_chat_message((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'A2 attachment message',null)->>'id')::uuid);
-- A2's independent Personal target is not readable by A1.
insert into link_other_targets values('A2 Project',(public.create_development_project('A2 File link isolation','individual',(select id from public.workspaces where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000006005'))->>'id')::uuid);
insert into link_other_targets select 'A2 Object',(public.create_development_object(id,(select primary_workspace_id from public.development_projects where id=link_other_targets.id),'PROBLEM','Private A2 Problem','Private context','User')->>'id')::uuid from link_other_targets where label='A2 Project';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','CHAT_MESSAGE','entityId',id,'relationshipType','CHAT_ATTACHMENT')),'42501') from link_other_targets where label='A2 message';
do $$begin assert not exists(select 1 from public.development_objects where id=(select id from link_other_targets where label='A2 Object'));end$$;
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','DEVELOPMENT_OBJECT','entityId',id,'relationshipType','REFERENCE')),'42501') from link_other_targets where label='A2 Object';
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into link_other_targets values('Second Team Project',(public.create_development_project('Second File link Project','team',(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),null,null,(select (payload->>'owner_team_id')::uuid from logged_projects where label='Team'))->>'id')::uuid);
insert into public.project_memberships(project_id,user_id) select id,'00000000-0000-4000-8000-000000006004' from link_other_targets where label='Second Team Project';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into link_other_targets select 'Second Team Object',(public.create_development_object(id,(select primary_workspace_id from public.development_projects where id=link_other_targets.id),'PROBLEM','Other Project Problem','Separate Project','User')->>'id')::uuid from link_other_targets where label='Second Team Project';
set local role authenticated;
-- Both endpoints independently accessible in one Workspace; Project mismatch denied.
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','DEVELOPMENT_OBJECT','entityId',id,'relationshipType','REFERENCE')),'42501') from link_other_targets where label='Second Team Object';
insert into link_results select 'Workspace-only reuse',public.link_file(jsonb_build_object('fileId',(select id from link_files where label='Workspace'),'entityType','DEVELOPMENT_OBJECT','entityId',id,'relationshipType','REFERENCE')) from link_other_targets where label='Second Team Object';
reset role;
-- Role-only actors and Team B cannot read or mutate exact known links.
do $$declare n integer;begin
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  set local role authenticated;
  assert not exists(select 1 from public.file_links where file_id=(select id from link_files where label='Team'));
  perform pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','EVIDENCE','entityId',(select id from link_targets where kind='EVIDENCE'),'relationshipType','REFERENCE')),'42501');
  reset role;
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Existing Activity links survive completion; no new/retried graph mutation.
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from link_targets where kind='ACTIVITY_INSTANCE');
create temporary table completed_link_activity as select to_jsonb(a) row from public.activity_instances a where id=(select id from link_targets where kind='ACTIVITY_INSTANCE');
set local role authenticated;
do $$begin assert exists(select 1 from public.file_links where id=(select (payload->>'id')::uuid from link_results where label='ACTIVITY_INSTANCE/ATTACHMENT'));end$$;
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team2'),'entityType','ACTIVITY_INSTANCE','entityId',id,'relationshipType','ATTACHMENT')),'55000') from link_targets where kind='ACTIVITY_INSTANCE';
reset role;
do $$begin assert (select to_jsonb(a) from public.activity_instances a where id=(select id from link_targets where kind='ACTIVITY_INSTANCE'))=(select row from completed_link_activity);end$$;
update public.activity_instances set status='archived' where id=(select id from link_targets where kind='ACTIVITY_INSTANCE');
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team2'),'entityType','ACTIVITY_INSTANCE','entityId',id,'relationshipType','REFERENCE')),'55000') from link_targets where kind='ACTIVITY_INSTANCE';
-- Deleted messages cannot receive attachments (fixture only; no edit API).
insert into public.chat_messages(chat_channel_id,sender_user_id,content,message_type,deleted_at)
 select chat_channel_id,sender_user_id,'Deleted fixture','TEXT',clock_timestamp() from public.chat_messages where id=(select id from link_targets where kind='CHAT_MESSAGE');
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','CHAT_MESSAGE','entityId',id,'relationshipType','CHAT_ATTACHMENT')),'42501') from public.chat_messages where content='Deleted fixture';
update public.files set status='archived',archived_at=clock_timestamp() where id=(select id from link_files where label='Team2');
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team2'),'entityType','EVIDENCE','entityId',id,'relationshipType','EVIDENCE_SOURCE')),'42501') from link_targets where kind='EVIDENCE';
do $$begin assert exists(select 1 from public.file_links where file_id=(select id from link_files where label='Team2'));end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'owner_team_id')::uuid from logged_projects where label='Team'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','CHAT_MESSAGE','entityId',id,'relationshipType','CHAT_ATTACHMENT')),'42501') from link_targets where kind='CHAT_MESSAGE';
do $$begin assert not exists(select 1 from public.file_links where file_id=(select id from link_files where label='Team'));assert exists(select 1 from public.file_links where file_id=(select id from link_files where label='Personal'));end$$;
reset role;
-- Remaining Team Lead still has endpoint access; archival must independently
-- prevent new graph mutation. These are trusted lifecycle fixtures only.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
update public.chat_channels set status='archived' where id=(select chat_channel_id from public.chat_messages where id=(select id from link_other_targets where label='A2 message'));
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','CHAT_MESSAGE','entityId',id,'relationshipType','CHAT_ATTACHMENT')),'42501') from link_other_targets where label='A2 message';
update public.evidence set archived_at=clock_timestamp() where id=(select id from link_targets where kind='EVIDENCE');
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','EVIDENCE','entityId',id,'relationshipType','EVIDENCE_SOURCE')),'42501') from link_targets where kind='EVIDENCE';
update public.artifacts set status='ARCHIVED',archived_at=clock_timestamp() where id=(select id from link_targets where kind='ARTIFACT');
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','ARTIFACT','entityId',id,'relationshipType','ARTIFACT_FILE')),'42501') from link_targets where kind='ARTIFACT';
select public.archive_development_object(id) from link_targets where kind='DEVELOPMENT_OBJECT';
select pg_temp.file_link_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select id from link_files where label='Team'),'entityType','DEVELOPMENT_OBJECT','entityId',id,'relationshipType','REFERENCE')),'42501') from link_targets where kind='DEVELOPMENT_OBJECT';
do $$begin
 assert (select count(*) from public.file_links)=14,'Historical links preserved';
 assert not has_table_privilege('authenticated','public.file_links','INSERT');
 assert not has_function_privilege('anon','public.link_file(jsonb)','execute');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.link_file(jsonb)'::regprocedure);
end$$;
select 'M12.8 File links full matrix/registered Files/Personal/Team/independent scopes/Chat author/lifecycle/history/no endpoint mutation/RLS PASS';
rollback;
