reset role;
create temporary table context_ids(label text primary key,id uuid);
grant select,insert on context_ids to authenticated;
create function pg_temp.ctx_bad(statement text,expected text default '42501') returns void language plpgsql as $$begin
 execute statement;raise exception 'Context boundary bypass';
exception when others then if sqlstate<>expected then raise;end if;end$$;
create function pg_temp.ctx_id(label0 text) returns uuid language sql as $$select id from context_ids where label=label0$$;
create function pg_temp.ctx_output(label0 text,project0 text) returns uuid language plpgsql as $$declare r uuid;begin
 insert into public.ai_outputs(project_id,workspace_id,activity_instance_id,ai_role,task_type,prompt_text,response_text,output_type)
 select (p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,
  case when project0='Team' then pg_temp.research_context('Session9') when project0='Individual' then (select id from instances where label='Individual') end,
  'CRITICAL_REVIEWER','CONTEXT_FIXTURE','Fixture only','Fixture output','ANALYSIS' from logged_projects p where p.label=project0 returning id into r;
 insert into context_ids values(label0,r);return r;
end$$;
create function pg_temp.ctx_ref(output0 uuid,kind0 public.ai_context_entity_type,source0 uuid,role0 public.ai_context_role,snapshot0 uuid default null) returns uuid language plpgsql as $$declare r uuid;begin
 insert into public.ai_context_references(ai_output_id,entity_type,entity_id,context_role,share_snapshot_id,permission_scope,included_snapshot_hash)
 values(output0,kind0,source0,role0,snapshot0,'{"access":"SOURCE"}','0') returning id into r;return r;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.ctx_output('TeamOutput','Team');
select pg_temp.ctx_output('PersonalOutput','Individual');
select pg_temp.ctx_ref(pg_temp.ctx_id('TeamOutput'),'PROJECT',(select (payload->>'id')::uuid from logged_projects where label='Team'),'CURRENT_PROJECT');
select pg_temp.ctx_ref(pg_temp.ctx_id('TeamOutput'),'ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'CURRENT_ARTIFACT');
select pg_temp.ctx_ref(pg_temp.ctx_id('TeamOutput'),'DEVELOPMENT_OBJECT',pg_temp.research_source('Gap'),'GAP');
select pg_temp.ctx_ref(pg_temp.ctx_id('TeamOutput'),'EVIDENCE',pg_temp.research_source('Evidence'),'EVIDENCE');
select pg_temp.ctx_ref(pg_temp.ctx_id('TeamOutput'),'PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT');
select pg_temp.ctx_ref(pg_temp.ctx_id('TeamOutput'),'ACTIVITY_INSTANCE',pg_temp.research_context('Session9'),'COURSE_CONTEXT');
select pg_temp.ctx_ref(pg_temp.ctx_id('PersonalOutput'),'PATENT_RECORD',pg_temp.research_source('PersonalPatent'),'PATENT');
insert into context_ids select 'Decision',(public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','Human decision','question','Which approach?','method','DISCUSSION','options','[{"label":"One"},{"label":"Two"}]'::jsonb))->'decision'->>'id')::uuid from logged_projects where label='Team';
select pg_temp.ctx_ref(pg_temp.ctx_id('TeamOutput'),'DECISION',pg_temp.ctx_id('Decision'),'TEAM_DECISION');
-- Real formal review provenance, not a fabricated feedback row.
insert into context_ids select 'Submission',(public.submit_artifact((f.payload->>'artifactId')::uuid,(f.payload->>'initialVersionId')::uuid,i.id)->>'id')::uuid from submitted_fixtures f cross join instances i where f.label='Personal' and i.label='Individual';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.ctx_id('Submission'));
insert into context_ids select 'Feedback',(public.add_feedback('ARTIFACT',(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,'COMMENT','Human instructor feedback')->>'id')::uuid from submitted_fixtures where label='Personal';
select public.approve_artifact(pg_temp.ctx_id('Submission'),'Approved canonical fixture');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.ctx_ref(pg_temp.ctx_id('PersonalOutput'),'FEEDBACK_ITEM',pg_temp.ctx_id('Feedback'),'INSTRUCTOR_FEEDBACK');
select pg_temp.ctx_ref(pg_temp.ctx_id('PersonalOutput'),'ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),'PRIOR_APPROVED_OUTPUT');
-- Successful capture inside an RPC-style subtransaction must stay atomic.
do $$declare r uuid;begin
 begin
  r:=pg_temp.ctx_output('NestedOutput','Individual');
  perform pg_temp.ctx_ref(r,'PATENT_RECORD',pg_temp.research_source('PersonalPatent'),'PATENT');
  raise exception 'Rollback test-only nested output' using errcode='P1420';
 exception when sqlstate 'P1420' then null;
 end;
 assert pg_temp.ctx_id('NestedOutput') is null;
end$$;
do $$declare q text;r record;col text;begin
 assert (select count(distinct context_role) from public.ai_context_references)=9;
 assert not exists(select 1 from public.ai_context_references where included_snapshot_hash !~ '^[a-f0-9]{64}$' or permission_scope<>'{"access":"SOURCE"}');
 perform pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''EVIDENCE'',%L,''PATENT'')',pg_temp.ctx_id('TeamOutput'),pg_temp.research_source('Evidence')),'23514');
 perform pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''PATENT_RECORD'',%L,''PATENT'')',pg_temp.ctx_id('PersonalOutput'),pg_temp.research_source('Patent')));
 perform pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''PATENT_RECORD'',%L,''PATENT'')',pg_temp.ctx_id('TeamOutput'),pg_temp.research_source('ForeignPatent')));
 perform pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''EVIDENCE'',''ffffffff-ffff-4fff-8fff-ffffffffffff'',''EVIDENCE'')',pg_temp.ctx_id('TeamOutput')));
 perform pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''ARTIFACT_VERSION'',%L,''PRIOR_APPROVED_OUTPUT'')',pg_temp.ctx_id('TeamOutput'),(select payload->>'initialVersionId' from submitted_fixtures where label='Team')));
 perform pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''ACTIVITY_INSTANCE'',%L,''COURSE_CONTEXT'')',pg_temp.ctx_id('TeamOutput'),pg_temp.research_context('Session8')));
 perform pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''FILE'',''ffffffff-ffff-4fff-8fff-ffffffffffff'',''EVIDENCE'')',pg_temp.ctx_id('TeamOutput')),'22P02');
 for r in select id from public.ai_context_references loop
  foreach col in array array['id','ai_output_id','entity_type','entity_id','context_role','included_snapshot_hash','permission_scope','share_snapshot_id'] loop
   perform pg_temp.ctx_bad(format('update public.ai_context_references set %I=%I where id=%L',col,col,r.id),'55000');
  end loop;
 end loop;
 perform pg_temp.ctx_bad('delete from public.ai_context_references','55000');
end$$;
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_context_references)=10;
 perform pg_temp.ctx_bad('insert into public.ai_context_references default values');
 perform pg_temp.ctx_bad('update public.ai_context_references set permission_scope=''{}''');
 perform pg_temp.ctx_bad('delete from public.ai_context_references');
end$$;
reset role;
-- Team A source shared to B; recipient stores only authorized frozen provenance
-- under its own Team B output. No direct source or implicit File grant exists.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into context_ids select 'Share',(public.share_entity(pg_temp.share_request('PATENT_RECORD',pg_temp.research_source('Patent')))->>'id')::uuid;
insert into context_ids select 'Snapshot',id from public.share_snapshots where share_id=pg_temp.ctx_id('Share');
insert into context_ids select 'ArtifactShare',(public.share_entity(pg_temp.share_request('ARTIFACT',(payload->>'artifactId')::uuid)||jsonb_build_object('sourceVersionId',payload->>'initialVersionId'))->>'id')::uuid from submitted_fixtures where label='Team';
insert into context_ids select 'ArtifactSnapshot',id from public.share_snapshots where share_id=pg_temp.ctx_id('ArtifactShare');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
set local role authenticated;
insert into logged_projects select 'Recipient',public.create_development_project('Recipient context','team',(payload->>'workspaceId')::uuid,null,null,(payload->>'teamId')::uuid) from acceptance_teams where label='B';
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006007' from logged_projects where label='Recipient';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
select pg_temp.ctx_output('RecipientOutput','Recipient');
insert into context_ids select 'HistoricalReference',pg_temp.ctx_ref(pg_temp.ctx_id('RecipientOutput'),'PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT',pg_temp.ctx_id('Snapshot'));
insert into context_ids select 'ArtifactReference',pg_temp.ctx_ref(pg_temp.ctx_id('RecipientOutput'),'ARTIFACT_VERSION',(payload->>'initialVersionId')::uuid,'CURRENT_ARTIFACT',pg_temp.ctx_id('ArtifactSnapshot')) from submitted_fixtures where label='Team';
create temporary table context_before as select * from public.ai_context_references;
grant select on context_before to authenticated;
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_context_references)=2;
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent'));
 assert not exists(select 1 from public.ai_context_references c join public.patent_records p on c.entity_id=p.id);
 assert not exists(select 1 from public.ai_context_references c join public.artifact_versions v on c.entity_id=v.id);
 assert not exists(select 1 from public.files where workspace_id=(select payload->>'primary_workspace_id' from logged_projects where label='Team')::uuid);
end$$;
reset role;
select pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''PATENT_RECORD'',%L,''PATENT'')',pg_temp.ctx_id('RecipientOutput'),pg_temp.research_source('Patent')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into context_ids select 'LaterVersion',(public.create_artifact_version((payload->>'artifactId')::uuid,'{"notes":"Later canonical content"}','Later version')->>'id')::uuid from submitted_fixtures where label='Team';
select public.revoke_share(jsonb_build_object('shareId',pg_temp.ctx_id('Share')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
select pg_temp.ctx_output('AfterRevoke','Recipient');
select pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''PATENT_RECORD'',%L,''PATENT'',%L)',pg_temp.ctx_id('AfterRevoke'),pg_temp.research_source('Patent'),pg_temp.ctx_id('Snapshot')));
select pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''PATENT_RECORD'',%L,''PATENT'',%L)',pg_temp.ctx_id('RecipientOutput'),pg_temp.research_source('Patent'),pg_temp.ctx_id('Snapshot')));
select pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''ARTIFACT_VERSION'',%L,''CURRENT_ARTIFACT'',%L)',pg_temp.ctx_id('RecipientOutput'),pg_temp.ctx_id('LaterVersion'),pg_temp.ctx_id('ArtifactSnapshot')));
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_context_references)=2;
 assert exists(select 1 from public.ai_context_references where id=pg_temp.ctx_id('HistoricalReference') and permission_scope='{"access":"SHARE_SNAPSHOT"}');
 assert (public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.ctx_id('Share')))->>'allowed')='false';
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent'));
 perform pg_temp.ctx_bad('select * from public.share_snapshots');
end$$;
reset role;
-- Role-only/exact-ID requests cannot see the parent or traverse its references.
do $$declare u text;begin
 foreach u in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',u,true);
  execute 'set local role authenticated';
  assert not exists(select 1 from public.ai_context_references);
  execute 'reset role';
  perform pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''PATENT_RECORD'',%L,''PATENT'')',pg_temp.ctx_id('TeamOutput'),pg_temp.research_source('Patent')));
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007','M14.2 removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
select pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''ARTIFACT_VERSION'',%L,''CURRENT_ARTIFACT'',%L)',pg_temp.ctx_id('RecipientOutput'),(select payload->>'initialVersionId' from submitted_fixtures where label='Team'),pg_temp.ctx_id('ArtifactSnapshot')));
set local role authenticated;
do $$begin assert not exists(select 1 from public.ai_context_references);end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.2 source removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_context_references)=3;
 assert not exists(select 1 from public.ai_context_references where ai_output_id=pg_temp.ctx_id('TeamOutput'));
end$$;
reset role;
do $$begin
 assert not exists((select * from context_before) except (select * from public.ai_context_references));
 assert (select count(*) from public.ai_context_references)=12;
 assert not has_table_privilege('anon','public.ai_context_references','SELECT');
 assert not has_table_privilege('authenticated','public.ai_context_references','INSERT,UPDATE,DELETE');
end$$;
select 'AI_CONTEXT_ROW='||to_jsonb(c)::text from public.ai_context_references c where id=pg_temp.ctx_id('HistoricalReference');
select 'M14.2 AT-AI-005 canonical-role-mapping/request-authority/exact-version/snapshot/hash/revocation/history/Personal/Team/removal/role-only/ID/joins/immutable/default-deny PASS';
rollback;
