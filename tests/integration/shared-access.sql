reset role;
create temporary table shared_access_context(label text primary key,payload jsonb);
grant select,insert on shared_access_context to authenticated;
create function pg_temp.shared_id(label0 text) returns uuid language sql as $$select (payload->>'id')::uuid from shared_access_context where label=$1$$;
create function pg_temp.shared_access(label0 text) returns jsonb language sql as $$select public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.shared_id($1)))$$;
create function pg_temp.shared_denied(input0 jsonb) returns void language plpgsql as $$begin
 assert public.resolve_shared_entity_access(input0)='{"allowed":false,"canView":false,"canComment":false,"canEdit":false,"canReshare":false,"isSnapshot":false,"isLiveReference":false}'::jsonb;
end$$;
create function pg_temp.shared_expect(label0 text,comment0 boolean) returns void language plpgsql as $$declare r jsonb;begin
 r:=pg_temp.shared_access(label0);assert r->'allowed'='true'::jsonb,r::text;
 assert r->'canView'='true'::jsonb and (r->>'canComment')::boolean=comment0 and r->'canEdit'='false'::jsonb and r->'canReshare'='false'::jsonb;
 assert r->'isSnapshot'='true'::jsonb and r->'isLiveReference'='false'::jsonb;
 assert (select count(*) from jsonb_object_keys(r))=12;
 assert not r?'sourceWorkspaceId' and not r?'provenance' and not r?'snapshotId';
end$$;
create temporary table shared_master as select ra.id,ra.ends_at,ra.status from public.role_assignments ra join public.roles r on r.id=ra.role_id
 where r.code='MASTER' and ra.user_id='00000000-0000-4000-8000-000000006002' and ra.cohort_id=(select id from acceptance_cohorts where label='Test');
grant select on shared_master to authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005','member');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare p jsonb;a jsonb;b jsonb;v jsonb;request jsonb;r jsonb;u jsonb;f jsonb;entry uuid;before_source jsonb;review_count bigint;begin
 select payload into p from logged_projects where label='Team';
 a:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Selected only',null,false,false);
 b:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Unrelated sibling secret',null,false,false);
 v:=public.create_artifact_version((a->>'artifactId')::uuid,'{"notes":"Frozen V2"}','V2');
 insert into shared_access_context values('Artifact',jsonb_build_object('id',a->>'artifactId')),('V1',jsonb_build_object('id',a->>'initialVersionId')),('V2',v),('Sibling',jsonb_build_object('id',b->>'artifactId'));
 request:=pg_temp.share_request('ARTIFACT',(a->>'artifactId')::uuid)||jsonb_build_object('sourceVersionId',v->>'id');
 r:=public.share_entity(request);insert into shared_access_context values('View',r);
 r:=public.share_entity(request||'{"permissionLevel":"COMMENT"}');insert into shared_access_context values('Comment',r);
 -- M13.7: the Share transaction must not become submission/review or ownership transfer.
 select to_jsonb(x) into before_source from public.artifacts x where id=(a->>'artifactId')::uuid;
 select count(*) into review_count from public.submissions;
 request:=request||jsonb_build_object('destinationType','MASTER','destinationId',(select id from shared_master));
 r:=public.share_entity(request);insert into shared_access_context values('Master',r);
 assert public.share_entity(request)=r,'Exact Master retry changed canonical Share';
 r:=public.share_entity(request||'{"permissionLevel":"COMMENT"}');insert into shared_access_context values('MasterComment',r);
 assert before_source=(select to_jsonb(x) from public.artifacts x where id=(a->>'artifactId')::uuid),'Share changed source Artifact';
 assert review_count=(select count(*) from public.submissions),'Share created submission';
 r:=public.share_entity(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent'),target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));insert into shared_access_context values('TeamA',r);
 r:=public.share_entity(pg_temp.share_request());insert into shared_access_context values('Patent',r);
 r:=public.share_entity(pg_temp.share_request('EVIDENCE',pg_temp.research_source('Evidence')));insert into shared_access_context values('Evidence',r);
 r:=public.share_entity(pg_temp.share_request('DEVELOPMENT_OBJECT',pg_temp.research_source('Gap')));insert into shared_access_context values('Object',r);
 u:=public.request_file_upload((p->>'primary_workspace_id')::uuid,(p->>'id')::uuid,'frozen-metadata.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',u->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((u->>'id')::uuid);insert into shared_access_context values('FileRow',f);
 r:=public.share_entity(pg_temp.share_request('FILE',(f->>'id')::uuid));insert into shared_access_context values('File',r);
 select payload into p from logged_projects where label='Individual';
 insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
 select id,(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,public.current_platform_user_id(),'SUBSTITUTE','Original','Proposed','Shared result' from instances where label='Individual' returning id into entry;
 r:=public.share_entity(pg_temp.share_request('SCAMPER_ENTRY',entry,target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));insert into shared_access_context values('Scamper',r);
 v:=public.create_artifact_version((a->>'artifactId')::uuid,'{"notes":"Unshared V3"}','V3');insert into shared_access_context values('V3',v);
end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
select pg_temp.shared_expect('View',false),pg_temp.shared_expect('Comment',true);
select pg_temp.shared_expect('Patent',false),pg_temp.shared_expect('Evidence',false),pg_temp.shared_expect('Object',false),pg_temp.shared_expect('File',false);
select 'SHARED_ACCESS_ROW='||pg_temp.shared_access('View')::text;
do $$declare r jsonb;begin
 r:=pg_temp.shared_access('View');assert (r->>'sourceVersionId')::uuid=pg_temp.shared_id('V2');
 assert r->'snapshotContent'->'content_snapshot'='{"notes":"Frozen V2"}'::jsonb;
 assert r::text not like '%Unshared V3%' and r::text not like '%Unrelated sibling secret%';
 assert not exists(select 1 from public.artifacts where id in(pg_temp.shared_id('Artifact'),pg_temp.shared_id('Sibling')));
 assert not exists(select 1 from public.artifact_versions where artifact_id=pg_temp.shared_id('Artifact'));
 assert not exists(select 1 from public.workspaces where id=(select (payload->>'source_workspace_id')::uuid from shared_access_context where label='View'));
 assert not exists(select 1 from public.files where id=pg_temp.shared_id('FileRow'));
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent'));
 assert not exists(select 1 from public.evidence where id=pg_temp.research_source('Evidence'));
 assert not exists(select 1 from public.development_objects where id=pg_temp.research_source('Gap'));
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from acceptance_teams where label='A')) is null;
 assert not public.can_access_team_chat((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A'));
 assert (public.resolve_shareability(pg_temp.share_request('ARTIFACT',pg_temp.shared_id('Artifact')))->>'allowed')::boolean=false;
 assert not (pg_temp.shared_access('File')->'snapshotContent'?'storage_reference');
end$$;
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Master')));
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('TeamA')));
select pg_temp.shared_denied('{"shareId":"ffffffff-ffff-4fff-8fff-ffffffffffff"}');
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('V2')));
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Artifact')));
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('View'),'actorId','spoof'));
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('View'),'sourceWorkspaceId','spoof'));
select pg_temp.shared_denied('{}'),pg_temp.shared_denied('[]'),pg_temp.shared_denied('null'),pg_temp.shared_denied('{"shareId":null}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.shared_expect('TeamA',false),pg_temp.shared_expect('Scamper',false);
do $$begin
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('PersonalPatent'));
 begin
  assert not exists(select 1 from public.scamper_entries where id=(pg_temp.shared_access('Scamper')->>'sharedEntityId')::uuid);
 exception when insufficient_privilege then null; -- Existing direct SELECT is denied even before RLS.
 end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
reset role;
-- Direct Snapshot IDs and even separately granted table SELECT cannot bypass RLS.
grant select on public.shares,public.share_snapshots to authenticated;
insert into shared_access_context select 'Snapshot',jsonb_build_object('id',id) from public.share_snapshots where share_id=pg_temp.shared_id('View');
set local role authenticated;
do $$begin assert not exists(select 1 from public.shares);assert not exists(select 1 from public.share_snapshots);end$$;
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Snapshot')));
-- Exact Master assignment, not role-only platform authority or source access.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.shared_expect('Master',false);
select pg_temp.shared_expect('MasterComment',true);
do $$declare r jsonb;begin
 r:=pg_temp.shared_access('Master');
 assert (r->>'sourceVersionId')::uuid=pg_temp.shared_id('V2');
 assert r->'snapshotContent'->'content_snapshot'='{"notes":"Frozen V2"}'::jsonb;
 assert not exists(select 1 from public.artifact_versions where artifact_id=pg_temp.shared_id('Artifact'));
 assert not exists(select 1 from public.artifacts where id=pg_temp.shared_id('Sibling'));
 assert not exists(select 1 from public.workspaces where id=(select (payload->>'source_workspace_id')::uuid from shared_access_context where label='Master'));
 assert not exists(select 1 from public.files where id=pg_temp.shared_id('FileRow'));
 assert public.get_team_workspace_access((select (payload->>'workspaceId')::uuid from acceptance_teams where label='A')) is null;
 assert not public.can_access_team_chat((select (payload->>'chatChannelId')::uuid from acceptance_teams where label='A'));
end$$;
do $$begin assert not exists(select 1 from public.artifacts where id=pg_temp.shared_id('Artifact'));end$$;
reset role;
update public.role_assignments set ends_at=statement_timestamp()-interval '1 second' where id=(select id from shared_master);
set local role authenticated;
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Master')));
reset role;
update public.role_assignments a set ends_at=m.ends_at,status='inactive' from shared_master m where a.id=m.id;
set local role authenticated;
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Master')));
reset role;
update public.role_assignments a set status=m.status from shared_master m where a.id=m.id;
set local role authenticated;
select pg_temp.shared_expect('Master',false);
-- No unrelated Master/Admin/Mentor authority, nor source-owner shortcut.
do $$declare u text;begin
 foreach u in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',u,true);
  perform pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('View')));
 end loop;
end$$;
-- Source owner access is unchanged and separate from Share-derived capabilities.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert exists(select 1 from public.artifacts where id=pg_temp.shared_id('Artifact'));end$$;
reset role;
-- Deferred rows are trusted structural fixtures, never newly enabled runtime modes.
do $$declare s uuid;begin
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('PATENT_RECORD',pg_temp.research_source('Patent'),'TEAM',(select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'COLLABORATE','SNAPSHOT') returning id into s;
 insert into public.share_snapshots(share_id) values(s);
 insert into shared_access_context values('Collaborate',jsonb_build_object('id',s));
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('PATENT_RECORD',pg_temp.research_source('Patent'),'USER','00000000-0000-4000-8000-000000006007','VIEW','SNAPSHOT') returning id into s;
 insert into public.share_snapshots(share_id) values(s);insert into shared_access_context values('User',jsonb_build_object('id',s));
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('PATENT_RECORD',pg_temp.research_source('Patent'),'TEAM',(select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'COMMENT','SNAPSHOT') returning id into s;
 insert into shared_access_context values('MissingSnapshot',jsonb_build_object('id',s));
end$$;
-- Legacy/inert LIVE_REFERENCE fixture bypasses only the insertion guard in this
-- rolled-back test. The resolver must still reject it before any source read.
alter table public.shares disable trigger shares_00_mvp_mode;
insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('PATENT_RECORD',pg_temp.research_source('Patent'),'TEAM',(select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'VIEW','LIVE_REFERENCE');
insert into shared_access_context select 'Live',jsonb_build_object('id',id) from public.shares where share_mode='LIVE_REFERENCE';
alter table public.shares enable trigger shares_00_mvp_mode;
-- M13.16: a legacy Artifact Live Reference must never follow latest or expose history.
alter table public.shares disable trigger shares_00_mvp_mode;
insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('ARTIFACT',pg_temp.shared_id('Artifact'),'TEAM',(select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'VIEW','LIVE_REFERENCE');
insert into shared_access_context select 'ArtifactLive',jsonb_build_object('id',id) from public.shares where shared_entity_type='ARTIFACT' and share_mode='LIVE_REFERENCE';
alter table public.shares enable trigger shares_00_mvp_mode;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('ArtifactLive')));
select 'M13.16 legacy-ARTIFACT-LIVE_REFERENCE/frozen-only/no-history PASS';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Collaborate'))),pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('User'))),pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Live')));
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('MissingSnapshot')));
-- Dynamic revocation: no deletion, membership grant, or Snapshot rewrite.
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
update public.shares set revoked_at=clock_timestamp(),revoked_by=public.current_platform_user_id() where id=pg_temp.shared_id('Comment');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Comment')));
select pg_temp.shared_expect('View',false);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007','M13.5 recipient revocation');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('View')));
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('File')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.shared_expect('View',false);
reset role;
do $$begin
 assert exists(select 1 from public.shares where id=pg_temp.shared_id('View') and revoked_at is null);
 assert exists(select 1 from public.share_snapshots where share_id=pg_temp.shared_id('Comment'));
 assert exists(select 1 from public.audit_events where event_type='SHARE_CREATED' and entity_id=pg_temp.shared_id('Comment'));
 assert not has_function_privilege('anon','public.resolve_shared_entity_access(jsonb)','EXECUTE');
 assert not has_function_privilege('service_role','public.resolve_shared_entity_access(jsonb)','EXECUTE');
 assert has_function_privilege('authenticated','public.resolve_shared_entity_access(jsonb)','EXECUTE');
 assert exists(select 1 from pg_proc where oid='public.resolve_shared_entity_access(jsonb)'::regprocedure and prosecdef and proconfig=array['search_path=""']);
end$$;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('View')));
-- M13.7 audit is the existing durable M15 hook; no body or delivery subsystem.
reset role;
do $$declare label0 text;begin
 foreach label0 in array array['Master','MasterComment'] loop
  assert (select count(*) from public.audit_events where event_type='SHARE_CREATED' and entity_id=pg_temp.shared_id(label0) and metadata='{}'::jsonb)=1;
  assert exists(select 1 from public.share_snapshots where share_id=pg_temp.shared_id(label0) and source_version_id=pg_temp.shared_id('V2'));
  assert exists(select 1 from public.shares where id=pg_temp.shared_id(label0) and destination_type='MASTER' and destination_id=(select id from shared_master));
 end loop;
end$$;
select 'M13.7 AT-SHARE-001 exact-V2/VIEW-COMMENT/ownership/retry/audit/source-isolation PASS';
select 'M13.5 TEAM-MASTER/VIEW-COMMENT/frozen-only/dynamic-revocation/direct-ID/source-privacy/deferred PASS';
rollback;
