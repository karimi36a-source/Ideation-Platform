\set ON_ERROR_STOP on
begin;
create function pg_temp.gate(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'M15.25: %',label;end if;end$$;
create temporary table progress_attack(label text primary key,payload jsonb);grant select,insert on progress_attack to authenticated;
insert into progress_attack select 'Cohort A',jsonb_build_object('id',cohort_id) from public.teams where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A');
-- Unrelated Cohort has its own approved curriculum, so neither its Definitions
-- nor its completion history may alter A1's denominator/numerator.
do $$declare cv uuid;sid uuid;aid uuid;cid uuid;begin
 insert into public.curriculum_versions(program_id,version_label,status) values('00000000-0000-4000-8000-000000000601','M15.25 foreign curriculum','draft') returning id into cv;
 insert into public.session_definitions(curriculum_version_id,session_number,title,description,learning_goal,sequence,status) values(cv,1,'M1525_FOREIGN_SESSION','fixture','Privacy gate',1,'active') returning id into sid;
 insert into public.activity_definitions(session_definition_id,name,method_type,workspace_mode,sequence,status) values(sid,'M1525_FOREIGN_ACTIVITY','custom','Team Workspace',1,'active') returning id into aid;
 insert into public.activity_definitions(session_definition_id,name,method_type,workspace_mode,sequence,status) values(sid,'M1525_FOREIGN_EXTRA','custom','Team Workspace',2,'active');
 update public.curriculum_versions set status='approved' where id=cv;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
 cid:=(public.create_cohort('00000000-0000-4000-8000-000000000601',cv,'M1525_FOREIGN_COHORT','2026-10-01',null,'00000000-0000-4000-8000-000000006003','active','{}')->>'id')::uuid;
 insert into progress_attack values('Cohort B',jsonb_build_object('id',cid)),('Foreign Definition',jsonb_build_object('id',aid));
end$$;
insert into progress_attack select 'Known Snapshot',jsonb_build_object('id',id) from public.share_snapshots where share_id=(select (payload->>'id')::uuid from public.current_work_fixture where label='Share');
update public.teams set status='active' where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team B');
-- Separate canonical Team/Project in the unrelated Cohort, using its own Master.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
insert into progress_attack select 'Foreign Team',public.create_team((payload->>'id')::uuid,'M1525_FOREIGN_TEAM') from progress_attack where label='Cohort B';
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006006','participant','active' from progress_attack where label='Cohort B';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select public.add_team_member((payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006006','team_lead') from progress_attack where label='Foreign Team';
insert into progress_attack select 'Foreign Project',public.create_development_project('M1525_FOREIGN_PROJECT','team',(payload->>'workspaceId')::uuid,null,null,(payload->>'teamId')::uuid) from progress_attack where label='Foreign Team';
reset role;
update public.teams set status='active' where id=(select (payload->>'teamId')::uuid from progress_attack where label='Foreign Team');
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006006' from progress_attack where label='Foreign Project';
insert into public.project_program_links(project_id,program_id,cohort_id) select (p.payload->>'id')::uuid,c.program_id,c.id from progress_attack p,public.cohorts c where p.label='Foreign Project' and c.id=(select (payload->>'id')::uuid from progress_attack where label='Cohort B');
-- Snapshot of A1's own counts before foreign history exists.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into progress_attack select 'A1 Team counts',public.get_my_learning_progress((select (payload->>'id')::uuid from public.current_work_fixture where label='Project Team'),(select (payload->>'workspaceId')::uuid from public.current_work_fixture where label='Team A'),(payload->>'id')::uuid,(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A')) from progress_attack where label='Cohort A';
insert into progress_attack select 'A1 Personal counts',public.get_my_learning_progress((select (payload->>'id')::uuid from public.current_work_fixture where label='Project Individual'),(select (payload->>'primary_workspace_id')::uuid from public.current_work_fixture where label='Project Individual'),(payload->>'id')::uuid,null) from progress_attack where label='Cohort A';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.send_team_chat_message((select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A'),'M1525_PRIVATE_CHAT');
select pg_temp.gate(exists(select 1 from public.chat_messages where content='M1525_PRIVATE_CHAT'),'positive control: private Team chat exists');
insert into progress_attack select 'Team Share',public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',payload->>'initialVersionId','destinationType','TEAM','destinationId',(select payload->>'teamId' from public.current_work_fixture where label='Team B'),'permissionLevel','VIEW','shareMode','SNAPSHOT')) from public.current_work_fixture where label='Artifact Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.gate((public.resolve_shared_entity_access(jsonb_build_object('shareId',(select payload->>'id' from progress_attack where label='Team Share')))->>'allowed')::boolean,'positive control: Team B can resolve explicitly shared Team A Snapshot');
select pg_temp.gate(public.get_my_learning_progress((select (payload->>'id')::uuid from public.current_work_fixture where label='Project Team'),(select (payload->>'workspaceId')::uuid from public.current_work_fixture where label='Team A'),(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A')) is null,'Team Snapshot recipient cannot see source Team progress');
select pg_temp.gate(public.get_my_current_work_catalog((select (payload->>'id')::uuid from public.current_work_fixture where label='Project Team'),(select (payload->>'workspaceId')::uuid from public.current_work_fixture where label='Team A'),(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A')) is null,'Team Snapshot recipient cannot see source Team current-work');
select pg_temp.gate(not exists(select 1 from public.workspaces where id=(select (payload->>'workspaceId')::uuid from public.current_work_fixture where label='Team A')),'Team Snapshot does not authorize source Workspace browsing');
reset role;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,completed_at,status,configuration_snapshot)
 select (select (payload->>'id')::uuid from progress_attack where label='Foreign Definition'),(select (payload->>'id')::uuid from progress_attack where label='Cohort B'),(select (payload->>'id')::uuid from progress_attack where label='Foreign Project'),(payload->>'workspaceId')::uuid,(payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006006',clock_timestamp(),clock_timestamp(),'completed','{}' from progress_attack where label='Foreign Team';
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,started_by,started_at,completed_at,status,configuration_snapshot)
 select '00000000-0000-4000-8000-000000098102',(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'00000000-0000-4000-8000-000000006005',clock_timestamp(),clock_timestamp(),'completed','{}' from public.current_work_fixture where label='A2 Project';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.gate(public.get_my_learning_progress((select (payload->>'id')::uuid from progress_attack where label='Foreign Project'),(select (payload->>'workspaceId')::uuid from progress_attack where label='Foreign Team'),(select (payload->>'id')::uuid from progress_attack where label='Cohort B'),(select (payload->>'teamId')::uuid from progress_attack where label='Foreign Team')) @> '{"requiredActivitiesTotal":2,"completedRequiredActivities":1,"completionPercentage":50}'::jsonb,'positive control: foreign authorized progress has distinct curriculum and completed history');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.gate(public.get_my_learning_progress((select (payload->>'id')::uuid from public.current_work_fixture where label='Project Team'),(select (payload->>'workspaceId')::uuid from public.current_work_fixture where label='Team A'),(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A'))=(select payload from progress_attack where label='A1 Team counts'),'foreign Team/Cohort completion cannot influence A1 counts');
select pg_temp.gate(public.get_my_learning_progress((select (payload->>'id')::uuid from public.current_work_fixture where label='Project Individual'),(select (payload->>'primary_workspace_id')::uuid from public.current_work_fixture where label='Project Individual'),(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),null)=(select payload from progress_attack where label='A1 Personal counts'),'A2 Personal completion cannot satisfy A1 progress');
select pg_temp.gate((public.resolve_shared_entity_access(jsonb_build_object('shareId',(select payload->>'id' from public.current_work_fixture where label='Share')))->>'allowed')::boolean,'positive control: exact A2 Snapshot is shared to A1 Team');
select pg_temp.gate(public.get_my_learning_progress((select (payload->>'id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'primary_workspace_id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),null) is null,'Share does not authorize source Personal progress');
select pg_temp.gate(public.get_my_current_work_catalog((select (payload->>'id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'primary_workspace_id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),null) is null,'Share does not authorize source current-work catalog');
-- Known-valid foreign Team/Project/Workspace IDs never confer progress authority.
do $$declare uid text;begin
 foreach uid in array array['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',uid,true);
  perform pg_temp.gate(public.get_my_learning_progress((select (payload->>'id')::uuid from progress_attack where label='Foreign Project'),(select (payload->>'workspaceId')::uuid from progress_attack where label='Foreign Team'),(select (payload->>'id')::uuid from progress_attack where label='Cohort B'),(select (payload->>'teamId')::uuid from progress_attack where label='Foreign Team')) is null,'foreign aggregate denied, including role-only/Admin self progress');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 begin perform public.get_master_cohort_overview((select (payload->>'id')::uuid from progress_attack where label='Cohort B'));raise exception 'Cross-Cohort overview leaked';exception when insufficient_privilege then null;end;
end$$;
-- Master operational metadata must not reopen private source details.
select pg_temp.gate(not exists(select 1 from public.artifact_versions where id=(select (payload->>'id')::uuid from public.current_work_fixture where label='V3')),'Master cannot open unpublished Draft through known Version ID');
select pg_temp.gate(not exists(select 1 from public.artifacts where id=(select (payload->>'artifactId')::uuid from public.current_work_fixture where label='A2 Artifact')),'Master cannot browse unsubmitted Personal Artifact through progress');
select pg_temp.gate(not exists(select 1 from public.chat_messages m join public.chat_channels c on c.id=m.chat_channel_id where c.workspace_id=(select (payload->>'workspaceId')::uuid from public.current_work_fixture where label='Team A')),'Master cannot read Team Chat');
-- Explicitly approve A2 Personal output through M8, then attack it as A1.
-- The reviewer's exact submission authority is distinct from broad Personal
-- browsing or Share-derived own-work/progress authority.
reset role;
with created as (
 insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,started_by,started_at,status,configuration_snapshot)
 select '00000000-0000-4000-8000-000000098102',(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'00000000-0000-4000-8000-000000006005',clock_timestamp(),'active','{}' from public.current_work_fixture where label='A2 Project' returning id
) insert into progress_attack select 'A2 Active Instance',jsonb_build_object('id',id) from created;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into progress_attack select 'A2 Approved Submission',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select (payload->>'id')::uuid from progress_attack where label='A2 Active Instance')) from public.current_work_fixture where label='A2 Artifact';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((payload->>'id')::uuid) from progress_attack where label='A2 Approved Submission';
select public.approve_artifact((payload->>'id')::uuid,null) from progress_attack where label='A2 Approved Submission';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.gate(not exists(select 1 from public.artifact_versions where id=(select (payload->>'initialVersionId')::uuid from public.current_work_fixture where label='A2 Artifact')),'A1 cannot fetch A2 approved Personal output via direct Version ID');
select pg_temp.gate(public.get_my_current_work_catalog((select (payload->>'id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'primary_workspace_id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),null) is null,'approved Personal output and Share never grant source current-work');
select pg_temp.gate(public.get_my_learning_progress((select (payload->>'id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'primary_workspace_id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),null) is null,'approved Personal output never grants source progress');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
-- Substitute every known valid non-Cohort identifier into all Master projections.
do $$declare known uuid;fn text;begin
 for known in select (payload->>'id')::uuid from public.current_work_fixture where label in ('Revision','V2','V3','Share','Instance Team','Project Team')
  union all select (payload->>'artifactId')::uuid from public.current_work_fixture where label='A2 Artifact'
  union all select (payload->>'id')::uuid from progress_attack where label='Known Snapshot'
 loop
  foreach fn in array array['get_master_cohort_overview','get_pending_review_queue','get_revision_status'] loop
   begin execute format('select public.%I($1)',fn) using known;raise exception 'Non-Cohort ID accepted by %',fn;exception when insufficient_privilege then null;end;
  end loop;
 end loop;
end$$;
-- Share revocation preserves history and cannot resurrect source progress.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.revoke_share(jsonb_build_object('shareId',(select payload->>'id' from public.current_work_fixture where label='Share')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.gate(not coalesce((public.resolve_shared_entity_access(jsonb_build_object('shareId',(select payload->>'id' from public.current_work_fixture where label='Share')))->>'allowed')::boolean,false),'revoked Share denied');
select pg_temp.gate(public.get_my_learning_progress((select (payload->>'id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'primary_workspace_id')::uuid from public.current_work_fixture where label='A2 Project'),(select (payload->>'id')::uuid from progress_attack where label='Cohort A'),null) is null,'revocation cannot reopen source progress');
reset role;
select pg_temp.gate(exists(select 1 from public.shares where id=(select (payload->>'id')::uuid from public.current_work_fixture where label='Share') and revoked_at is not null) and exists(select 1 from public.share_snapshots where share_id=(select (payload->>'id')::uuid from public.current_work_fixture where label='Share')),'Share/Snapshot history retained');
rollback;
\echo M15.25 cross-Cohort/foreign-history/Share/direct-ID/source-RLS authorization gate PASS
