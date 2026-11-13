reset role;
create temporary table builder_ids(label text primary key,id uuid);
grant select on builder_ids to authenticated;
create temporary table builder_rows(payload jsonb);
grant select,insert on builder_rows to authenticated;
create function pg_temp.builder_request(project0 text,kind0 text,id0 uuid,role0 text,share0 uuid default null,activity0 uuid default null) returns jsonb language sql as $$
 select jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','entityType',kind0,'entityId',id0,'contextRole',role0,'shareId',share0,'activityInstanceId',activity0) from logged_projects where label=project0;
$$;
create function pg_temp.builder_bad(request jsonb,code0 text default '42501') returns void language plpgsql as $$begin
 perform public.resolve_ai_context_source(request);raise exception 'Builder boundary bypass';exception when others then if sqlstate<>code0 then raise;end if;end$$;
create temporary table builder_before as select (select count(*) from public.ai_outputs) outputs,(select count(*) from public.ai_usage_events) usage,(select count(*) from public.ai_context_references) refs;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$declare r jsonb;q jsonb;begin
 r:=public.resolve_ai_context_source(pg_temp.builder_request('Team','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT'));
 insert into builder_rows values(r);
 assert r->'content'->>'title'='Original source';
 assert not (r->'content' ?| array['why_retained','created_by','workspace_id','source_url','metadata']);
 assert r->>'included_snapshot_hash'=(select encode(sha256(convert_to(to_jsonb(p)::text,'UTF8')),'hex') from public.patent_records p where p.id=pg_temp.research_source('Patent')),'Canonical hash mismatch';
 assert r->'permission_scope'='{"access":"SOURCE"}', 'Unexpected permission projection';assert r->'share_snapshot_id'='null'::jsonb,'Unexpected Snapshot binding';
 assert public.resolve_ai_context_source(pg_temp.builder_request('Individual','PATENT_RECORD',pg_temp.research_source('PersonalPatent'),'PATENT')) is not null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('Team','EVIDENCE',pg_temp.research_source('Evidence'),'EVIDENCE')) is not null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('Team','DEVELOPMENT_OBJECT',pg_temp.research_source('Gap'),'GAP')) is not null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('Team','ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'CURRENT_ARTIFACT')) is not null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('Team','ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'PRIOR_APPROVED_OUTPUT')) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('Team','ACTIVITY_INSTANCE',pg_temp.research_context('Session9'),'COURSE_CONTEXT',null,pg_temp.research_context('Session9'))) is not null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('Team','ACTIVITY_INSTANCE',pg_temp.research_context('Session8'),'COURSE_CONTEXT',null,pg_temp.research_context('Session9'))) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('Team','PATENT_RECORD',pg_temp.research_source('PersonalPatent'),'PATENT')) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('Individual','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT')) is null;
 perform pg_temp.builder_bad(pg_temp.builder_request('Team','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT')||jsonb_build_object('workspaceId',(select payload->>'primary_workspace_id' from logged_projects where label='Individual')));
 perform pg_temp.builder_bad(pg_temp.builder_request('Team','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT')||'{"entityType":"BRAINSTORM_ENTRY"}','22023');
 perform pg_temp.builder_bad(pg_temp.builder_request('Team','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT')||'{"entityType":"CHAT_MESSAGE"}','22023');
 perform pg_temp.builder_bad(pg_temp.builder_request('Team','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT')||'{"entityType":"FILE"}','22023');
 foreach q in array array['{"userId":"spoof"}'::jsonb,'{"hash":"spoof"}','{"snapshotId":"spoof"}','{"storageReference":"spoof"}','{"permission_scope":{"access":"SOURCE"}}'] loop
  perform pg_temp.builder_bad(pg_temp.builder_request('Team','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT')||q,'22023');
 end loop;
end$$;
reset role;
-- Reuse M8 formal review to prove both approved Version and Feedback reads;
-- no instructor-only child can bypass the original target RLS.
insert into builder_ids select 'Submission',(public.submit_artifact((f.payload->>'artifactId')::uuid,(f.payload->>'initialVersionId')::uuid,i.id)->>'id')::uuid from submitted_fixtures f cross join instances i where f.label='Personal' and i.label='Individual';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select id from builder_ids where label='Submission'));
insert into builder_ids select 'Feedback',(public.add_feedback('ARTIFACT',(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,'COMMENT','Authorized feedback fixture')->>'id')::uuid from submitted_fixtures where label='Personal';
select public.approve_artifact((select id from builder_ids where label='Submission'),'Approved source fixture');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin
 assert public.resolve_ai_context_source(pg_temp.builder_request('Individual','ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),'PRIOR_APPROVED_OUTPUT')) is not null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('Individual','FEEDBACK_ITEM',(select id from builder_ids where label='Feedback'),'INSTRUCTOR_FEEDBACK')) is not null;
end$$;
reset role;
-- Canonical M13 creation, not a fabricated recipient grant.
insert into builder_ids select 'Share',(public.share_entity(pg_temp.share_request('PATENT_RECORD',pg_temp.research_source('Patent')))->>'id')::uuid;
insert into builder_ids select 'ArtifactShare',(public.share_entity(pg_temp.share_request('ARTIFACT',(payload->>'artifactId')::uuid)||jsonb_build_object('sourceVersionId',payload->>'initialVersionId'))->>'id')::uuid from submitted_fixtures where label='Team';
insert into builder_ids select 'Snapshot',id from public.share_snapshots where share_id=(select id from builder_ids where label='Share');
insert into builder_ids select 'ArtifactSnapshot',id from public.share_snapshots where share_id=(select id from builder_ids where label='ArtifactShare');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
set local role authenticated;
insert into logged_projects select 'BuilderRecipient',public.create_development_project('Builder recipient','team',(payload->>'workspaceId')::uuid,null,null,(payload->>'teamId')::uuid) from acceptance_teams where label='B';
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006007' from logged_projects where label='BuilderRecipient';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
set local role authenticated;
do $$declare r jsonb;begin
 r:=public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT',(select id from builder_ids where label='Share')));
 assert r->>'share_snapshot_id'=(select id::text from builder_ids where label='Snapshot');
 assert r->'permission_scope'='{"access":"SHARE_SNAPSHOT"}';
 insert into builder_rows values(r);
 assert r->'content'->>'title'='Original source';
 assert not (r->'content' ? 'why_retained');
 assert r->>'included_snapshot_hash'=encode(sha256(convert_to((public.resolve_shared_entity_access(jsonb_build_object('shareId',(select id from builder_ids where label='Share')))->'snapshotContent')::text,'UTF8')),'hex');
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT')) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','PATENT_RECORD',pg_temp.research_source('PersonalPatent'),'PATENT',(select id from builder_ids where label='Share'))) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','EVIDENCE',pg_temp.research_source('Evidence'),'EVIDENCE',(select id from builder_ids where label='Share'))) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT',(select id from builder_ids where label='Snapshot'))) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'CURRENT_ARTIFACT',(select id from builder_ids where label='ArtifactShare'))) is not null;
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent'));
 assert not exists(select 1 from public.artifact_versions where artifact_id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'));
 assert not exists(select 1 from public.files where workspace_id=(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'));
end$$;
reset role;
-- New source version does not move the frozen recipient representation.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into builder_ids select 'LaterVersion',(public.create_artifact_version((payload->>'artifactId')::uuid,'{"notes":"Later private state"}','Later')->>'id')::uuid from submitted_fixtures where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
set local role authenticated;
do $$begin
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','ARTIFACT_VERSION',(select id from builder_ids where label='LaterVersion'),'CURRENT_ARTIFACT',(select id from builder_ids where label='ArtifactShare'))) is null;
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'CURRENT_ARTIFACT',(select id from builder_ids where label='ArtifactShare'))) is not null;
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.revoke_share(jsonb_build_object('shareId',(select id from builder_ids where label='Share')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
set local role authenticated;
do $$begin
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT',(select id from builder_ids where label='Share'))) is null;
 assert public.resolve_ai_context_share((select id from builder_ids where label='Share')) is null;
end$$;
reset role;
-- Role/ID knowledge and earlier participation are not source authority.
do $$declare u text;begin
 foreach u in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',u,true);execute 'set local role authenticated';
  perform pg_temp.builder_bad(pg_temp.builder_request('Team','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT'));
  perform pg_temp.builder_bad(pg_temp.builder_request('Individual','PATENT_RECORD',pg_temp.research_source('PersonalPatent'),'PATENT'));
  if u='00000000-0000-4000-8000-000000006006' then
   -- Team B is a valid explicit Share destination. Membership authorizes only
   -- the selected Snapshot; the direct source/Personal requests above fail.
   assert public.resolve_ai_context_share((select id from builder_ids where label='ArtifactShare')) is not null;
  else
   assert public.resolve_ai_context_share((select id from builder_ids where label='ArtifactShare')) is null;
  end if;
  execute 'reset role';
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007','M14.8 destination removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
set local role authenticated;
select pg_temp.builder_bad(pg_temp.builder_request('BuilderRecipient','ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'CURRENT_ARTIFACT',(select id from builder_ids where label='ArtifactShare')));
do $$begin assert public.resolve_ai_context_share((select id from builder_ids where label='ArtifactShare')) is null;end$$;
reset role;
-- M14.20 independent Share authority survives source-Team removal only.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006004','member');
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006004' from logged_projects where label='BuilderRecipient';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.8 source removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
select pg_temp.builder_bad(pg_temp.builder_request('Team','PATENT_RECORD',pg_temp.research_source('Patent'),'PATENT'));
select pg_temp.builder_bad(pg_temp.builder_request('Team','EVIDENCE',pg_temp.research_source('Evidence'),'EVIDENCE'));
select pg_temp.builder_bad(pg_temp.builder_request('Team','DEVELOPMENT_OBJECT',pg_temp.research_source('Gap'),'GAP'));
select pg_temp.builder_bad(pg_temp.builder_request('Team','ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'CURRENT_ARTIFACT'));
select pg_temp.builder_bad(pg_temp.builder_request('Team','ACTIVITY_INSTANCE',pg_temp.research_context('Session9'),'COURSE_CONTEXT',null,pg_temp.research_context('Session9')));
do $$begin
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'CURRENT_ARTIFACT',(select id from builder_ids where label='ArtifactShare'))) is not null,'Independent destination Share lost';
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','ARTIFACT_VERSION',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'CURRENT_ARTIFACT')) is null,'Share expanded source authority';
 assert public.resolve_ai_context_source(pg_temp.builder_request('BuilderRecipient','ARTIFACT_VERSION',(select id from builder_ids where label='LaterVersion'),'CURRENT_ARTIFACT',(select id from builder_ids where label='ArtifactShare'))) is null,'Share expanded sibling authority';
end$$;

do $$begin
 assert public.resolve_ai_context_source(pg_temp.builder_request('Individual','PATENT_RECORD',pg_temp.research_source('PersonalPatent'),'PATENT')) is not null;
end$$;
reset role;
do $$begin
 assert not has_function_privilege('anon','public.resolve_ai_context_source(jsonb)','EXECUTE');
 assert not has_function_privilege('service_role','public.resolve_ai_context_source(jsonb)','EXECUTE');
 assert (select count(*) from public.ai_outputs)=(select outputs from builder_before);
 assert (select count(*) from public.ai_usage_events)=(select usage from builder_before);
 assert (select count(*) from public.ai_context_references)=(select refs from builder_before);
 assert exists(select 1 from public.share_snapshots where id=(select id from builder_ids where label='Snapshot'));
end$$;
select 'AI_BUILDER_ROW='||payload::text from builder_rows;
select 'M14.8 AT-AI-002/003/004 LEAK-001/002/003 current-scope/exact-Snapshot/revocation/removal/role-only/Personal/Team/IDs/no-provider/no-output/no-usage PASS';
rollback;




