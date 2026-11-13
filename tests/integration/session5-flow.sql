begin;
create table public.m1018_ids(label text primary key,id uuid not null);
create table public.m1018_data(label text primary key,payload jsonb not null);
grant select,insert on public.m1018_ids,public.m1018_data to authenticated;
insert into public.m1018_ids select label,(payload->>'id')::uuid from public.m919_fixture where label in('Project','Problem1','Problem2','Problem3','Solution1','Solution2','Solution3');
insert into public.m1018_ids select 'Workspace',(payload->>'primary_workspace_id')::uuid from public.m919_fixture where label='Project';
insert into public.m1018_ids select 'Team',(payload->>'teamId')::uuid from public.m919_fixture where label='Team';
insert into public.m1018_ids select 'Activity',(payload#>>'{activity,id}')::uuid from public.m919_fixture where label='Session5';
insert into public.m1018_ids select label,(payload#>>'{artifact,id}')::uuid from public.m919_fixture where label in('ProblemBank','SolutionBank');
insert into public.m1018_ids select label||'Version',(payload#>>'{version,id}')::uuid from public.m919_fixture where label in('ProblemBank','SolutionBank');
create function pg_temp.s5(label0 text) returns uuid language sql as $$select id from public.m1018_ids where label=label0$$;
create table public.m1018_preserved as select
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a where id in(pg_temp.s5('ProblemBank'),pg_temp.s5('SolutionBank'))) banks,
 (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v where artifact_id in(pg_temp.s5('ProblemBank'),pg_temp.s5('SolutionBank'))) bank_versions,
 (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b) baselines,
 (select count(*) from public.artifacts) artifact_count;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.create_voting_session(pg_temp.s5('Activity'),'DOT_VOTE',3,false,'LIVE','[{"label":"Unauthorized"}]');raise exception 'Student created voting Session';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into public.m1018_data select 'Voting',public.create_voting_session(pg_temp.s5('Activity'),'DOT_VOTE',3,false,'LIVE',
 (select jsonb_agg(jsonb_build_object('label',label,'developmentObjectId',id) order by label) from public.m1018_ids where label in('Problem1','Problem2','Solution1','Solution2','Solution3')));
insert into public.m1018_ids select 'Voting',(payload#>>'{session,id}')::uuid from public.m1018_data where label='Voting';
select public.open_voting_session(pg_temp.s5('Voting'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.cast_vote(pg_temp.s5('Voting'),(select id from public.voting_options where voting_session_id=pg_temp.s5('Voting') and development_object_id=pg_temp.s5(x)),1) from unnest(array['Solution1','Solution2','Problem1']) x;
do $$begin
 begin perform public.cast_vote(pg_temp.s5('Voting'),(select id from public.voting_options where voting_session_id=pg_temp.s5('Voting') and development_object_id=pg_temp.s5('Problem2')),1);raise exception 'Fourth vote allowed';exception when unique_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.cast_vote(pg_temp.s5('Voting'),(select id from public.voting_options where voting_session_id=pg_temp.s5('Voting') and development_object_id=pg_temp.s5(x)),1) from unnest(array['Solution1','Solution3']) x;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.close_voting_session(pg_temp.s5('Voting'));
insert into public.m1018_data values('Results',public.get_voting_results(pg_temp.s5('Voting')));
do $$declare r jsonb;begin
 select payload into r from public.m1018_data where label='Results';
 assert exists(select 1 from jsonb_array_elements(r->'options') o where o->>'label'='Solution1' and o->>'voteCount'='2');
 assert exists(select 1 from jsonb_array_elements(r->'options') o where o->>'label'='Solution2' and o->>'voteCount'='1');
 assert not r::text like '%user_id%' and not r::text like '%voter%';
 begin perform 1 from public.votes;raise exception 'Raw voting access';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.decisions);
end $$;
reset role;
do $$begin assert (select count(*) from public.votes where voting_session_id=pg_temp.s5('Voting') and user_id='00000000-0000-4000-8000-000000006004')=3;end $$;
-- Discussion is external to the structured workflow. Only this explicit human
-- operation creates a Decision; it does not treat the vote leader as the answer.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.m1018_data values('Decision',public.create_decision(jsonb_build_object('projectId',pg_temp.s5('Project'),'workspaceId',pg_temp.s5('Workspace'),'activityInstanceId',pg_temp.s5('Activity'),'title','Session 5 human decision','question','Which solution should we develop?','method','DOT_VOTE','options',jsonb_build_array(jsonb_build_object('label','S1 vote leader','developmentObjectId',pg_temp.s5('Solution1')),jsonb_build_object('label','S2 human choice','developmentObjectId',pg_temp.s5('Solution2'))))));
insert into public.m1018_ids select 'Decision',(payload#>>'{decision,id}')::uuid from public.m1018_data where label='Decision';
reset role;
-- Existing participant metadata has no public management API; trusted fixture only.
insert into public.decision_participants(decision_id,user_id,role,position,comment) values(pg_temp.s5('Decision'),'00000000-0000-4000-8000-000000006004','OBSERVER','Alternative considered','Preserved discussion attribution');
set local role authenticated;
select public.link_decision_entity(jsonb_build_object('decisionId',pg_temp.s5('Decision'),'linkedEntityType','VOTING_SESSION','linkedEntityId',pg_temp.s5('Voting'),'relationshipType','INFORMED_BY'));
select public.link_decision_entity(jsonb_build_object('decisionId',pg_temp.s5('Decision'),'linkedEntityType','DEVELOPMENT_OBJECT','linkedEntityId',pg_temp.s5('Solution2'),'relationshipType','CONSIDERED_IN_DECISION'));
select public.link_decision_entity(jsonb_build_object('decisionId',pg_temp.s5('Decision'),'linkedEntityType','ARTIFACT','linkedEntityId',pg_temp.s5(x),'relationshipType','CONSIDERED_IN_DECISION')) from unnest(array['ProblemBank','SolutionBank']) x;
insert into public.m1018_data values('Finalized',public.finalize_decision(jsonb_build_object('decisionId',pg_temp.s5('Decision'),'selectedOptionId',(select id from public.decision_options where decision_id=pg_temp.s5('Decision') and development_object_id=pg_temp.s5('Solution2')),'outcome','Develop S2 despite lower popularity','reasoning','After discussion, S2 better addresses feasibility and the selected problem','linkedObjectIds',jsonb_build_array(pg_temp.s5('Solution2')),'linkedArtifactIds',jsonb_build_array(pg_temp.s5('ProblemBank'),pg_temp.s5('SolutionBank')))));
insert into public.m1018_data values('Record',public.create_team_decision_record_artifact(pg_temp.s5('Decision')));
insert into public.m1018_ids select 'Record',(payload#>>'{artifact,id}')::uuid from public.m1018_data where label='Record';
insert into public.m1018_ids select 'RecordVersion',(payload#>>'{version,id}')::uuid from public.m1018_data where label='Record';
do $$begin
 assert (select status='DRAFT' from public.artifact_versions where id=pg_temp.s5('RecordVersion'));
 assert (select artifact_type='TEAM_DECISION_RECORD' and current_version_id is null from public.artifacts where id=pg_temp.s5('Record'));
 assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000001018801',pg_temp.s5('Project'),pg_temp.s5('Workspace'),pg_temp.s5('Team'))->>'satisfied'='true';
 assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000001018802',pg_temp.s5('Project'),pg_temp.s5('Workspace'),pg_temp.s5('Team'))->>'satisfied'='false';
end $$;
-- Optional explicit M8 review demonstrates approved_output; this does not add a
-- production Session 5 approval requirement or alter the fixture's false flags.
insert into public.m1018_data values('Submission',public.submit_artifact(pg_temp.s5('Record'),pg_temp.s5('RecordVersion'),pg_temp.s5('Activity')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((payload->>'id')::uuid) from public.m1018_data where label='Submission';
select public.approve_artifact((payload->>'id')::uuid,'Explicit optional instructor approval') from public.m1018_data where label='Submission';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000001018802',pg_temp.s5('Project'),pg_temp.s5('Workspace'),pg_temp.s5('Team'))->>'satisfied'='true';end $$;
insert into public.m1018_data values('Downstream',public.start_activity('00000000-0000-4000-8000-000001018802',pg_temp.s5('Project'),pg_temp.s5('Workspace'),pg_temp.s5('Team')));
insert into public.m1018_ids select 'Downstream',(payload#>>'{activity,id}')::uuid from public.m1018_data where label='Downstream';
select public.add_activity_artifact_input(pg_temp.s5('Downstream'),pg_temp.s5('Record'),pg_temp.s5('RecordVersion'),true);
reset role;
do $$declare d public.decisions;v public.artifact_versions;begin
 select * into d from public.decisions where id=pg_temp.s5('Decision');
 select * into v from public.artifact_versions where id=pg_temp.s5('RecordVersion');
 assert d.status='FINALIZED' and length(d.outcome)>0 and length(d.reasoning)>0 and d.decided_at is not null;
 assert (select count(*) from public.decision_options where decision_id=d.id and selected)=1;
 assert exists(select 1 from public.decision_options where decision_id=d.id and selected and development_object_id=pg_temp.s5('Solution2'));
 assert exists(select 1 from public.decision_participants where decision_id=d.id and role='FINALIZER' and user_id='00000000-0000-4000-8000-000000006005');
 assert (select count(*) from public.decision_links where decision_id=d.id)=4;
 assert (select configuration_snapshot#>>'{configuration,outputs,artifact_types,0}'='TEAM_DECISION_RECORD' and configuration_snapshot->>'requires_review'='false' and configuration_snapshot->>'requires_approval'='false' from public.activity_instances where id=pg_temp.s5('Activity'));
 assert jsonb_array_length(v.content_snapshot->'participants')=2;
 assert v.content_snapshot#>'{references,votingSessionIds}' @> jsonb_build_array(pg_temp.s5('Voting')::text);
 assert (select count(*) from public.activity_inputs where activity_instance_id=pg_temp.s5('Activity') and artifact_id in(pg_temp.s5('ProblemBank'),pg_temp.s5('SolutionBank')))=2;
 assert exists(select 1 from public.artifact_object_links bank
  join public.voting_options vo on vo.development_object_id=bank.development_object_id
  join public.decision_options opt on opt.development_object_id=vo.development_object_id
  join public.decision_links dl on dl.decision_id=opt.decision_id and dl.linked_entity_type='DEVELOPMENT_OBJECT' and dl.linked_entity_id=opt.development_object_id
  join public.artifact_object_links record0 on record0.development_object_id=opt.development_object_id
  join public.activity_inputs input0 on input0.artifact_id=record0.artifact_id and input0.artifact_version_id=record0.artifact_version_id
  where bank.artifact_id=pg_temp.s5('SolutionBank') and bank.artifact_version_id=pg_temp.s5('SolutionBankVersion') and bank.development_object_id=pg_temp.s5('Solution2')
  and vo.voting_session_id=pg_temp.s5('Voting') and opt.decision_id=d.id and opt.selected
  and record0.artifact_id=pg_temp.s5('Record') and input0.activity_instance_id=pg_temp.s5('Downstream'));
 assert v.status='CURRENT' and v.content_snapshot#>>'{decision,reasoning}'=d.reasoning;
 assert v.content_snapshot#>>'{decision,outcome}'=d.outcome and (v.content_snapshot#>>'{decision,decidedAt}')::timestamptz=d.decided_at;
 assert not v.content_snapshot ? 'votes' and not v.content_snapshot::text like '%voter%';
 assert exists(select 1 from public.artifact_decision_sources where artifact_id=pg_temp.s5('Record') and decision_id=d.id and artifact_version_id=v.id);
 assert exists(select 1 from public.artifact_object_links where artifact_id=pg_temp.s5('Record') and artifact_version_id=v.id and development_object_id=pg_temp.s5('Solution2') and role_in_artifact='SELECTED_DECISION_OBJECT');
 assert exists(select 1 from public.activity_outputs where activity_instance_id=pg_temp.s5('Activity') and artifact_id=pg_temp.s5('Record'));
 assert exists(select 1 from public.activity_inputs where activity_instance_id=pg_temp.s5('Downstream') and artifact_id=pg_temp.s5('Record') and artifact_version_id=v.id);
 assert (select status='active' from public.activity_instances where id=pg_temp.s5('Activity'));
 assert (select objects from public.m1018_preserved)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
 assert (select banks from public.m1018_preserved)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a where id in(pg_temp.s5('ProblemBank'),pg_temp.s5('SolutionBank')));
 assert (select bank_versions from public.m1018_preserved)=(select jsonb_agg(to_jsonb(vv) order by id) from public.artifact_versions vv where artifact_id in(pg_temp.s5('ProblemBank'),pg_temp.s5('SolutionBank')));
 assert (select baselines from public.m1018_preserved) is not distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b);
 assert (select count(*) from public.artifacts)=(select artifact_count+1 from public.m1018_preserved);
 assert (select count(*) from public.artifact_versions where artifact_id=pg_temp.s5('Record'))=1;
 assert (select count(*) from public.development_objects where id in(select id from public.m1018_ids where label in('Problem1','Problem2','Problem3','Solution1','Solution2','Solution3')))=6;
end $$;
commit;
select 'M10.18 Session4-current-inputs/canonical-IDs/vote-limit/top-advisory/non-top-human/TDR/M8/dependencies/no-clones/no-baseline PASS';
