-- Reuses the real Session 10 AI operation, reviewed Output and human-confirmed
-- Solution Candidate. This tail carries the same IDs through M12/M10/M8.
reset role;
create temporary table gov(label text primary key,data jsonb);
grant all on gov to authenticated,service_role;
create function pg_temp.gov_id(k text,field0 text default 'id') returns uuid language sql as $$select (data->>field0)::uuid from gov where label=k$$;
create temporary table gov_votes as select (select count(*) from public.votes) n;
create temporary table gov_ai as select to_jsonb(o)-'disposition'-'disposition_revision'-'disposition_changed_by'-'disposition_changed_at' body from public.ai_outputs o where id=(select (data#>>'{}')::uuid from s10 where label='gapOutput');
-- An independently human-authored source Artifact gets a real M8 V1 approval.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
insert into gov select 'artifact',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Human-governed bearing concept',(select (data->>'id')::uuid from s10 where label='activity'),true,true) from logged_projects where label='Team';
select public.update_artifact_draft(pg_temp.gov_id('artifact','initialVersionId'),0,'{"human_design":"Original bearing"}','Initial human design',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into gov values('submission1',public.submit_artifact(pg_temp.gov_id('artifact','artifactId'),pg_temp.gov_id('artifact','initialVersionId'),(select (data->>'id')::uuid from s10 where label='activity')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.gov_id('submission1'));
select public.approve_artifact(pg_temp.gov_id('submission1'));
reset role;
insert into gov select 'v1',to_jsonb(v) from public.artifact_versions v where id=pg_temp.gov_id('artifact','initialVersionId');
create function pg_temp.gov_old_current() returns void language plpgsql as $$begin
 assert (select current_version_id from public.artifacts where id=pg_temp.gov_id('artifact','artifactId'))=pg_temp.gov_id('v1');
 assert (select to_jsonb(v) from public.artifact_versions v where id=pg_temp.gov_id('v1'))=(select data from gov where label='v1');
 assert (select baselines from s10_before)=(select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b);
end$$;
-- Explicit human Evidence creation, not a conversion of AI prose to Evidence.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
insert into gov select 'evidence',public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'MEASUREMENT','Bench observation','Human observed bearing wear; repeat measurement needed','Human lab notebook run G1') from logged_projects where label='Team';
select public.link_evidence(jsonb_build_object('evidenceId',pg_temp.gov_id('evidence'),'entityType','GAP','entityId',pg_temp.research_source('Gap'),'relationshipType','RELATED_TO'));
select public.link_evidence(jsonb_build_object('evidenceId',pg_temp.gov_id('evidence'),'entityType','ARTIFACT','entityId',pg_temp.gov_id('artifact','artifactId'),'relationshipType','SUPPORTS'));
reset role;
select pg_temp.gov_old_current();
-- Team Lead makes a human DISCUSSION decision. No AI voter or participant.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
set local role authenticated;
insert into gov select 'decision',public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','Human bearing decision','question','Which bearing direction should be developed?','method','DISCUSSION','options','[{"label":"Investigate candidate"},{"label":"Keep original"}]'::jsonb)) from logged_projects where label='Team';
select public.finalize_decision(jsonb_build_object('decisionId',(select data#>>'{decision,id}' from gov where label='decision'),'selectedOptionId',(select data#>>'{options,0,id}' from gov where label='decision'),'outcome','Develop a testable bearing candidate','reasoning','Human evaluation of source uncertainty; no acceptance of AI as proof','linkedEvidenceIds',jsonb_build_array(pg_temp.gov_id('evidence')),'linkedArtifactIds',jsonb_build_array(pg_temp.gov_id('artifact','artifactId')),'linkedObjectIds',jsonb_build_array((select data->>'id' from s10 where label='candidate'))));
reset role;
select pg_temp.gov_old_current();
insert into gov select 'revisionRequest',jsonb_build_object('actorId','00000000-0000-4000-8000-000000006004','aiOutputId',o.id,'artifactId',pg_temp.gov_id('artifact','artifactId'),'expectedVersionId',pg_temp.gov_id('v1'),'expectedDraftRevision',null,'contentSnapshot',jsonb_build_object('human_design','Selected bearing direction; testing remains required','candidateId',(select data->>'id' from s10 where label='candidate'),'evidenceId',pg_temp.gov_id('evidence'),'decisionId',(select data#>>'{decision,id}' from gov where label='decision')),'changeSummary','Explicit human-selected AI-assisted revision','confirmed',true,'idempotencyKey',gen_random_uuid(),'sourceResponseHash',encode(sha256(convert_to(o.response_text,'UTF8')),'hex')) from public.ai_outputs o where id=(select (data#>>'{}')::uuid from s10 where label='gapOutput');
set local role service_role;
insert into gov select 'draft',public.apply_ai_artifact_revision(data) from gov where label='revisionRequest';
reset role;
select pg_temp.gov_old_current();
do $$begin
 assert (select data->>'status' from gov where label='draft')='DRAFT';
 assert (select data->>'version_number' from gov where label='draft')='2';
 assert (select (data->>'previous_version_id')::uuid from gov where label='draft')=pg_temp.gov_id('v1');
 assert (select data->>'created_by' from gov where label='draft')='00000000-0000-4000-8000-000000006004';
 assert (select verification_status='UNVERIFIED' and created_by='00000000-0000-4000-8000-000000006004' and source_name='Human lab notebook run G1' from public.evidence where id=pg_temp.gov_id('evidence'));
 assert exists(select 1 from public.evidence_links where evidence_id=pg_temp.gov_id('evidence') and linked_entity_type='DECISION' and linked_entity_id=(select (data#>>'{decision,id}')::uuid from gov where label='decision'));
 assert exists(select 1 from public.decision_links where decision_id=(select (data#>>'{decision,id}')::uuid from gov where label='decision') and linked_entity_type='DEVELOPMENT_OBJECT' and linked_entity_id=(select (data->>'id')::uuid from s10 where label='candidate'));
 assert (select count(*) from public.decision_participants where decision_id=(select (data#>>'{decision,id}')::uuid from gov where label='decision'))=1;
 assert exists(select 1 from public.decision_participants where decision_id=(select (data#>>'{decision,id}')::uuid from gov where label='decision') and role='FINALIZER' and user_id='00000000-0000-4000-8000-000000006005');
end$$;
-- Exact-ID privacy at Draft, submitted, under-review and CURRENT stages.
create function pg_temp.gov_team_b() returns void language plpgsql as $$begin
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
 execute 'set local role authenticated';
 assert not exists(select 1 from public.development_objects where id in(pg_temp.research_source('Gap'),(select (data->>'id')::uuid from s10 where label='candidate')));
 assert not exists(select 1 from public.ai_outputs where id=(select (data#>>'{}')::uuid from s10 where label='gapOutput'));
 assert not exists(select 1 from public.ai_context_references where ai_output_id=(select (data#>>'{}')::uuid from s10 where label='gapOutput'));
 assert not exists(select 1 from public.evidence where id=pg_temp.gov_id('evidence'));
 assert not exists(select 1 from public.decisions where id=(select (data#>>'{decision,id}')::uuid from gov where label='decision'));
 assert not exists(select 1 from public.artifacts where id=pg_temp.gov_id('artifact','artifactId'));
 assert not exists(select 1 from public.artifact_versions where artifact_id=pg_temp.gov_id('artifact','artifactId'));
 assert not exists(select 1 from public.submissions where artifact_id=pg_temp.gov_id('artifact','artifactId'));
 perform pg_temp.research_bad(format('select public.submit_artifact(%L::uuid,%L::uuid,%L::uuid)',pg_temp.gov_id('artifact','artifactId'),pg_temp.gov_id('draft'),(select data->>'id' from s10 where label='activity')));
 perform pg_temp.research_bad(format('update public.artifact_versions set status=''CURRENT'',approved_by=current_platform_user_id(),approved_at=now() where id=%L::uuid',pg_temp.gov_id('draft')));
 perform pg_temp.research_bad(format('update public.ai_outputs set response_text=''forged approval'' where id=%L::uuid',(select data#>>'{}' from s10 where label='gapOutput')));
 execute 'reset role';
end$$;
select pg_temp.gov_team_b();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
-- Neither the source author nor the trusted-server AI command may impersonate review.
select pg_temp.research_bad(format('select public.apply_ai_artifact_revision(%L::jsonb)',(select data from gov where label='revisionRequest')));
select pg_temp.research_bad(format('update public.artifact_versions set status=''CURRENT'' where id=%L::uuid',pg_temp.gov_id('draft')));
select pg_temp.research_bad(format('update public.artifacts set current_version_id=%L::uuid where id=%L::uuid',pg_temp.gov_id('draft'),pg_temp.gov_id('artifact','artifactId')));
select pg_temp.research_bad(format('update public.development_objects set status=''APPROVED'' where id=%L::uuid',(select data->>'id' from s10 where label='candidate')));
select pg_temp.research_bad(format('update public.evidence set verification_status=''VERIFIED'',verified_by=current_platform_user_id(),verified_at=now() where id=%L::uuid',pg_temp.gov_id('evidence')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into gov values('submission2',public.submit_artifact(pg_temp.gov_id('artifact','artifactId'),pg_temp.gov_id('draft'),(select (data->>'id')::uuid from s10 where label='activity')));
select pg_temp.research_bad(format('select public.approve_artifact(%L::uuid)',pg_temp.gov_id('submission2')));
reset role;
select pg_temp.gov_old_current();
select pg_temp.gov_team_b();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
set local role authenticated;
select pg_temp.research_bad(format('select public.start_review(%L::uuid)',pg_temp.gov_id('submission2')));
reset role;
-- Exact assigned canonical reviewer, not a role-only private-content grant.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
set local role authenticated;
select pg_temp.research_bad(format('select public.approve_artifact(%L::uuid)',pg_temp.gov_id('submission2')),'22023');
select public.start_review(pg_temp.gov_id('submission2'));
reset role;
select pg_temp.gov_old_current();
select pg_temp.gov_team_b();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
set local role authenticated;
insert into gov values('approved',public.approve_artifact(pg_temp.gov_id('submission2'),'Human review of evidence uncertainty and candidate design'));
select public.approve_artifact(pg_temp.gov_id('submission2'),'Human review of evidence uncertainty and candidate design');
reset role;
select pg_temp.gov_team_b();
do $$declare sid uuid:=pg_temp.gov_id('submission2');begin
 assert (select current_version_id from public.artifacts where id=pg_temp.gov_id('artifact','artifactId'))=pg_temp.gov_id('draft');
 assert (select status='CURRENT' and approved_by='00000000-0000-4000-8000-000000006002' and approved_at is not null from public.artifact_versions where id=pg_temp.gov_id('draft'));
 assert (select status='SUPERSEDED' from public.artifact_versions where id=pg_temp.gov_id('v1'));
 assert (select to_jsonb(v)-'status' from public.artifact_versions v where id=pg_temp.gov_id('v1'))=(select data-'status' from gov where label='v1');
 assert (select count(*) from public.artifact_versions where artifact_id=pg_temp.gov_id('artifact','artifactId'))=2;
 assert exists(select 1 from public.submissions where id=sid and submitted_by='00000000-0000-4000-8000-000000006005' and reviewer_user_id='00000000-0000-4000-8000-000000006002');
 assert (select count(*) from public.review_actions where submission_id=sid and action_type='STARTED_REVIEW' and reviewer_user_id='00000000-0000-4000-8000-000000006002')=1;
 assert (select count(*) from public.review_actions where submission_id=sid and action_type='APPROVED' and reviewer_user_id='00000000-0000-4000-8000-000000006002')=1;
 assert (select count(*) from public.audit_events where event_type='ARTIFACT_APPROVED' and entity_id=sid and actor_user_id='00000000-0000-4000-8000-000000006002' and metadata='{}')=1;
 assert (select count(*) from public.audit_events where event_type='AI_ARTIFACT_DRAFT_APPLIED' and entity_id=pg_temp.gov_id('artifact','artifactId') and actor_user_id='00000000-0000-4000-8000-000000006004' and metadata->>'aiOutputId'=(select data#>>'{}' from s10 where label='gapOutput'))=1;
 assert exists(select 1 from public.change_log where entity_id=(select (data#>>'{decision,id}')::uuid from gov where label='decision') and change_type='DECISION_FINALIZED' and changed_by='00000000-0000-4000-8000-000000006005');
 assert (select baselines from s10_before)=(select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b);
 assert (select count(*) from public.votes)=(select n from gov_votes);
 assert exists(select 1 from public.change_log where change_type='AI_OUTPUT_DISPOSITION_CHANGED' and entity_id=(select (data#>>'{}')::uuid from s10 where label='gapOutput') and changed_by='00000000-0000-4000-8000-000000006004');
 assert exists(select 1 from public.change_log where entity_id=(select (data->>'id')::uuid from s10 where label='candidate') and change_type='OBJECT_CREATED' and related_ai_output_id=(select (data#>>'{}')::uuid from s10 where label='gapOutput') and changed_by='00000000-0000-4000-8000-000000006004' and reason::jsonb->>'human_confirmed_by'='00000000-0000-4000-8000-000000006004');
 assert (select origin_reference_id from public.development_objects where id=(select (data->>'id')::uuid from s10 where label='candidate'))=(select (data#>>'{}')::uuid from s10 where label='gapOutput');
 assert (select body from gov_ai)=(select to_jsonb(o)-'disposition'-'disposition_revision'-'disposition_changed_by'-'disposition_changed_at' from public.ai_outputs o where id=(select (data#>>'{}')::uuid from s10 where label='gapOutput'));
 assert (select verification_status='UNVERIFIED' from public.evidence where id=pg_temp.gov_id('evidence'));
end$$;
\echo AT-E2E-AI-001 AI/human/candidate/Evidence/Decision/Draft/review/CURRENT/history/privacy PASS
rollback;
