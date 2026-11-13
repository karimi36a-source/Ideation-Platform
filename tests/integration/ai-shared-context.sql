reset role;
create temporary table sc_ids(label text primary key,id uuid);grant select on sc_ids to authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into sc_ids select label0,(public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT',label0,null,false,false)->>'artifactId')::uuid from logged_projects cross join unnest(array['X','Y']) label0 where label='Team';
insert into sc_ids select 'YVersion',id from public.artifact_versions where artifact_id=(select id from sc_ids where label='Y');
insert into sc_ids select 'V2',(public.create_artifact_version((select id from sc_ids where label='X'),'{"notes":"FROZEN_ONLY","relationships":[{"notes":"NEVER_TRAVERSE"}],"linked_file_id":"00000000-0000-4000-8000-000000999999"}','Selected V2')->>'id')::uuid;
insert into sc_ids select permission0,(public.share_entity(pg_temp.share_request('ARTIFACT',(select id from sc_ids where label='X'),permission0=>permission0)||jsonb_build_object('sourceVersionId',(select id from sc_ids where label='V2')))->>'id')::uuid from unnest(array['VIEW','COMMENT']) permission0;
create temporary table sc_master as select ra.id,ra.ends_at,ra.status from public.role_assignments ra join public.roles r on r.id=ra.role_id where r.code='MASTER' and ra.user_id='00000000-0000-4000-8000-000000006002' and ra.cohort_id=(select id from acceptance_cohorts where label='Test');
insert into sc_ids select 'MASTER',(public.share_entity(pg_temp.share_request('ARTIFACT',(select id from sc_ids where label='X'),'MASTER',(select id from sc_master))||jsonb_build_object('sourceVersionId',(select id from sc_ids where label='V2')))->>'id')::uuid;
insert into sc_ids select 'SNAPSHOT',id from public.share_snapshots where share_id=(select id from sc_ids where label='VIEW');
insert into sc_ids select 'V3',(public.create_artifact_version((select id from sc_ids where label='X'),'{"notes":"NEWER_PRIVATE_STATE"}','Private V3')->>'id')::uuid;
create function pg_temp.sc_request(share0 text default 'VIEW',version0 text default 'V2') returns jsonb language sql as $$select pg_temp.builder_request('BuilderRecipient','ARTIFACT_VERSION',(select id from sc_ids where label=version0),'CURRENT_ARTIFACT',(select id from sc_ids where label=share0))$$;
create temporary table sc_original as select (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v) versions,(select jsonb_agg(to_jsonb(m) order by id) from public.team_memberships m) memberships;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
set local role authenticated;
do $$declare r jsonb;permission0 text;begin
 foreach permission0 in array array['VIEW','COMMENT'] loop
  r:=public.resolve_ai_context_source(pg_temp.sc_request(permission0));
  assert r is not null and r::text like '%FROZEN_ONLY%' and r::text not like '%NEWER_PRIVATE_STATE%';
  assert r->>'entity_id'=(select id::text from sc_ids where label='V2');
  assert r->'permission_scope'='{"access":"SHARE_SNAPSHOT"}';
  assert (public.resolve_shared_entity_access(jsonb_build_object('shareId',(select id from sc_ids where label=permission0)))->>'canEdit')='false';
 end loop;
 assert public.resolve_ai_context_source(pg_temp.sc_request('VIEW','V3')) is null;
 assert public.resolve_ai_context_source(pg_temp.sc_request('VIEW','YVersion')) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','EVIDENCE',pg_temp.research_source('Evidence'),'EVIDENCE',(select id from sc_ids where label='VIEW'))) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT',(select id from sc_ids where label='VIEW'))) is null;
 assert public.resolve_ai_context_source(pg_temp.sc_request('SNAPSHOT')) is null;
 assert not exists(select 1 from public.artifacts where id in (select id from sc_ids where label in ('X','Y')));
 assert not exists(select 1 from public.workspaces where id=(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'));
 perform pg_temp.builder_bad(pg_temp.sc_request()||'{"included_snapshot_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}','22023');
 perform pg_temp.builder_bad(pg_temp.sc_request()||'{"entityType":"FILE"}','22023');
end$$;
reset role;
-- Preserve exact historical Snapshot provenance without creating source access.
with created as (insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type) select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'CRITICAL_REVIEWER','CRITICAL_REVIEW','Selected frozen context','Historical unverified interpretation','ANALYSIS' from logged_projects where label='BuilderRecipient' returning id) insert into sc_ids select 'OUTPUT',id from created;
insert into public.ai_context_references(ai_output_id,entity_type,entity_id,context_role,included_snapshot_hash,permission_scope,share_snapshot_id)
select (select id from sc_ids where label='OUTPUT'),'ARTIFACT_VERSION',(r->>'entity_id')::uuid,'CURRENT_ARTIFACT',r->>'included_snapshot_hash',r->'permission_scope',(r->>'share_snapshot_id')::uuid from (select public.resolve_ai_context_source(pg_temp.sc_request()) r) source0;
create temporary table sc_history as select to_jsonb(r) body from public.ai_context_references r where ai_output_id=(select id from sc_ids where label='OUTPUT');
-- Exact scoped assignment expires dynamically; role-only actors never qualify.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
set local role authenticated;
do $$begin assert public.resolve_ai_context_share((select id from sc_ids where label='MASTER')) is not null;end$$;
reset role;
update public.role_assignments set ends_at=statement_timestamp()-interval '1 second' where id=(select id from sc_master);
do $$begin assert public.resolve_ai_context_share((select id from sc_ids where label='MASTER')) is null;end$$;
update public.role_assignments r set ends_at=m.ends_at,status='inactive' from sc_master m where r.id=m.id;
do $$begin assert public.resolve_ai_context_share((select id from sc_ids where label='MASTER')) is null;end$$;
update public.role_assignments r set ends_at=m.ends_at,status=m.status from sc_master m where r.id=m.id;
do $$declare n integer;begin
 foreach n in array array[6001,6003,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  assert public.resolve_ai_context_share((select id from sc_ids where label='VIEW')) is null;
  assert public.resolve_ai_context_share((select id from sc_ids where label='MASTER')) is null;
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.revoke_share(jsonb_build_object('shareId',(select id from sc_ids where label='VIEW')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
set local role authenticated;
do $$begin
 assert public.resolve_ai_context_source(pg_temp.sc_request()) is null;
 assert public.resolve_ai_context_share((select id from sc_ids where label='VIEW')) is null;
 assert public.resolve_ai_context_source(pg_temp.sc_request('SNAPSHOT')) is null;
 assert exists(select 1 from public.ai_context_references where ai_output_id=(select id from sc_ids where label='OUTPUT'));
 assert public.resolve_ai_context_source(pg_temp.sc_request('COMMENT')) is not null;
end$$;
reset role;
do $$begin
 assert (select body from sc_history)=(select to_jsonb(r) from public.ai_context_references r where ai_output_id=(select id from sc_ids where label='OUTPUT'));
 assert exists(select 1 from public.share_snapshots where id=(select id from sc_ids where label='SNAPSHOT'));
 assert (select artifacts from sc_original)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select versions from sc_original)=(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v);
 assert (select memberships from sc_original)=(select jsonb_agg(to_jsonb(m) order by id) from public.team_memberships m);
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007','M14.18 destination removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$begin
 assert public.resolve_ai_context_share((select id from sc_ids where label='COMMENT')) is null;
 perform pg_temp.builder_bad(pg_temp.sc_request('COMMENT'));
end$$;
\echo M14.18 AT-AI-LEAK-003 exact-frozen-Artifact/VIEW-COMMENT/siblings/revocation/history/membership/MASTER-expiry/no-source-mutation PASS
rollback;
