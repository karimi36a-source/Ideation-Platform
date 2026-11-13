reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table snapshot_context(label text primary key,id uuid);
create function pg_temp.snap_id(label0 text) returns uuid language sql as $$select id from snapshot_context where label=$1$$;
create function pg_temp.snap_bad(statement text,expected text default '23514') returns void language plpgsql as $$begin execute statement;raise exception 'Snapshot attack succeeded';exception when others then if sqlstate<>expected then raise;end if;end$$;
grant select on snapshot_context to authenticated,anon;
do $$declare p jsonb;a jsonb;b jsonb;v jsonb;s uuid;sid uuid;initial uuid;begin
 select payload into p from logged_projects where label='Team';
 a:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Selected framework',null,false,false);
 b:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Sibling secret never exposed',null,false,false);
 insert into snapshot_context values('Artifact',(a->>'artifactId')::uuid),('Sibling',(b->>'artifactId')::uuid),('SiblingVersion',(b->>'initialVersionId')::uuid);
 v:=public.create_artifact_version((a->>'artifactId')::uuid,'{"notes":"Intentionally shared V2"}','V2 checkpoint');
 insert into snapshot_context values('V2',(v->>'id')::uuid);
 -- The public operation returns a canonical Version row; no client Version ID.
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('ARTIFACT',(a->>'artifactId')::uuid,'USER','00000000-0000-4000-8000-000000006006','VIEW','SNAPSHOT') returning id into s;
 insert into snapshot_context values('Share',s);
 insert into public.share_snapshots(share_id,source_version_id) values(s,pg_temp.snap_id('V2')) returning id into sid;
 insert into snapshot_context values('Snapshot',sid);
 assert exists(select 1 from public.share_snapshots where id=sid and source_version_id=pg_temp.snap_id('V2') and snapshot_data->'content'->'content_snapshot'='{"notes":"Intentionally shared V2"}'::jsonb);
 perform pg_temp.snap_bad(format('insert into public.share_snapshots(share_id,source_version_id) values (%L,%L)',s,pg_temp.snap_id('V2')),'23505');
 perform pg_temp.snap_bad(format('insert into public.share_snapshots(share_id,source_version_id) values (%L,%L)',s,pg_temp.snap_id('SiblingVersion')));
 perform pg_temp.snap_bad(format('insert into public.share_snapshots(share_id) values (%L)',s));
 perform pg_temp.snap_bad(format('insert into public.share_snapshots(share_id,source_version_id,snapshot_data) values (%L,%L,%L)',s,pg_temp.snap_id('V2'),'{"workspace":{"siblings":"private"},"provenance":{"source_created_by":"forged"}}'));
 perform pg_temp.snap_bad(format('insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values (%L,%L,%L,%L,%L,%L)','ARTIFACT',pg_temp.snap_id('Artifact'),'USER','00000000-0000-4000-8000-000000006006','VIEW','LIVE_REFERENCE'),'0A000');
 perform 'LIVE_REFERENCE'::public.share_mode;
 assert exists(select 1 from public.share_snapshots where id=sid and snapshot_data->'provenance'->>'share_id'=s::text
  and snapshot_data->'provenance'->>'source_entity_id'=pg_temp.snap_id('Artifact')::text
  and snapshot_data->'provenance'->>'source_workspace_id'=p->>'primary_workspace_id'
  and snapshot_data->'provenance'->>'source_created_by'=public.current_platform_user_id()::text
  and snapshot_data->'provenance'->>'source_owner_team_id'=p->>'owner_team_id');
 assert not exists(select 1 from public.share_snapshots where snapshot_data::text like '%Sibling secret never exposed%');
 assert (select array_agg(k order by k)=array['content','provenance'] from public.share_snapshots x cross join lateral jsonb_object_keys(x.snapshot_data) k where x.id=sid);
end $$;
create temporary table snapshot_history as select to_jsonb(x) payload from public.share_snapshots x where id=pg_temp.snap_id('Snapshot');
do $$declare v jsonb;p jsonb;f jsonb;r jsonb;entry uuid;s uuid;k text;source uuid;begin
 v:=public.create_artifact_version(pg_temp.snap_id('Artifact'),'{"notes":"Different V3 body"}','V3 checkpoint');
 insert into snapshot_context values('V3',(v->>'id')::uuid);
 assert pg_temp.snap_id('V3')<>pg_temp.snap_id('V2');
 assert (select to_jsonb(x)=(select payload from snapshot_history) from public.share_snapshots x where id=pg_temp.snap_id('Snapshot'));
 select payload into p from logged_projects where label='Team';
 foreach k in array array['EVIDENCE','PATENT_RECORD','DEVELOPMENT_OBJECT'] loop
  source:=pg_temp.research_source(case k when 'EVIDENCE' then 'Evidence' when 'PATENT_RECORD' then 'Patent' else 'Gap' end);
  insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
  values(k::public.share_entity_type,source,'USER','00000000-0000-4000-8000-000000006006','VIEW','SNAPSHOT') returning id into s;
  insert into public.share_snapshots(share_id) values(s);
  perform pg_temp.snap_bad(format('insert into public.share_snapshots(share_id,source_version_id) values (%L,%L)',s,pg_temp.snap_id('V2')));
 end loop;
 -- A changed current Object does not rewrite its frozen, unversioned projection.
 perform public.update_development_object(pg_temp.research_source('Gap'),'{"title":"Later current Gap"}');
 assert not exists(select 1 from public.share_snapshots where snapshot_data::text like '%Later current Gap%');
 r:=public.request_file_upload((p->>'primary_workspace_id')::uuid,(p->>'id')::uuid,'snapshot.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',r->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((r->>'id')::uuid);
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('FILE',(f->>'id')::uuid,'USER','00000000-0000-4000-8000-000000006006','VIEW','SNAPSHOT') returning id into s;
 insert into public.share_snapshots(share_id) values(s);
 insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
 select id,project_id,workspace_id,public.current_platform_user_id(),'SUBSTITUTE','Original','Proposed','Frozen result' from public.activity_instances where id=(select id from instances where label='Individual') returning id into entry;
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('SCAMPER_ENTRY',entry,'USER','00000000-0000-4000-8000-000000006006','VIEW','SNAPSHOT') returning id into s;
 insert into public.share_snapshots(share_id) values(s);
 assert (select count(*) from public.share_snapshots)=6;
 assert (select count(*) from public.share_snapshots where source_version_id is null)=5;
 assert not exists(select 1 from public.share_snapshots where snapshot_data::text like '%storage_reference%' or snapshot_data::text like '%why_retained%' or snapshot_data::text like '%metadata%' or snapshot_data::text like '%activity_instance_id%' or snapshot_data::text like '%idea_object_id%');
 perform pg_temp.snap_bad(format('update public.share_snapshots set snapshot_data=%L where id=%L','{}',pg_temp.snap_id('Snapshot')));
 perform pg_temp.snap_bad(format('update public.share_snapshots set source_version_id=%L where id=%L',pg_temp.snap_id('V3'),pg_temp.snap_id('Snapshot')));
 perform pg_temp.snap_bad(format('update public.share_snapshots set created_at=clock_timestamp() where id=%L',pg_temp.snap_id('Snapshot')));
 perform pg_temp.snap_bad(format('delete from public.share_snapshots where id=%L',pg_temp.snap_id('Snapshot')));
 perform pg_temp.snap_bad('insert into public.share_snapshots(share_id) values (''ffffffff-ffff-4fff-8fff-ffffffffffff'')','23503');
 update public.shares set revoked_at=clock_timestamp(),revoked_by=public.current_platform_user_id() where id=pg_temp.snap_id('Share');
 assert (select to_jsonb(x)=(select payload from snapshot_history) from public.share_snapshots x where id=pg_temp.snap_id('Snapshot'));
 perform pg_temp.snap_bad(format('insert into public.share_snapshots(share_id,source_version_id) values (%L,%L)',pg_temp.snap_id('Share'),pg_temp.snap_id('V2')));
 assert (select relrowsecurity from pg_class where oid='public.share_snapshots'::regclass);
 assert not has_function_privilege('authenticated','private.validate_share_snapshot()','EXECUTE');
 assert not has_function_privilege('authenticated','private.enforce_mvp_share_mode()','EXECUTE');
end $$;
select 'SHARE_SNAPSHOT_ROW='||to_jsonb(x)::text from public.share_snapshots x where id=pg_temp.snap_id('Snapshot');
grant select,insert,update,delete on public.share_snapshots to authenticated;
set local role authenticated;
do $$declare n integer;begin
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  assert not exists(select 1 from public.share_snapshots where id=pg_temp.snap_id('Snapshot'));
  assert not exists(select 1 from public.artifacts where id=pg_temp.snap_id('Artifact'));
  assert not exists(select 1 from public.share_snapshots x join public.artifacts a on a.id=(x.snapshot_data->'provenance'->>'source_entity_id')::uuid);
  if n=6006 then
   assert not exists(select 1 from public.workspaces where id=(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'));
  end if;
  perform pg_temp.snap_bad(format('insert into public.share_snapshots(share_id,source_version_id) values (%L,%L)',pg_temp.snap_id('Share'),pg_temp.snap_id('V2')),'42501');
 end loop;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','Snapshot revocation regression');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.share_snapshots);assert not exists(select 1 from public.artifacts where id=pg_temp.snap_id('Artifact'));end $$;
reset role;
select 'M13.2 SNAPSHOT-only/canonical-V2-V3/five-unversioned/projection/provenance/frozen/history/default-deny/LIVE-deferred/privacy PASS';
rollback;
