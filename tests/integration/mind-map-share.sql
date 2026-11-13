-- Trusted normalized fixture; real canonical Artifact/Share/Comment/Revoke RPCs.
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table map_share_context(label text primary key,payload jsonb);
grant select on map_share_context to authenticated;
create function pg_temp.map_share_id(label0 text) returns uuid language sql as $$select (payload->>'id')::uuid from map_share_context where label=$1$$;
do $$declare p jsonb;a jsonb;v jsonb;b jsonb;m uuid:=gen_random_uuid();r uuid:=gen_random_uuid();n uuid:=gen_random_uuid();e uuid:=gen_random_uuid();s jsonb;u jsonb;f jsonb;begin
 select payload into p from logged_projects where label='Team';
 u:=public.request_file_upload((p->>'primary_workspace_id')::uuid,(p->>'id')::uuid,'Map linked private file.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',u->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((u->>'id')::uuid);
 insert into map_share_context values('File',f);
 a:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'MIND_MAP','Team authored frozen map',null,false,false);
 b:=jsonb_build_object('workspaceId',p->>'primary_workspace_id','projectId',p->>'id','activityInstanceId',(select id from instances where label='Team'),
  'rootNodeId',r,'mindMapId',m,'sources',jsonb_build_array(jsonb_build_object('private_source',pg_temp.research_source('Patent'))),
  'nodes',jsonb_build_array(jsonb_build_object('id',r,'nodeType','CENTRAL_INVENTION','label','Our invention','parentNodeId',null,'positionData',jsonb_build_object('x',0,'y',0),'createdBy',public.current_platform_user_id()),
   jsonb_build_object('id',n,'nodeType','COMPONENT','label','Team chosen component','parentNodeId',r,'developmentObjectId',pg_temp.research_source('Gap'),'productClassification','SUPPORTING',
    'positionData',jsonb_build_object('x',120,'y',80,'private_path','PRIVATE_MAP_CANARY'),
    'metadata',jsonb_build_object('fileId',pg_temp.map_share_id('File'),'storageReference',f->>'storage_reference','evidenceId',pg_temp.research_source('Evidence'),'patentRecordId',pg_temp.research_source('Patent'),'secret','PRIVATE_MAP_CANARY'))),
  'edges',jsonb_build_array(jsonb_build_object('id',e,'sourceNodeId',r,'targetNodeId',n,'edgeType','HIERARCHY','label','Team connection','metadata',jsonb_build_object('private','PRIVATE_MAP_CANARY'))));
 v:=public.create_artifact_version((a->>'artifactId')::uuid,b,'Selected V2');
 insert into public.mind_maps(id,artifact_id,artifact_version_id) values(m,(a->>'artifactId')::uuid,(v->>'id')::uuid);
 insert into public.mind_map_nodes(id,mind_map_id,node_type,label,parent_node_id,position_data,created_by) values(r,m,'CENTRAL_INVENTION','Our invention',null,'{"x":0,"y":0}',public.current_platform_user_id()),(n,m,'COMPONENT','Team chosen component',r,'{"x":120,"y":80}',public.current_platform_user_id());
 update public.mind_maps set root_node_id=r where id=m;
 insert into public.mind_map_edges(id,mind_map_id,source_node_id,target_node_id,edge_type,label) values(e,m,r,n,'HIERARCHY','Team connection');
 insert into public.file_links(file_id,entity_type,entity_id,relationship_type,created_by) values(pg_temp.map_share_id('File'),'ARTIFACT',(a->>'artifactId')::uuid,'ARTIFACT_FILE',public.current_platform_user_id());
 insert into map_share_context values('Artifact',jsonb_build_object('id',a->>'artifactId')),('V1',jsonb_build_object('id',a->>'initialVersionId')),('V2',v),('Map',jsonb_build_object('id',m)),('Node',jsonb_build_object('id',n)),('Edge',jsonb_build_object('id',e)),('Source',b);
 s:=public.share_entity(pg_temp.share_request('ARTIFACT',(a->>'artifactId')::uuid)||jsonb_build_object('sourceVersionId',v->>'id'));
 insert into map_share_context values('View',s);
 s:=public.share_entity(pg_temp.share_request('ARTIFACT',(a->>'artifactId')::uuid,permission0=>'COMMENT')||jsonb_build_object('sourceVersionId',v->>'id'));
 insert into map_share_context values('Comment',s);
end$$;
-- Simulate one pre-M13.17 frozen row; resolver must redact without rewriting it.
do $$begin
 assert (select snapshot_data::text not like '%PRIVATE_MAP_CANARY%' from public.share_snapshots where share_id=pg_temp.map_share_id('Comment'));
end$$;
alter table public.share_snapshots disable trigger share_snapshots_frozen;
update public.share_snapshots set snapshot_data=jsonb_set(snapshot_data,'{content,content_snapshot}',(select payload from map_share_context where label='Source')) where share_id=pg_temp.map_share_id('View');
alter table public.share_snapshots enable trigger share_snapshots_frozen;
insert into map_share_context select 'LegacyStored',to_jsonb(s) from public.share_snapshots s where share_id=pg_temp.map_share_id('View');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$declare r jsonb;c jsonb;begin
 r:=public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.map_share_id('View')));c:=r->'snapshotContent'->'content_snapshot';
 assert (r->>'allowed')::boolean and not (r->>'canEdit')::boolean and not (r->>'canComment')::boolean;
 assert r->>'sourceVersionId'=pg_temp.map_share_id('V2')::text;
 assert jsonb_array_length(c->'nodes')=2 and jsonb_array_length(c->'edges')=1;
 assert c->'nodes'->1->>'label'='Team chosen component';
 assert r::text not like '%PRIVATE_MAP_CANARY%', 'Private node/position/edge metadata leaked';
 assert r::text not like '%storageReference%' and r::text not like '%workspaces/%';
 assert c->'nodes'->1->'positionData'='{"x":120,"y":80}'::jsonb;
 assert c->'nodes'->1->>'productClassification'='SUPPORTING';
 assert not c?'workspaceId' and not c?'projectId' and not c?'sources' and not c?'activityInstanceId' and not c?'mindMapId';
 assert not (c->'nodes'->1)?'developmentObjectId' and not (c->'nodes'->0)?'createdBy';
 assert public.authorize_shared_file_access(pg_temp.map_share_id('File'))=false;
 c:=public.add_share_comment(jsonb_build_object('shareId',pg_temp.map_share_id('Comment'),'content','Frozen map discussion'));
 assert c->>'target_version_id'=pg_temp.map_share_id('V2')::text;
 begin perform public.add_share_comment(jsonb_build_object('shareId',pg_temp.map_share_id('View'),'content','Forbidden'));raise exception 'VIEW comment succeeded';exception when insufficient_privilege then null;end;
end$$;
-- Exact identifiers and references confer no source read or mutation authority.
do $$declare t text;sql0 text;count0 bigint;filter0 text;begin
 foreach t in array array['artifacts','artifact_versions','mind_maps','mind_map_nodes','mind_map_edges','development_objects','evidence','patent_records','patent_search_logs','files','file_links'] loop
  filter0:=case when t='artifact_versions' then 'artifact_id='||quote_literal(pg_temp.map_share_id('Artifact'))
   when t='mind_maps' then 'id='||quote_literal(pg_temp.map_share_id('Map'))
   when t in('mind_map_nodes','mind_map_edges') then 'mind_map_id='||quote_literal(pg_temp.map_share_id('Map'))
   when t='file_links' then 'file_id='||quote_literal(pg_temp.map_share_id('File'))
   else 'workspace_id='||quote_literal((select payload->>'primary_workspace_id' from logged_projects where label='Team')) end;
  begin execute format('select count(*) from public.%I where %s',t,filter0) into count0;assert count0=0,'Source collection readable: '||t;exception when insufficient_privilege then null;end;
 end loop;
 foreach sql0 in array array['update public.mind_map_nodes set label=''Stolen'' where id='''||pg_temp.map_share_id('Node')||'''','delete from public.mind_map_edges where id='''||pg_temp.map_share_id('Edge')||''''] loop
  begin execute sql0;get diagnostics count0=row_count;assert count0=0;exception when insufficient_privilege then null;end;
 end loop;
 begin perform public.save_mind_map_draft(jsonb_build_object('mindMapId',pg_temp.map_share_id('Map'),'expectedDraftRevision',0));raise exception 'Recipient saved source';exception when insufficient_privilege then null;end;
 begin perform public.update_mind_map_node(jsonb_build_object('nodeId',pg_temp.map_share_id('Node'),'expectedRevision',0,'label','Stolen'));raise exception 'Recipient edited source';exception when insufficient_privilege then null;end;
 begin perform public.update_mind_map_node(jsonb_build_object('nodeId',pg_temp.map_share_id('Node'),'expectedRevision',0,'positionData',jsonb_build_object('x',999,'y',999)));raise exception 'Recipient changed layout';exception when insufficient_privilege then null;end;
 begin perform public.add_mind_map_node(jsonb_build_object('mindMapId',pg_temp.map_share_id('Map'),'nodeType','COMPONENT','label','Unauthorized node','positionData',jsonb_build_object('x',1,'y',1)));raise exception 'Recipient added node';exception when insufficient_privilege then null;end;
 begin perform public.update_mind_map_edge(jsonb_build_object('edgeId',pg_temp.map_share_id('Edge'),'expectedRevision',0,'label','Unauthorized edge'));raise exception 'Recipient edited edge';exception when insufficient_privilege then null;end;
 begin perform public.remove_mind_map_edge(jsonb_build_object('edgeId',pg_temp.map_share_id('Edge'),'expectedRevision',0));raise exception 'Recipient removed edge';exception when insufficient_privilege then null;end;
 begin perform public.get_mind_map_editor((select id from instances where label='Team'));raise exception 'Share granted source editor/collaboration context';exception when insufficient_privilege then null;end;
 begin perform public.share_entity(pg_temp.share_request('ARTIFACT',pg_temp.map_share_id('Artifact'))||jsonb_build_object('sourceVersionId',pg_temp.map_share_id('V2')));raise exception 'Recipient re-shared';exception when insufficient_privilege then null;end;
end$$;
reset role;
do $$declare u uuid;begin
 foreach u in array array['00000000-0000-4000-8000-000000006001'::uuid,'00000000-0000-4000-8000-000000006003'::uuid,'00000000-0000-4000-8000-000000006008'::uuid,'00000000-0000-4000-8000-000000006007'::uuid] loop
  perform set_config('request.jwt.claim.sub',u::text,true);perform pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.map_share_id('View')));
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 begin perform public.share_entity(pg_temp.share_request('ARTIFACT',pg_temp.map_share_id('Artifact'))||jsonb_build_object('sourceVersionId',pg_temp.map_share_id('V2')));raise exception 'Ordinary member shared';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 begin perform public.share_entity(pg_temp.share_request('ARTIFACT',pg_temp.map_share_id('Artifact'),target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='C'))||jsonb_build_object('sourceVersionId',pg_temp.map_share_id('V2')));raise exception 'Cross-Cohort shared';exception when insufficient_privilege then null;end;
end$$;
-- Freeze compares the entire recipient projection before and after newer source content.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
insert into map_share_context select 'Frozen',public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.map_share_id('View')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into map_share_context select 'V3',public.create_artifact_version(pg_temp.map_share_id('Artifact'),'{"nodes":[],"edges":[],"notes":"Private newer map"}','V3');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin assert public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.map_share_id('View')))=(select payload from map_share_context where label='Frozen');end$$;
-- Revocation and removal preserve frozen history, and deny future access/comments.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.revoke_share(jsonb_build_object('shareId',pg_temp.map_share_id('Comment')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.map_share_id('Comment')));
do $$begin begin perform public.add_share_comment(jsonb_build_object('shareId',pg_temp.map_share_id('Comment'),'content','Revoked'));raise exception 'Revoked comment succeeded';exception when insufficient_privilege then null;end;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006','M13.17 recipient removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.map_share_id('View')));
reset role;
do $$begin
 assert exists(select 1 from public.share_snapshots where share_id=pg_temp.map_share_id('Comment') and source_version_id=pg_temp.map_share_id('V2'));
 assert (select content_snapshot from public.artifact_versions where id=pg_temp.map_share_id('V2'))=(select payload from map_share_context where label='Source');
 assert (select label from public.mind_map_nodes where id=pg_temp.map_share_id('Node'))='Team chosen component';
 assert (select to_jsonb(s) from public.share_snapshots s where share_id=pg_temp.map_share_id('View'))=(select payload from map_share_context where label='LegacyStored');
end$$;
-- A scoped MASTER receives only its own explicit map Share and loses it on expiry.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into map_share_context select 'Master',public.share_entity(pg_temp.share_request('ARTIFACT',pg_temp.map_share_id('Artifact'),dest=>'MASTER',target=>(select id from shared_master))||jsonb_build_object('sourceVersionId',pg_temp.map_share_id('V2')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert (public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.map_share_id('Master')))->>'allowed')::boolean;end$$;
update public.role_assignments set ends_at=clock_timestamp()-interval '1 second' where id=(select id from shared_master);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.map_share_id('Master')));
update public.role_assignments set ends_at=null,status='inactive' where id=(select id from shared_master);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.map_share_id('Master')));
update public.role_assignments set ends_at=null,status='active' where id=(select id from shared_master);
-- Source scope remains private even when a frozen map is shared.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin
 assert public.get_team_workspace_access((select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team')) is null;
 assert public.team_workspace_has_chat_access((select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'))=false;
end$$;
reset role;
select 'M13.17 AT-SHARE-002 frozen-map/minimal-projection/references/File/VIEW-COMMENT/RLS/revocation/history PASS';
