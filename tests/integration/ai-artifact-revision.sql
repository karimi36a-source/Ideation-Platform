reset role;
create temporary table ar_artifacts(label text primary key,id uuid,v1 uuid,original jsonb);
create function pg_temp.ar_fixture(label0 text,scope0 text,kind0 public.artifact_type default 'DEVELOPED_CONCEPT') returns uuid language plpgsql as $$
declare a uuid:=gen_random_uuid();v uuid:=gen_random_uuid();p public.development_projects;begin
 select * into p from public.development_projects where id=(select (payload->>'id')::uuid from logged_projects where label=scope0);
 insert into public.artifacts(id,project_id,workspace_id,artifact_type,title,created_by,review_required,approval_required) values(a,p.id,p.primary_workspace_id,kind0,'Disposable revision target','00000000-0000-4000-8000-000000006004',true,true);
 if kind0='PATENT_READING_FRAMEWORK' then
  insert into public.artifact_versions(id,artifact_id,version_number,content_snapshot,status,created_by) values(v,a,1,'{}','DRAFT','00000000-0000-4000-8000-000000006004');
 else
  insert into public.artifact_versions(id,artifact_id,version_number,content_snapshot,change_summary,status,created_by,approved_by,approved_at,approval_note) values(v,a,1,'{"original":"approved"}','Original approval','CURRENT','00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006001',clock_timestamp(),'Preserved approval');
  update public.artifacts set current_version_id=v where id=a;
 end if;
 insert into ar_artifacts select label0,a,v,to_jsonb(x) from public.artifact_versions x where id=v;return a;
end$$;
select pg_temp.ar_fixture('Team','Team'),pg_temp.ar_fixture('Personal','Individual'),pg_temp.ar_fixture('Rollback','Team'),pg_temp.ar_fixture('Race','Team'),pg_temp.ar_fixture('Submitted','Team');
insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by,previous_version_id) select id,2,'{"submitted":"preserve"}','SUBMITTED','00000000-0000-4000-8000-000000006004',v1 from ar_artifacts where label='Submitted';
create temporary table ar_submitted as select to_jsonb(v) original,v.id from public.artifact_versions v join ar_artifacts a on a.id=v.artifact_id where a.label='Submitted' and v.version_number=2;
grant select on ar_submitted to service_role;
select pg_temp.ar_fixture(kind0,'Team',kind0::public.artifact_type) from unnest(array['MIND_MAP','INVENTION_STRUCTURE','GAP_LIST','MINIMUM_ESSENTIAL_STRUCTURE','INVENTION_CONCEPT','PROBLEM_BANK','SOLUTION_BANK','TEAM_DECISION_RECORD','PATENT_READING_FRAMEWORK']) kind0;
create function pg_temp.ar_request(label0 text,source0 text default 'Team') returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','aiOutputId',s.id,'artifactId',a.id,'expectedVersionId',a.v1,'expectedDraftRevision',null,'contentSnapshot',jsonb_build_object('human_confirmed','Revised '||label0),'changeSummary','Human-confirmed change','confirmed',true,'idempotencyKey',a.id,'sourceResponseHash',encode(sha256(convert_to(o.response_text,'UTF8')),'hex')) from ar_artifacts a cross join cv_sources s join public.ai_outputs o on o.id=s.id where a.label=label0 and s.label=source0
$$;
-- Real VIEW/COMMENT recipients can resolve the selected frozen representation,
-- but neither grant authorizes source editing or AI source access.
create temporary table ar_shares(permission0 text,id uuid);grant select on ar_shares to authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into ar_shares select permission0,(public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',a.id,'sourceVersionId',a.v1,'destinationType','TEAM','destinationId',(select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'permissionLevel',permission0,'shareMode','SNAPSHOT'))->>'id')::uuid from ar_artifacts a cross join unnest(array['VIEW','COMMENT']) permission0 where a.label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
set local role authenticated;
do $$declare s record;r jsonb;begin
 for s in select * from ar_shares loop
  r:=public.resolve_shared_entity_access(jsonb_build_object('shareId',s.id));
  assert (r->>'allowed')::boolean and not (r->>'canEdit')::boolean;
 end loop;
 assert not exists(select 1 from public.artifact_versions where artifact_id=(pg_temp.ar_request('Team')->>'artifactId')::uuid);
 perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Team')),'42501');
 perform pg_temp.research_bad(format('update public.artifact_versions set content_snapshot=''{}'' where id=%L::uuid',pg_temp.ar_request('Team')->>'expectedVersionId'),'42501');
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- REVISION TESTS
create temporary table ar_before as select (select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p) projects,(select jsonb_agg(to_jsonb(s) order by id) from public.ai_outputs s) ai,(select jsonb_agg(to_jsonb(n) order by id) from public.mind_map_nodes n) nodes,(select jsonb_agg(to_jsonb(e) order by id) from public.mind_map_edges e) edges,(select jsonb_agg(to_jsonb(s) order by id) from public.submissions s) submissions,(select jsonb_agg(to_jsonb(f) order by id) from public.feedback_items f) feedback,(select count(*) from public.evidence) evidence_count,(select count(*) from public.decisions) decision_count,(select count(*) from public.shares) share_count;
create temporary table ar_results(label text primary key,body jsonb);grant all on ar_results to service_role;
set local role service_role;
insert into ar_results values('Team',public.apply_ai_artifact_revision(pg_temp.ar_request('Team')));
insert into ar_results values('Retry',public.apply_ai_artifact_revision(pg_temp.ar_request('Team')));
insert into ar_results values('Personal',public.apply_ai_artifact_revision(pg_temp.ar_request('Personal','Personal')));
insert into ar_results values('Submitted',public.apply_ai_artifact_revision(pg_temp.ar_request('Submitted')||jsonb_build_object('expectedVersionId',(select id from ar_submitted))));
do $$begin
 perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Team')||'{"contentSnapshot":{"conflict":true}}'),'23505');
 perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Personal')),'42501');
 perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Rollback')||'{"confirmed":false}'),'22023');
 perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Rollback','Legacy')),'22000');
end$$;
reset role;
do $$declare t text;before0 bigint;begin
 assert (select body from ar_results where label='Team')=(select body from ar_results where label='Retry');
 assert (select body->>'status' from ar_results where label='Team')='DRAFT';
 assert (select body->>'version_number' from ar_results where label='Team')='2';
 assert (select (body->>'previous_version_id')::uuid from ar_results where label='Team')=(select v1 from ar_artifacts where label='Team');
 assert (select body->>'version_number' from ar_results where label='Submitted')='3';
 assert (select (body->>'previous_version_id')::uuid from ar_results where label='Submitted')=(select id from ar_submitted);
 assert (select body->>'status' from ar_results where label='Submitted')='DRAFT';
 for t in select label from ar_artifacts where label not in ('Team','Personal','Rollback','Race','Submitted') loop
  select count(*) into before0 from public.artifact_versions;
  perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request(t)),'0A000');
  assert (select count(*) from public.artifact_versions)=before0;
  assert not exists(select 1 from public.audit_events where event_type='AI_ARTIFACT_DRAFT_APPLIED' and entity_id=(select id from ar_artifacts where label=t));
 end loop;
end$$;
-- A new explicit command safely reuses the current editable Draft with CAS.
insert into ar_results select 'Reuse',public.apply_ai_artifact_revision(pg_temp.ar_request('Team')||jsonb_build_object('idempotencyKey',gen_random_uuid(),'expectedVersionId',body->>'id','expectedDraftRevision',0,'contentSnapshot','{"human_confirmed":"Second explicit edit"}'::jsonb)) from ar_results where label='Team';
do $$begin
 assert (select body->>'id' from ar_results where label='Reuse')=(select body->>'id' from ar_results where label='Team');
 assert (select body->>'draft_revision' from ar_results where label='Reuse')='1';
 perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Team')||jsonb_build_object('idempotencyKey',gen_random_uuid(),'expectedVersionId',(select body->>'id' from ar_results where label='Team'),'expectedDraftRevision',0)),'23505');
end$$;
-- Retries do not overwrite later human editing.
do $$declare r jsonb;begin r:=public.apply_ai_artifact_revision(pg_temp.ar_request('Team'));assert r->'content_snapshot'='{"human_confirmed":"Second explicit edit"}'::jsonb;end$$;
create function pg_temp.ar_fail() returns trigger language plpgsql as $$begin raise exception 'Required-step failure' using errcode='23514';end$$;
do $$declare t text;n bigint;begin
 for t in select unnest(array['artifact_versions','audit_events']) loop
  select count(*) into n from public.artifact_versions;
  execute format('create trigger ar_forced before insert on public.%I for each row execute function pg_temp.ar_fail()',t);
  perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Rollback')),'23514');
  execute format('drop trigger ar_forced on public.%I',t);
  assert (select count(*) from public.artifact_versions)=n;
  assert not exists(select 1 from public.audit_events where event_type='AI_ARTIFACT_DRAFT_APPLIED' and entity_id=(select id from ar_artifacts where label='Rollback'));
 end loop;
end$$;
-- Trusted server path still rechecks canonical source and target authority.
do $$declare n integer;begin
 foreach n in array array[6001,6002,6003,6006,6007,6008] loop
  perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Rollback')||jsonb_build_object('actorId',('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid)),'42501');
  perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Personal','Personal')||jsonb_build_object('actorId',('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid)),'42501');
 end loop;
 perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Personal','Personal')||'{"actorId":"00000000-0000-4000-8000-000000006005"}'),'42501');
end$$;
set local role authenticated;
do $$begin
 perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Rollback')),'42501');
 perform pg_temp.research_bad('insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id) select current_platform_user_id(),''AI_ARTIFACT_DRAFT_APPLIED'',''artifact'',gen_random_uuid(),''artifact'',gen_random_uuid()','42501');
end$$;
reset role;
-- Current edit access never derives from a historical creator or exact ID.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.16 disposable removal');
do $$begin perform pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',pg_temp.ar_request('Rollback')),'42501');end$$;
do $$begin
 assert not exists(select 1 from ar_artifacts a join public.artifact_versions v on v.id=a.v1 where a.original<>to_jsonb(v));
 assert (select original from ar_submitted)=(select to_jsonb(v) from public.artifact_versions v where id=(select id from ar_submitted));
 assert not exists(select 1 from ar_artifacts a join public.artifacts x on x.id=a.id where x.current_version_id<>a.v1);
 assert (select projects from ar_before) is not distinct from (select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p);
 assert (select ai from ar_before) is not distinct from (select jsonb_agg(to_jsonb(s) order by id) from public.ai_outputs s);
 assert (select nodes from ar_before) is not distinct from (select jsonb_agg(to_jsonb(n) order by id) from public.mind_map_nodes n);
 assert (select edges from ar_before) is not distinct from (select jsonb_agg(to_jsonb(e) order by id) from public.mind_map_edges e);
 assert (select submissions from ar_before) is not distinct from (select jsonb_agg(to_jsonb(s) order by id) from public.submissions s);
 assert (select feedback from ar_before) is not distinct from (select jsonb_agg(to_jsonb(f) order by id) from public.feedback_items f);
 assert (select evidence_count from ar_before)=(select count(*) from public.evidence);
 assert (select decision_count from ar_before)=(select count(*) from public.decisions);
 assert (select share_count from ar_before)=(select count(*) from public.shares);
 assert (select count(*) from public.audit_events where event_type='AI_ARTIFACT_DRAFT_APPLIED')=4;
 assert not has_function_privilege('authenticated','public.apply_ai_artifact_revision(jsonb)','execute');
end$$;
\echo M14.16 AT-AI-007 generic-Draft/specialized-denial/approved-history/provenance/CAS/rollback/privacy PASS
rollback;
