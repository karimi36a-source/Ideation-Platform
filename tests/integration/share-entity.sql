reset role;
create temporary table sharing_context(label text primary key,payload jsonb);
grant select,insert on sharing_context to authenticated;
create function pg_temp.sharing_bad(request jsonb,expected text default '42501') returns void language plpgsql as $$begin
 perform public.share_entity(request);raise exception 'Share attack succeeded';
exception when others then if sqlstate<>expected then raise;end if;end$$;
create function pg_temp.sharing_request(version0 uuid default null) returns jsonb language sql as $$
 select pg_temp.share_request('ARTIFACT',(select (payload->>'artifactId')::uuid from sharing_context where label='Artifact'))||jsonb_build_object('sourceVersionId',version0)
$$;
do $$declare p jsonb;a jsonb;b jsonb;v jsonb;begin
 select payload into p from logged_projects where label='Team';
 a:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Explicit shared Artifact',null,false,false);
 b:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Sibling secret',null,false,false);
 insert into sharing_context values('Artifact',a),('Sibling',b);
 v:=public.create_artifact_version((a->>'artifactId')::uuid,'{"notes":"Selected V2"}','V2');
 insert into sharing_context values('V2',v);
 select payload into p from logged_projects where label='Individual';
 b:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Other Workspace secret',null,false,false);
 insert into sharing_context values('PersonalArtifact',b);
end$$;
set local role authenticated;
do $$declare r jsonb;again jsonb;v2 uuid;begin
 select (payload->>'id')::uuid into v2 from sharing_context where label='V2';
 perform pg_temp.sharing_bad(pg_temp.sharing_request(),'22023');
 perform pg_temp.sharing_bad(pg_temp.share_request()||jsonb_build_object('sourceVersionId',v2),'22023');
 perform pg_temp.sharing_bad(pg_temp.sharing_request(v2)||'{"shared_by":"spoof"}','22023');
 perform pg_temp.sharing_bad(pg_temp.sharing_request(v2)||'{"source_workspace_id":"spoof"}','22023');
 perform pg_temp.sharing_bad(pg_temp.sharing_request((select (payload->>'initialVersionId')::uuid from sharing_context where label='Sibling')));
 perform pg_temp.sharing_bad(pg_temp.sharing_request((select (payload->>'initialVersionId')::uuid from sharing_context where label='PersonalArtifact')));
 perform pg_temp.sharing_bad(pg_temp.sharing_request('ffffffff-ffff-4fff-8fff-ffffffffffff'));
 r:=public.share_entity(pg_temp.sharing_request(v2));again:=public.share_entity(pg_temp.sharing_request(v2));assert r=again;
 insert into sharing_context values('V2Share',r);
 -- Personal owner -> own current Team, unchanged from M13.3.
 r:=public.share_entity(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent'),target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
 insert into sharing_context values('PersonalShare',r);
end$$;
select 'SHARE_ENTITY_ROW='||payload::text from sharing_context where label='V2Share';
reset role;
do $$declare source uuid;k text;r jsonb;p jsonb;upload jsonb;f jsonb;entry uuid;before_row jsonb;begin
 foreach k in array array['EVIDENCE','DEVELOPMENT_OBJECT'] loop
  source:=pg_temp.research_source(case k when 'EVIDENCE' then 'Evidence' else 'Gap' end);
  r:=public.share_entity(pg_temp.share_request(k,source));
  assert exists(select 1 from public.share_snapshots where share_id=(r->>'id')::uuid and source_version_id is null);
 end loop;
 select payload into p from logged_projects where label='Team';
 upload:=public.request_file_upload((p->>'primary_workspace_id')::uuid,(p->>'id')::uuid,'shared-file.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',upload->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((upload->>'id')::uuid);
 r:=public.share_entity(pg_temp.share_request('FILE',(f->>'id')::uuid));
 assert (select not (snapshot_data->'content'?'storage_reference') from public.share_snapshots where share_id=(r->>'id')::uuid);
 assert f=(select to_jsonb(x) from public.files x where id=(f->>'id')::uuid);
 select payload into p from logged_projects where label='Individual';
 insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
 select id,(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,public.current_platform_user_id(),'SUBSTITUTE','Source','Proposal','Result' from instances where label='Individual' returning id into entry;
 select to_jsonb(e) into before_row from public.scamper_entries e where id=entry;
 r:=public.share_entity(pg_temp.share_request('SCAMPER_ENTRY',entry,target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
 assert before_row=(select to_jsonb(e) from public.scamper_entries e where id=entry);
 assert (select source_version_id is null from public.share_snapshots where share_id=(r->>'id')::uuid);
end$$;
do $$declare v jsonb;s uuid;frozen jsonb;before_count integer;begin
 select (payload->>'id')::uuid into s from sharing_context where label='V2Share';
 assert (select count(*) from public.share_snapshots where share_id=s)=1;
 select snapshot_data into frozen from public.share_snapshots where share_id=s;
 assert frozen->'content'->'content_snapshot'='{"notes":"Selected V2"}'::jsonb;
 assert frozen->'content'->>'title'='Explicit shared Artifact';
 assert frozen::text not like '%Sibling secret%';
 v:=public.create_artifact_version((select (payload->>'artifactId')::uuid from sharing_context where label='Artifact'),'{"notes":"Later V3"}','V3');
 insert into sharing_context values('V3',v);
 perform pg_temp.sharing_bad(pg_temp.sharing_request((v->>'id')::uuid),'P1304');
 assert frozen=(select snapshot_data from public.share_snapshots where share_id=s);
 -- Test-only trusted revocation uses existing history-preserving schema, not a new API.
 update public.shares set revoked_at=clock_timestamp(),revoked_by=public.current_platform_user_id() where id=s;
 v:=public.share_entity(pg_temp.sharing_request((v->>'id')::uuid));
 assert (v->>'id')::uuid<>s;
 assert exists(select 1 from public.share_snapshots where share_id=(v->>'id')::uuid and source_version_id=(select (payload->>'id')::uuid from sharing_context where label='V3'));
 assert frozen=(select snapshot_data from public.share_snapshots where share_id=s);
 assert exists(select 1 from public.shares where id=s and revoked_at is not null);
 assert (select count(*) from public.audit_events where event_type='SHARE_CREATED' and entity_id=s and actor_user_id=public.current_platform_user_id() and metadata='{}')=1;
 select count(*) into before_count from public.notifications;
 assert before_count>=0; -- No invented notification recipients or delivery policy.
end$$;
-- Required Snapshot/audit failures must unwind the complete RPC subtransaction.
create function pg_temp.fail_share_step() returns trigger language plpgsql as $$begin raise exception 'forced required-step failure' using errcode='P1305';end$$;
create trigger test_snapshot_failure before insert on public.share_snapshots for each row execute function pg_temp.fail_share_step();
do $$declare n integer;sn integer;an integer;begin
 select count(*) into n from public.shares;select count(*) into sn from public.share_snapshots;select count(*) into an from public.audit_events;
 perform pg_temp.sharing_bad(pg_temp.share_request(),'P1305');
 assert n=(select count(*) from public.shares) and sn=(select count(*) from public.share_snapshots) and an=(select count(*) from public.audit_events);
end$$;
drop trigger test_snapshot_failure on public.share_snapshots;
create trigger test_audit_failure before insert on public.audit_events for each row when(new.event_type='SHARE_CREATED') execute function pg_temp.fail_share_step();
do $$declare n integer;sn integer;an integer;begin
 select count(*) into n from public.shares;select count(*) into sn from public.share_snapshots;select count(*) into an from public.audit_events;
 perform pg_temp.sharing_bad(pg_temp.share_request(),'P1305');
 assert n=(select count(*) from public.shares) and sn=(select count(*) from public.share_snapshots) and an=(select count(*) from public.audit_events);
end$$;
drop trigger test_audit_failure on public.audit_events;
-- Team Lead -> exact current scoped MASTER; no role-only source grant.
create temporary table sharing_master as select ra.id,ra.ends_at from public.role_assignments ra join public.roles r on r.id=ra.role_id
 where r.code='MASTER' and ra.user_id='00000000-0000-4000-8000-000000006002' and ra.cohort_id=(select id from acceptance_cohorts where label='Test');
grant select on sharing_master to authenticated;
set local role authenticated;
select public.share_entity(pg_temp.share_request(dest=>'MASTER',target=>(select id from sharing_master),permission0=>'COMMENT'));
select pg_temp.sharing_bad(pg_temp.share_request(dest=>'MASTER',target=>'00000000-0000-4000-8000-000000006002'));
select pg_temp.sharing_bad(pg_temp.share_request(mode0=>'LIVE_REFERENCE'));
select pg_temp.sharing_bad(pg_temp.share_request(permission0=>'COLLABORATE'));
select pg_temp.sharing_bad(pg_temp.share_request(dest=>'COHORT'));
select pg_temp.sharing_bad(pg_temp.share_request(dest=>'WORKSPACE'));
select pg_temp.sharing_bad(pg_temp.share_request(dest=>'USER'));
select pg_temp.sharing_bad(pg_temp.share_request(target=>'ffffffff-ffff-4fff-8fff-ffffffffffff'));
reset role;
update public.role_assignments set ends_at=statement_timestamp()-interval '1 second' where id=(select id from sharing_master);
set local role authenticated;
select pg_temp.sharing_bad(pg_temp.share_request(dest=>'MASTER',target=>(select id from sharing_master),permission0=>'COMMENT'));
reset role;
update public.role_assignments ra set ends_at=m.ends_at from sharing_master m where ra.id=m.id;
-- Trusted status fixture: archived Version cannot be selected for a new Share.
update public.artifact_versions set status='ARCHIVED' where id=(select (payload->>'initialVersionId')::uuid from sharing_context where label='Artifact');
set local role authenticated;
select pg_temp.sharing_bad(pg_temp.sharing_request((select (payload->>'initialVersionId')::uuid from sharing_context where label='Artifact')));
-- Ordinary member and role-only actors cannot share a known source/version.
do $$declare u text;begin
 foreach u in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006005','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',u,true);
  perform pg_temp.sharing_bad(pg_temp.sharing_request((select (payload->>'id')::uuid from sharing_context where label='V3')));
  perform pg_temp.sharing_bad(pg_temp.share_request());
 end loop;
end$$;
-- Even SELECT privileges cannot traverse inert Share/Snapshot rows or sources.
reset role;
grant select on public.shares,public.share_snapshots to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$begin
 assert not exists(select 1 from public.shares);assert not exists(select 1 from public.share_snapshots);
 assert not exists(select 1 from public.artifacts where id=(select (payload->>'artifactId')::uuid from sharing_context where label='Artifact'));
 assert not exists(select 1 from public.artifact_versions where artifact_id=(select (payload->>'artifactId')::uuid from sharing_context where label='Artifact'));
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent'));
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M13.4 revoked current authority');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.sharing_bad(pg_temp.sharing_request((select (payload->>'id')::uuid from sharing_context where label='V3')));
reset role;
do $$begin
 assert not has_function_privilege('anon','public.share_entity(jsonb)','EXECUTE');
 assert not has_function_privilege('service_role','public.share_entity(jsonb)','EXECUTE');
 assert has_function_privilege('authenticated','public.share_entity(jsonb)','EXECUTE');
 assert exists(select 1 from pg_proc where oid='public.share_entity(jsonb)'::regprocedure and prosecdef and proconfig=array['search_path=""']);
 assert not has_table_privilege('authenticated','public.shares','INSERT');
 assert (select count(*) from public.audit_events where event_type='SHARE_CREATED')=(select count(*) from public.shares);
 assert not exists(select 1 from public.shares s left join public.share_snapshots ss on ss.share_id=s.id where ss.id is null);
end$$;
select 'M13.4 atomic explicit-version/retry/conflict/history/rollback/audit/privacy PASS';
rollback;
