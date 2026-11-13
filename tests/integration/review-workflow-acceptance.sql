-- M8.16: prepend artifactReviewSecurityFixture. Canonical Team A / IA / PA /
-- WA / Artifact A fixture; Lead A1=6005, member A2=6004, Primary Master=6002.
-- Every command below uses real PostgreSQL authenticated roles and existing RPCs.
create temporary table review_acceptance(key text primary key,data jsonb);
grant select,insert on review_acceptance to authenticated,anon;
insert into review_acceptance select 'A',payload from submitted_fixtures where label='Team';
-- M8.20: persist a nonzero counter through submission/review/revision history.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare vid uuid;body jsonb;begin
 select (data->>'initialVersionId')::uuid into vid from review_acceptance where key='A';
 select content_snapshot into body from public.artifact_versions where id=vid;
 assert (select draft_revision from public.artifact_versions where id=vid)=0;
 perform public.update_artifact_draft(vid,0,body);
end$$;
reset role;
insert into review_acceptance select 'V1',to_jsonb(v) from public.artifact_versions v where id=(select (data->>'initialVersionId')::uuid from review_acceptance where key='A');
insert into review_acceptance select 'Activity',to_jsonb(i) from public.activity_instances i where id=(select id from instances where label='Team');
insert into review_acceptance values('Clock',jsonb_build_object('before',clock_timestamp()));
insert into review_acceptance select 'Notifications',coalesce(jsonb_agg(to_jsonb(n) order by id),'[]') from public.notifications n;
insert into review_acceptance select 'Baselines',coalesce(jsonb_agg(to_jsonb(b) order by id),'[]') from public.project_baseline_items b;

create function pg_temp.review_state() returns jsonb language sql as $$
 select jsonb_build_object(
 'artifacts',(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a),
 'versions',(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v),
 'submissions',(select jsonb_agg(to_jsonb(s) order by id) from public.submissions s),
 'feedback',(select jsonb_agg(to_jsonb(f) order by id) from public.feedback_items f),
 'actions',(select jsonb_agg(to_jsonb(r) order by id) from public.review_actions r),
 'audit',(select jsonb_agg(to_jsonb(e) order by id) from public.audit_events e));
$$;
create function pg_temp.reject(command text,code text default '42501') returns void language plpgsql as $$
declare actual text;begin
 begin execute command;exception when others then get stacked diagnostics actual=returned_sqlstate;if actual=code then return;end if;raise;end;
 raise exception 'Unexpected acceptance success: %',command;
end $$;
create function pg_temp.team_b_private() returns void language plpgsql as $$
declare actor uuid;begin
 actor:=auth.uid();perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
 assert not exists(select 1 from public.artifacts where id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'));
 assert not exists(select 1 from public.artifact_versions where artifact_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'));
 assert not exists(select 1 from public.submissions where artifact_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'));
 assert not exists(select 1 from public.feedback_items where target_entity_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'));
 assert not exists(select 1 from public.review_actions);
 assert public.get_submitted_artifact_metadata((select (data->>'artifactId')::uuid from review_acceptance where key='A')) is null;
 perform set_config('request.jwt.claim.sub',actor::text,true);
end $$;

-- AT-REV-001 negative matrix runs before the first Submission exists.
insert into review_acceptance values('BeforeDeniedSubmit',pg_temp.review_state());
set local role authenticated;
do $$declare actor integer;cmd text;begin
 cmd:=format('select public.submit_artifact(%L,%L,%L)',(select data->>'artifactId' from review_acceptance where key='A'),(select data->>'initialVersionId' from review_acceptance where key='A'),(select id from instances where label='Team'));
 foreach actor in array array[6001,6002,6003,6004,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor::text,12,'0'),true);perform pg_temp.reject(cmd);
 end loop;
end $$;
reset role;set local role anon;
select pg_temp.reject(format('select public.submit_artifact(%L,%L,%L)',(select data->>'artifactId' from review_acceptance where key='A'),(select data->>'initialVersionId' from review_acceptance where key='A'),(select id from instances where label='Team')));
reset role;
do $$begin assert (select data from review_acceptance where key='BeforeDeniedSubmit')=pg_temp.review_state();end $$;

-- Removed Lead cannot submit; rollback the isolated canonical removal so the
-- main fixture may then execute its approved workflow without rewriting history.
do $$declare before_state jsonb;begin
 before_state:=pg_temp.review_state();
 begin
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
  set local role authenticated;
  perform public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005',null);
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
  perform pg_temp.reject(format('select public.submit_artifact(%L,%L,%L)',(select data->>'artifactId' from review_acceptance where key='A'),(select data->>'initialVersionId' from review_acceptance where key='A'),(select id from instances where label='Team')));
  raise exception 'Rollback removal sub-test' using errcode='P0002';
 exception when no_data_found then null;end;
 assert before_state=pg_temp.review_state();
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into review_acceptance select 'S1',public.submit_artifact((data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,(select id from instances where label='Team')) from review_acceptance where key='A';
-- Existing submit retry semantics reject duplicate cycles; they do not recreate.
select pg_temp.reject(format('select public.submit_artifact(%L,%L,%L)',(select data->>'artifactId' from review_acceptance where key='A'),(select data->>'initialVersionId' from review_acceptance where key='A'),(select id from instances where label='Team')),'23505');
select pg_temp.team_b_private();
reset role;
do $$declare s public.submissions;v public.artifact_versions;a public.artifacts;begin
 select * into s from public.submissions where id=(select (data->>'id')::uuid from review_acceptance where key='S1');
 select * into a from public.artifacts where id=s.artifact_id;select * into v from public.artifact_versions where id=s.artifact_version_id;
 assert s.artifact_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A');
 assert s.artifact_version_id=(select (data->>'initialVersionId')::uuid from review_acceptance where key='A');
 assert s.activity_instance_id=(select id from instances where label='Team');
 assert s.submitted_by='00000000-0000-4000-8000-000000006005' and s.reviewer_user_id='00000000-0000-4000-8000-000000006002';
 assert s.submitted_at between (select (data->>'before')::timestamptz from review_acceptance where key='Clock') and clock_timestamp();
 assert s.status='SUBMITTED' and v.status='SUBMITTED' and a.status='ACTIVE' and a.current_version_id is null;
 assert (to_jsonb(v)-'status')=(select data-'status' from review_acceptance where key='V1');
 assert (select count(*) from public.submissions where artifact_id=a.id)=1;
 assert (select data from review_acceptance where key='Activity')=(select to_jsonb(i) from public.activity_instances i where id=s.activity_instance_id);
end $$;
\echo AT-REV-001 CORE/SECURITY/HISTORY PASS; notification DEFERRED TO M15

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into review_acceptance select 'Started1',public.start_review((data->>'id')::uuid) from review_acceptance where key='S1';
do $$begin assert (select data from review_acceptance where key='Started1')=public.start_review((select (data->>'id')::uuid from review_acceptance where key='S1'));end $$;
insert into review_acceptance select 'Comment',public.add_feedback('ARTIFACT',(data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,'COMMENT','Original V1 feedback') from review_acceptance where key='A';
reset role;
insert into review_acceptance select 'BeforeRevision',to_jsonb(v) from public.artifact_versions v where id=(select (data->>'initialVersionId')::uuid from review_acceptance where key='A');
set local role authenticated;
insert into review_acceptance select 'Revision',public.request_revision((data->>'id')::uuid,'Revise the concept with clear constraints') from review_acceptance where key='S1';
do $$begin assert (select data from review_acceptance where key='Revision')=public.request_revision((select (data->>'id')::uuid from review_acceptance where key='S1'),'Revise the concept with clear constraints');end $$;
select pg_temp.team_b_private();
reset role;
do $$declare sid uuid;vid uuid;begin
 sid:=(select (data->>'id')::uuid from review_acceptance where key='S1');vid:=(select (data->>'initialVersionId')::uuid from review_acceptance where key='A');
 assert (select status from public.submissions where id=sid)='REVISION_REQUESTED';
 assert (select status from public.artifact_versions where id=vid)='REVISION_REQUESTED';
 assert (select to_jsonb(v)-'status' from public.artifact_versions v where id=vid)=(select data-'status' from review_acceptance where key='BeforeRevision');
 assert (select count(*) from public.review_actions where submission_id=sid and action_type='STARTED_REVIEW')=1;
 assert (select count(*) from public.review_actions where submission_id=sid and action_type='REQUESTED_REVISION' and note='Revise the concept with clear constraints')=1;
 assert (select count(*) from public.feedback_items where submission_id=sid and feedback_type='REVISION_REQUEST' and target_entity_type='ARTIFACT' and target_entity_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A') and target_version_id=vid and status='OPEN' and content='Revise the concept with clear constraints')=1;
 assert (select to_jsonb(f) from public.feedback_items f where id=(select (data->>'id')::uuid from review_acceptance where key='Comment'))=(select data from review_acceptance where key='Comment');
 assert (select count(*) from public.audit_events where event_type='REVISION_REQUESTED' and entity_id=sid and actor_user_id='00000000-0000-4000-8000-000000006002' and metadata='{}')=1;
end $$;
insert into review_acceptance select 'HistoricalV1',to_jsonb(v) from public.artifact_versions v where id=(select (data->>'initialVersionId')::uuid from review_acceptance where key='A');
insert into review_acceptance select 'HistoricalS1',to_jsonb(s) from public.submissions s where id=(select (data->>'id')::uuid from review_acceptance where key='S1');
insert into review_acceptance select 'HistoricalFeedback',jsonb_agg(to_jsonb(f) order by id) from public.feedback_items f;
\echo AT-REV-002 CORE/SECURITY/HISTORY PASS; notification DEFERRED TO M15

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into review_acceptance select 'V2',public.create_revision_draft((data->>'id')::uuid,'{"concept":"Revised concept","constraints":["explicit"]}','Address V1 feedback') from review_acceptance where key='S1';
do $$begin
 assert (select data->>'id' from review_acceptance where key='V2')<>(select data->>'id' from review_acceptance where key='V1');
 assert (select data->>'status' from review_acceptance where key='V2')='DRAFT';
 assert (select data->>'artifact_id' from review_acceptance where key='V2')=(select data->>'artifactId' from review_acceptance where key='A');
 assert (select data->>'previous_version_id' from review_acceptance where key='V2')=(select data->>'id' from review_acceptance where key='V1');
 assert (select (data->>'version_number')::int from review_acceptance where key='V2')=2;
 assert (select data->>'approved_by' from review_acceptance where key='V2') is null and (select data->>'approved_at' from review_acceptance where key='V2') is null;
end $$;
insert into review_acceptance select 'S2',public.submit_artifact((select (data->>'artifactId')::uuid from review_acceptance where key='A'),(data->>'id')::uuid,(select id from instances where label='Team')) from review_acceptance where key='V2';
select pg_temp.team_b_private();
reset role;
do $$begin
 assert (select data->>'id' from review_acceptance where key='S2')<>(select data->>'id' from review_acceptance where key='S1');
 assert (select data->>'artifact_version_id' from review_acceptance where key='S2')=(select data->>'id' from review_acceptance where key='V2');
 assert (select data->>'activity_instance_id' from review_acceptance where key='S2')=(select id::text from instances where label='Team');
 assert (select data->>'reviewer_user_id' from review_acceptance where key='S2')='00000000-0000-4000-8000-000000006002';
 assert (select data->>'status' from review_acceptance where key='S2')='SUBMITTED';
 assert (select status from public.artifact_versions where id=(select (data->>'id')::uuid from review_acceptance where key='V2'))='SUBMITTED';
 assert (select data from review_acceptance where key='HistoricalV1')=(select to_jsonb(v) from public.artifact_versions v where id=(select (data->>'id')::uuid from review_acceptance where key='V1'));
 assert (select data from review_acceptance where key='HistoricalS1')=(select to_jsonb(s) from public.submissions s where id=(select (data->>'id')::uuid from review_acceptance where key='S1'));
end $$;
\echo AT-REV-003 CORE/SECURITY/HISTORY PASS

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (data->>'id')::uuid from review_acceptance where key='S2'));
reset role;
insert into review_acceptance values('BeforeDeniedApproval',pg_temp.review_state());
set local role authenticated;
-- Creator = Lead = submitter is tested under all three contextual assertions;
-- ordinary Student member, Admin, Mentor and unrelated Master are denied too.
do $$declare actor integer;begin
 foreach actor in array array[6001,6003,6004,6005,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor::text,12,'0'),true);
  perform pg_temp.reject(format('select public.approve_artifact(%L,''forged approval'')',(select data->>'id' from review_acceptance where key='S2')));
 end loop;
end $$;
reset role;
do $$begin assert (select data from review_acceptance where key='BeforeDeniedApproval')=pg_temp.review_state();end $$;
-- Current assignment revocation also prevents the exact historical reviewer.
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.reject(format('select public.approve_artifact(%L)',(select data->>'id' from review_acceptance where key='S2')));
reset role;
do $$begin assert (select data from review_acceptance where key='BeforeDeniedApproval')=pg_temp.review_state();end $$;
update public.role_assignments set status='active' where user_id='00000000-0000-4000-8000-000000006002';
\echo AT-REV-005 CORE/SECURITY/HISTORY PASS; creator/Lead/submitter and revoked/unrelated reviewer denied

-- Force an audit-write failure after every approval content/history mutation.
-- The failed RPC must roll back to the exact complete pre-approval fingerprint.
create function pg_temp.reject_approval_audit() returns trigger language plpgsql as $$begin if new.event_type='ARTIFACT_APPROVED' then raise exception 'Injected approval audit failure' using errcode='23514';end if;return new;end $$;
create trigger m816_fail_approval after insert on public.audit_events for each row execute function pg_temp.reject_approval_audit();
set local role authenticated;
select pg_temp.reject(format('select public.approve_artifact(%L,''Approved revised concept'')',(select data->>'id' from review_acceptance where key='S2')),'23514');
reset role;
do $$begin assert (select data from review_acceptance where key='BeforeDeniedApproval')=pg_temp.review_state();end $$;
drop trigger m816_fail_approval on public.audit_events;
set local role authenticated;
insert into review_acceptance select 'Approved',public.approve_artifact((data->>'id')::uuid,'Approved revised concept') from review_acceptance where key='S2';
do $$begin assert (select data from review_acceptance where key='Approved')=public.approve_artifact((select (data->>'id')::uuid from review_acceptance where key='S2'),'Approved revised concept');end $$;
select pg_temp.team_b_private();
reset role;
do $$declare a public.artifacts;v public.artifact_versions;sid uuid;begin
 sid:=(select (data->>'id')::uuid from review_acceptance where key='S2');
 select * into a from public.artifacts where id=(select (data->>'artifactId')::uuid from review_acceptance where key='A');
 select * into v from public.artifact_versions where id=(select (data->>'id')::uuid from review_acceptance where key='V2');
 assert a.status='ACTIVE' and a.current_version_id=v.id and v.status='CURRENT';
 assert v.approved_by='00000000-0000-4000-8000-000000006002' and v.approval_note='Approved revised concept';
 assert v.approved_at between (select (data->>'before')::timestamptz from review_acceptance where key='Clock') and clock_timestamp();
 assert v.created_by='00000000-0000-4000-8000-000000006005';
 assert (to_jsonb(v)-array['status','approved_by','approved_at','approval_note'])=(select data-array['status','approved_by','approved_at','approval_note'] from review_acceptance where key='V2');
 assert (select status from public.submissions where id=sid)='APPROVED';
 assert (select count(*) from public.artifact_versions where artifact_id=a.id and status='CURRENT')=1;
 assert (select count(*) from public.artifact_versions where artifact_id=a.id)=2;
 assert (select count(*) from public.submissions where artifact_id=a.id)=2;
 assert (select count(*) from public.review_actions where submission_id=sid and action_type='STARTED_REVIEW')=1;
 assert (select count(*) from public.review_actions where submission_id=sid and action_type='APPROVED' and reviewer_user_id=v.approved_by and note=v.approval_note and created_at=v.approved_at)=1;
 assert (select count(*) from public.audit_events where entity_id=sid and event_type='ARTIFACT_APPROVED' and actor_user_id=v.approved_by and created_at=v.approved_at and metadata='{}')=1;
 assert (select count(*) from public.audit_events where entity_id=sid and event_type='ARTIFACT_APPROVED')=1;
 assert (select data from review_acceptance where key='HistoricalFeedback')=(select jsonb_agg(to_jsonb(f) order by id) from public.feedback_items f);
 assert (select data from review_acceptance where key='HistoricalV1')=(select to_jsonb(v0) from public.artifact_versions v0 where id=(select (data->>'id')::uuid from review_acceptance where key='V1'));
 assert (select data from review_acceptance where key='HistoricalS1')=(select to_jsonb(s) from public.submissions s where id=(select (data->>'id')::uuid from review_acceptance where key='S1'));
 assert (select data from review_acceptance where key='Activity')=(select to_jsonb(i) from public.activity_instances i where id=(select id from instances where label='Team'));
 assert (select data from review_acceptance where key='Baselines')=(select coalesce(jsonb_agg(to_jsonb(b) order by id),'[]') from public.project_baseline_items b);
 assert (select data from review_acceptance where key='Notifications')=(select coalesce(jsonb_agg(to_jsonb(n) order by id),'[]') from public.notifications n);
 -- The approved notification vocabulary is membership-only; M8 side effects
 -- remain explicitly deferred. The absence is never reported as notification PASS.
 assert not exists(select 1 from public.notifications where notification_type not in ('MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED'));
end $$;
\echo AT-REV-004 CORE/SECURITY/HISTORY PASS; notification DEFERRED TO M15

-- Existing supersession semantics exercised as an isolated branch. Roll it back
-- so the primary acceptance history finishes with exactly V1 and V2 CURRENT.
savepoint m816_supersession;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into review_acceptance select 'V3',public.create_artifact_version((data->>'artifactId')::uuid,'{"later":true}','Supersession regression') from review_acceptance where key='A';
insert into review_acceptance select 'S3',public.submit_artifact((select (data->>'artifactId')::uuid from review_acceptance where key='A'),(data->>'id')::uuid,(select id from instances where label='Team')) from review_acceptance where key='V3';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (data->>'id')::uuid from review_acceptance where key='S3'));
select public.approve_artifact((select (data->>'id')::uuid from review_acceptance where key='S3'));
reset role;
do $$begin
 assert (select status from public.artifact_versions where id=(select (data->>'id')::uuid from review_acceptance where key='V2'))='SUPERSEDED';
 assert (select current_version_id from public.artifacts where id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'))=(select (data->>'id')::uuid from review_acceptance where key='V3');
 assert (select data from review_acceptance where key='Baselines')=(select coalesce(jsonb_agg(to_jsonb(b) order by id),'[]') from public.project_baseline_items b);
end $$;
rollback to savepoint m816_supersession;
release savepoint m816_supersession;

-- Ordinary creator/Lead cannot rewrite approval, lineage, Submission or pointer.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare column_name text;begin
 foreach column_name in array array['content_snapshot','version_number','previous_version_id','approved_by','approved_at','approval_note'] loop
  perform pg_temp.reject(format('update public.artifact_versions set %I=%I where id=%L',column_name,column_name,(select data->>'id' from review_acceptance where key='V2')));
 end loop;
 perform pg_temp.reject(format('update public.artifacts set current_version_id=%L where id=%L',(select data->>'id' from review_acceptance where key='V1'),(select data->>'artifactId' from review_acceptance where key='A')));
 perform pg_temp.reject(format('update public.submissions set artifact_version_id=%L where id=%L',(select data->>'id' from review_acceptance where key='V2'),(select data->>'id' from review_acceptance where key='S1')));
 assert (select count(*) from public.feedback_items where target_version_id=(select (data->>'id')::uuid from review_acceptance where key='V1'))=2;
 assert (select count(*) from public.review_actions)=5;
end $$;
reset role;
insert into review_acceptance values('BeforeRemoval',pg_temp.review_state());
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert not exists(select 1 from public.artifacts where id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'));
 assert not exists(select 1 from public.artifact_versions where id in (select (data->>'id')::uuid from review_acceptance where key in ('V1','V2')));
 assert not exists(select 1 from public.submissions where id in (select (data->>'id')::uuid from review_acceptance where key in ('S1','S2')));
 assert not exists(select 1 from public.feedback_items);
 assert not exists(select 1 from public.review_actions);
end $$;
select pg_temp.team_b_private();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert exists(select 1 from public.artifacts where id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'));
 assert (select count(*) from public.submissions where artifact_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'))=2;
 assert (select count(*) from public.review_actions)=5;
end $$;
reset role;
-- Removal adds its own Team event but cannot rewrite the prior M8 history.
do $$begin
 assert (select data-'audit' from review_acceptance where key='BeforeRemoval')=(pg_temp.review_state()-'audit');
 assert (select status from public.artifact_versions where id=(select (data->>'id')::uuid from review_acceptance where key='V2'))='CURRENT';
 assert (select count(*) from public.audit_events where event_type='REVISION_REQUESTED')=1;
 assert (select count(*) from public.audit_events where event_type='ARTIFACT_APPROVED')=1;
end $$;
rollback;
\echo M8.16 consolidated AT-REV-001/002/003/004/005 lifecycle/history/privacy/rollback/retry/baseline PASS; notifications DEFERRED TO M15
