-- M8.21: prepend activityArtifactFixture; one canonical Team lifecycle, rolled back.
reset role;
create temporary table cycle_context as select f.id upstream,c.project,c.workspace,c.team from resumed_fixture f join av_context c on c.label=f.label where f.label='Team';
create temporary table cycle_values(key text primary key,data jsonb);
grant select on cycle_context to authenticated,anon;
grant select,insert on cycle_values to authenticated,anon;
create function pg_temp.cid(k text,f text default 'id') returns uuid language sql as $$select (data->>f)::uuid from cycle_values where key=k$$;
create function pg_temp.reject_cycle(command text,code text default '42501') returns void language plpgsql as $$
declare actual text;begin begin execute command;exception when others then get stacked diagnostics actual=returned_sqlstate;if actual=code then return;end if;raise;end;raise exception 'Unexpected lifecycle attack success';end$$;
create function pg_temp.cycle_history() returns jsonb language sql as $$select jsonb_build_object(
 'version',(select to_jsonb(v) from public.artifact_versions v where id=pg_temp.cid('A','initialVersionId')),
 'submission',(select to_jsonb(s) from public.submissions s where id=pg_temp.cid('S1')),
 'feedback',(select jsonb_agg(to_jsonb(f) order by id) from public.feedback_items f where submission_id=pg_temp.cid('S1')),
 'actions',(select jsonb_agg(to_jsonb(r) order by id) from public.review_actions r where submission_id=pg_temp.cid('S1')),
 'links',(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l where artifact_version_id=pg_temp.cid('A','initialVersionId')))$$;
insert into cycle_values select 'ActivityBefore',to_jsonb(i) from public.activity_instances i where id=(select upstream from cycle_context);
insert into cycle_values select 'BaselineBefore',coalesce(jsonb_agg(to_jsonb(b) order by id),'[]') from public.project_baseline_items b;
insert into cycle_values select 'NotificationsBefore',coalesce(jsonb_agg(to_jsonb(n) order by id),'[]') from public.notifications n;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into cycle_values select 'O1',public.create_development_object(project,workspace,'PROBLEM','Cycle O1','Canonical first problem','User') from cycle_context;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into cycle_values select 'O2',public.create_development_object(project,workspace,'PROBLEM','Cycle O2','Canonical second problem','User') from cycle_context;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into cycle_values select 'A',public.create_artifact(project,workspace,'PROBLEM_BANK','Integrated revision cycle',upstream,true,true) from cycle_context;
do $$begin
 assert (select (a.status,a.project_id,a.workspace_id,a.activity_instance_id,a.current_version_id) from public.artifacts a where id=pg_temp.cid('A','artifactId'))=(select ('ACTIVE'::public.artifact_status,project,workspace,upstream,null::uuid) from cycle_context);
 assert (select status='DRAFT' and version_number=1 and previous_version_id is null and draft_revision=0 and created_by=auth.uid() and approved_by is null and approved_at is null and approval_note is null from public.artifact_versions where id=pg_temp.cid('A','initialVersionId'));
 assert (select public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000740803',project,workspace,team)->>'satisfied' from cycle_context)='false';
end$$;
reset role;
insert into cycle_values select 'ObjectsBefore',jsonb_agg(to_jsonb(o) order by id) from public.development_objects o;
-- Established M8.3 trusted composition fixture, not a new public editing API.
insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence)
 select pg_temp.cid('A','artifactId'),pg_temp.cid('A','initialVersionId'),pg_temp.cid(k),n from (values('O1',1),('O2',2)) x(k,n);
select pg_temp.reject_cycle(format('insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id) values(%L,%L,%L)',pg_temp.cid('A','artifactId'),pg_temp.cid('A','initialVersionId'),'00000000-0000-4000-8000-000000780802'),'23514');
set local role authenticated;
insert into cycle_values select 'V1Saved',public.update_artifact_draft(pg_temp.cid('A','initialVersionId'),0,'{"concept":"V1 explicit problem bank","objects":["O1","O2"]}','Initial working snapshot',true);
do $$begin assert (select data->>'draft_revision' from cycle_values where key='V1Saved')='1';assert (select current_version_id from public.artifacts where id=pg_temp.cid('A','artifactId')) is null;assert (select count(*) from public.artifact_object_links where artifact_version_id=pg_temp.cid('A','initialVersionId'))=2;end$$;
insert into cycle_values select 'Output',public.add_activity_artifact_output(upstream,pg_temp.cid('A','artifactId')) from cycle_context;
insert into cycle_values select 'S1',public.submit_artifact(pg_temp.cid('A','artifactId'),pg_temp.cid('A','initialVersionId'),upstream) from cycle_context;
do $$begin assert (select status='SUBMITTED' and artifact_id=pg_temp.cid('A','artifactId') and artifact_version_id=pg_temp.cid('A','initialVersionId') and activity_instance_id=(select upstream from cycle_context) and submitted_by=auth.uid() and reviewer_user_id='00000000-0000-4000-8000-000000006002' from public.submissions where id=pg_temp.cid('S1'));assert (select status='SUBMITTED' and draft_revision=1 from public.artifact_versions where id=pg_temp.cid('A','initialVersionId'));end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.cid('S1'));
insert into cycle_values select 'Comment',public.add_feedback('ARTIFACT',pg_temp.cid('A','artifactId'),pg_temp.cid('A','initialVersionId'),'COMMENT','Clarify the constraints');
do $$begin assert (select status='UNDER_REVIEW' from public.submissions where id=pg_temp.cid('S1'));assert (select status='UNDER_REVIEW' and draft_revision=1 from public.artifact_versions where id=pg_temp.cid('A','initialVersionId'));assert (select status='OPEN' and submission_id=pg_temp.cid('S1') and target_version_id=pg_temp.cid('A','initialVersionId') and author_user_id=auth.uid() from public.feedback_items where id=pg_temp.cid('Comment'));end$$;
select public.request_revision(pg_temp.cid('S1'),'Specify constraints before approval');
reset role;
do $$begin
 assert (select status='REVISION_REQUESTED' from public.submissions where id=pg_temp.cid('S1'));
 assert (select to_jsonb(v)-'status' from public.artifact_versions v where id=pg_temp.cid('A','initialVersionId'))=(select data-'status' from cycle_values where key='V1Saved');
 assert (select to_jsonb(f) from public.feedback_items f where id=pg_temp.cid('Comment'))=(select data from cycle_values where key='Comment');
 assert (select count(*) from public.feedback_items where submission_id=pg_temp.cid('S1') and feedback_type='REVISION_REQUEST' and status='OPEN')=1;
 assert (select count(*) from public.audit_events where event_type='REVISION_REQUESTED' and entity_id=pg_temp.cid('S1') and actor_user_id='00000000-0000-4000-8000-000000006002')=1;
end$$;
insert into cycle_values values('V1History',pg_temp.cycle_history());
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into cycle_values select 'V2',public.create_revision_draft(pg_temp.cid('S1'),'{"concept":"V2 revised constraints"}','Address the revision request');
do $$begin assert (select id<>pg_temp.cid('A','initialVersionId') and artifact_id=pg_temp.cid('A','artifactId') and version_number=2 and previous_version_id=pg_temp.cid('A','initialVersionId') and status='DRAFT' and draft_revision=0 and approved_by is null and approved_at is null and approval_note is null from public.artifact_versions where id=pg_temp.cid('V2'));end$$;
select public.update_artifact_draft(pg_temp.cid('V2'),0,'{"concept":"V2 edited constraints"}','Refine constraints',true);
insert into cycle_values select 'V2Winner',public.update_artifact_draft(pg_temp.cid('V2'),1,'{"concept":"V2 final winner"}','Ready for resubmission',true);
select pg_temp.reject_cycle(format('select public.update_artifact_draft(%L,1,%L,%L,true)',pg_temp.cid('V2'),'{"concept":"stale loser"}','Stale summary'),'23505');
do $$begin assert (select to_jsonb(v) from public.artifact_versions v where id=pg_temp.cid('V2'))=(select data from cycle_values where key='V2Winner');assert (select current_version_id from public.artifacts where id=pg_temp.cid('A','artifactId')) is null;end$$;
insert into cycle_values select 'S2',public.submit_artifact(pg_temp.cid('A','artifactId'),pg_temp.cid('V2'),upstream) from cycle_context;
do $$begin assert pg_temp.cid('S2')<>pg_temp.cid('S1');assert (select status='SUBMITTED' and artifact_version_id=pg_temp.cid('V2') and submitted_by=auth.uid() and reviewer_user_id='00000000-0000-4000-8000-000000006002' and activity_instance_id=(select upstream from cycle_context) from public.submissions where id=pg_temp.cid('S2'));end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.cid('S2'));
do $$begin assert (select status='UNDER_REVIEW' from public.submissions where id=pg_temp.cid('S2'));assert (select status='UNDER_REVIEW' and draft_revision=2 from public.artifact_versions where id=pg_temp.cid('V2'));end$$;
select public.approve_artifact(pg_temp.cid('S2'),'Constraints reviewed');
reset role;
do $$begin
 assert (select status='CURRENT' and approved_by='00000000-0000-4000-8000-000000006002' and approved_at is not null and approval_note='Constraints reviewed' and draft_revision=2 and previous_version_id=pg_temp.cid('A','initialVersionId') from public.artifact_versions where id=pg_temp.cid('V2'));
 assert (select status='ACTIVE' and current_version_id=pg_temp.cid('V2') from public.artifacts where id=pg_temp.cid('A','artifactId'));
 assert (select status='APPROVED' and artifact_version_id=pg_temp.cid('V2') from public.submissions where id=pg_temp.cid('S2'));
 assert (select data from cycle_values where key='V1History')=pg_temp.cycle_history();
 assert (select count(*) from public.review_actions where submission_id=pg_temp.cid('S1') and action_type='STARTED_REVIEW')=1;
 assert (select count(*) from public.review_actions where submission_id=pg_temp.cid('S1') and action_type='COMMENTED')=1;
 assert (select count(*) from public.review_actions where submission_id=pg_temp.cid('S1') and action_type='REQUESTED_REVISION')=1;
 assert (select count(*) from public.review_actions where submission_id=pg_temp.cid('S2') and action_type='STARTED_REVIEW')=1;
 assert (select count(*) from public.review_actions where submission_id=pg_temp.cid('S2') and action_type='APPROVED')=1;
 assert (select count(*) from public.review_actions where submission_id=pg_temp.cid('S1'))=3;
 assert (select count(*) from public.review_actions where submission_id=pg_temp.cid('S2'))=2;
 assert not exists(select 1 from public.feedback_items where submission_id=pg_temp.cid('S2'));
 assert not exists(select 1 from public.artifact_object_links where artifact_version_id=pg_temp.cid('V2'));
 assert (select count(*) from public.audit_events where event_type='ARTIFACT_APPROVED' and entity_id=pg_temp.cid('S2') and actor_user_id='00000000-0000-4000-8000-000000006002')=1;
 assert (select data from cycle_values where key='NotificationsBefore')=(select coalesce(jsonb_agg(to_jsonb(n) order by id),'[]') from public.notifications n),'Review notifications remain deferred; Team notifications are separate';
end$$;
\echo M8.21 Activity -> V1/link/edit/submit/review/feedback/revision -> V2/CAS/resubmit/review/CURRENT PASS
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert (select public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000740803',project,workspace,team)->>'satisfied' from cycle_context)='true';
 assert (select public.list_activity_artifact_candidates('00000000-0000-4000-8000-000000740803',project,workspace,team)->0->>'artifactVersionId' from cycle_context)=pg_temp.cid('V2')::text;
end$$;
insert into cycle_values select 'B',public.start_activity('00000000-0000-4000-8000-000000740803',project,workspace,team) from cycle_context;
insert into cycle_values select 'Input',public.add_activity_artifact_input((data->'activity'->>'id')::uuid,pg_temp.cid('A','artifactId'),pg_temp.cid('V2'),true) from cycle_values where key='B';
insert into cycle_values select 'VersionHistory',jsonb_agg(to_jsonb(v) order by version_number) from public.artifact_versions v where artifact_id=pg_temp.cid('A','artifactId');
do $$declare col text;begin
 assert (select data->0->>'status'='REVISION_REQUESTED' and data->1->>'status'='CURRENT' and jsonb_array_length(data)=2 from cycle_values where key='VersionHistory');
 assert (select artifact_id=pg_temp.cid('A','artifactId') and artifact_version_id=pg_temp.cid('V2') and development_object_id is null and evidence_id is null from public.activity_inputs where id=pg_temp.cid('Input'));
 foreach col in array array['content_snapshot','change_summary','draft_revision','status','previous_version_id','approved_by','approved_at','approval_note'] loop
  perform pg_temp.reject_cycle(format('update public.artifact_versions set %I=%s where id=%L',col,case col
   when 'content_snapshot' then quote_literal('{"tampered":true}')||'::jsonb'
   when 'change_summary' then quote_literal('Forged summary')
   when 'draft_revision' then '0'
   when 'status' then quote_literal('DRAFT')
   when 'previous_version_id' then 'gen_random_uuid()'
   when 'approved_by' then quote_literal('00000000-0000-4000-8000-000000006005')||'::uuid'
   when 'approved_at' then 'clock_timestamp()'
   else quote_literal('Forged approval note') end,pg_temp.cid('V2')));
 end loop;
 perform pg_temp.reject_cycle(format('select public.update_artifact_draft(%L,2,%L)',pg_temp.cid('V2'),'{}'),'55000');
 perform pg_temp.reject_cycle(format('update public.artifacts set current_version_id=%L where id=%L',pg_temp.cid('A','initialVersionId'),pg_temp.cid('A','artifactId')));
 perform pg_temp.reject_cycle(format('delete from public.artifact_versions where artifact_id=%L',pg_temp.cid('A','artifactId')));
 perform pg_temp.reject_cycle(format('delete from public.submissions where id=%L',pg_temp.cid('S1')));
 perform pg_temp.reject_cycle(format('delete from public.feedback_items where submission_id=%L',pg_temp.cid('S1')));
 perform pg_temp.reject_cycle(format('delete from public.review_actions where submission_id=%L',pg_temp.cid('S1')));
end$$;
-- Exact known IDs do not bypass Team B or removed-member privacy.
create function pg_temp.cycle_hidden() returns void language plpgsql as $$begin
 assert not exists(select 1 from public.artifacts where id=pg_temp.cid('A','artifactId'));
 assert not exists(select 1 from public.artifact_versions where artifact_id=pg_temp.cid('A','artifactId'));
 assert not exists(select 1 from public.submissions where id in (pg_temp.cid('S1'),pg_temp.cid('S2')));
 assert not exists(select 1 from public.feedback_items where submission_id=pg_temp.cid('S1'));
 assert not exists(select 1 from public.review_actions where submission_id in (pg_temp.cid('S1'),pg_temp.cid('S2')));
 assert not exists(select 1 from public.artifact_object_links where artifact_id=pg_temp.cid('A','artifactId'));
 assert not exists(select 1 from public.activity_inputs where id=pg_temp.cid('Input'));
 assert public.get_submitted_artifact_metadata(pg_temp.cid('A','artifactId')) is null;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);select pg_temp.cycle_hidden();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member(team,'00000000-0000-4000-8000-000000006004',null) from cycle_context;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select pg_temp.cycle_hidden();
reset role;
do $$begin
 assert (select data from cycle_values where key='V1History')=pg_temp.cycle_history();
 assert (select data from cycle_values where key='ObjectsBefore')=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
 assert (select data from cycle_values where key='ActivityBefore')=(select to_jsonb(i) from public.activity_instances i where id=(select upstream from cycle_context));
 assert (select data from cycle_values where key='BaselineBefore')=(select coalesce(jsonb_agg(to_jsonb(b) order by id),'[]') from public.project_baseline_items b);
 assert (select data from cycle_values where key='VersionHistory')=(select jsonb_agg(to_jsonb(v) order by version_number) from public.artifact_versions v where artifact_id=pg_temp.cid('A','artifactId'));
 assert (select to_jsonb(i) from public.activity_inputs i where id=pg_temp.cid('Input'))=(select data from cycle_values where key='Input');
 assert (select current_version_id from public.artifacts where id=pg_temp.cid('A','artifactId'))=pg_temp.cid('V2');
end$$;
select 'M821_ARTIFACT='||(select to_jsonb(a)::text from public.artifacts a where id=pg_temp.cid('A','artifactId'));
select 'M821_HISTORY='||(select data::text from cycle_values where key='VersionHistory');
\echo M8.21 approved-output exact V2 / immutable input / history / Team B + removed-member privacy / baseline + Activity preservation PASS
\echo M8.21 notifications DEFERRED TO M15; trusted M8.3 composition fixture only; no new policy
rollback;
