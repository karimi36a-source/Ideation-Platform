reset role;
update public.teams set status='active' where id in(select (payload->>'teamId')::uuid from acceptance_teams);
-- Fixture references are test-owned metadata, never a production access path.
create table public.m919_fixture(label text primary key,payload jsonb not null);
grant select,insert,update on public.m919_fixture to authenticated;
insert into public.m919_fixture select 'Project',payload from logged_projects where label='Team';
insert into public.m919_fixture select 'Team',payload from acceptance_teams where label='A';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.m919_fixture select 'ConceptActivity',public.start_activity('00000000-0000-4000-8000-000000919800',(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid) from public.m919_fixture p cross join public.m919_fixture t where p.label='Project' and t.label='Team';
insert into public.m919_fixture select 'Concept',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Concept V2',(select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label='ConceptActivity'),true,true) from public.m919_fixture where label='Project';
insert into public.m919_fixture select 'ConceptV2',to_jsonb(public.create_artifact_version((payload->>'artifactId')::uuid,'{"concept":"Session 4 canonical V2"}','V2 fixture')) from public.m919_fixture where label='Concept';
insert into public.m919_fixture select 'ConceptSubmission',public.submit_artifact((select (payload->>'artifactId')::uuid from public.m919_fixture where label='Concept'),(payload->>'id')::uuid,(select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label='ConceptActivity')) from public.m919_fixture where label='ConceptV2';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((payload->>'id')::uuid) from public.m919_fixture where label='ConceptSubmission';
select public.approve_artifact((payload->>'id')::uuid) from public.m919_fixture where label='ConceptSubmission';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.m919_fixture select 'ProblemActivity',public.start_activity('00000000-0000-4000-8000-000000919801',(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid) from public.m919_fixture p cross join public.m919_fixture t where p.label='Project' and t.label='Team';
select public.add_activity_artifact_input((a.payload#>>'{activity,id}')::uuid,(c.payload->>'artifactId')::uuid,(v.payload->>'id')::uuid,true) from public.m919_fixture a cross join public.m919_fixture c cross join public.m919_fixture v where a.label='ProblemActivity' and c.label='Concept' and v.label='ConceptV2';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into public.m919_fixture select 'Problem'||n,public.create_problem_storming_problem((payload#>>'{activity,id}')::uuid,'Session 4 challenge '||n,(array['user','functional','technical'])[n],'Human perspective') from public.m919_fixture cross join generate_series(1,3)n where label='ProblemActivity';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.m919_fixture select 'ProblemBank',public.compose_problem_bank((payload#>>'{activity,id}')::uuid,array(select (payload->>'id')::uuid from public.m919_fixture where label in('Problem3','Problem2','Problem1') order by label desc)) from public.m919_fixture where label='ProblemActivity';
insert into public.m919_fixture select 'SolutionActivity',public.start_activity('00000000-0000-4000-8000-000000919802',(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid) from public.m919_fixture p cross join public.m919_fixture t where p.label='Project' and t.label='Team';
select public.add_activity_input((a.payload#>>'{activity,id}')::uuid,(p.payload->>'id')::uuid,true) from public.m919_fixture a cross join public.m919_fixture p where a.label='SolutionActivity' and p.label='Problem1';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into public.m919_fixture select 'Entry1',public.create_brainstorm_entry((payload#>>'{activity,id}')::uuid,'Independent solution one','private') from public.m919_fixture where label='SolutionActivity';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.m919_fixture select 'Entry'||n,public.create_brainstorm_entry((payload#>>'{activity,id}')::uuid,'Independent solution '||n,'private') from public.m919_fixture cross join generate_series(2,3)n where label='SolutionActivity';
do $$begin
 assert not exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from public.m919_fixture where label='Entry1')),'Peer premature read';
 assert not exists(select 1 from public.development_objects where origin_reference_id in(select (payload->>'id')::uuid from public.m919_fixture where label like 'Entry%')),'Automatic Solution creation';
 begin perform public.promote_brainstorm_entry_to_solution((select (payload->>'id')::uuid from public.m919_fixture where label='Entry2'),(select (payload->>'id')::uuid from public.m919_fixture where label='Problem1'));raise exception 'Hidden promotion';exception when insufficient_privilege then null;end;
end $$;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.brainstorm_entries where id in(select (payload->>'id')::uuid from public.m919_fixture where label in('Entry2','Entry3')));end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$begin assert not exists(select 1 from public.brainstorm_entries where id in(select (payload->>'id')::uuid from public.m919_fixture where label like 'Entry%'));end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 begin perform public.reveal_brainstorm_entries((select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label='SolutionActivity'),array[(select (payload->>'id')::uuid from public.m919_fixture where label='Entry2'),'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid]);raise exception 'Mixed reveal accepted';exception when insufficient_privilege then null;end;
 assert exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from public.m919_fixture where label='Entry2') and revealed_at is null);
end $$;
insert into public.m919_fixture select 'Reveal',public.reveal_brainstorm_entries((payload#>>'{activity,id}')::uuid,array(select (payload->>'id')::uuid from public.m919_fixture where label like 'Entry%' order by label)) from public.m919_fixture where label='SolutionActivity';
do $$begin assert public.reveal_brainstorm_entries((select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label='SolutionActivity'),array(select (payload->>'id')::uuid from public.m919_fixture where label like 'Entry%' order by label))=(select payload from public.m919_fixture where label='Reveal');end $$;
insert into public.m919_fixture select 'Solution'||n,public.promote_brainstorm_entry_to_solution((e.payload->>'id')::uuid,(p.payload->>'id')::uuid) from public.m919_fixture e cross join public.m919_fixture p cross join generate_series(1,3)n where e.label='Entry'||n and p.label='Problem1';
do $$declare n int;begin for n in 1..3 loop assert public.promote_brainstorm_entry_to_solution((select (payload->>'id')::uuid from public.m919_fixture where label='Entry'||n),(select (payload->>'id')::uuid from public.m919_fixture where label='Problem1'))=(select payload from public.m919_fixture where label='Solution'||n);end loop;end $$;
insert into public.m919_fixture select 'SolutionBank',public.compose_solution_bank((payload#>>'{activity,id}')::uuid,array(select (payload->>'id')::uuid from public.m919_fixture where label in('Solution3','Solution2','Solution1') order by label desc)) from public.m919_fixture where label='SolutionActivity';
do $$declare p jsonb:=(select payload from public.m919_fixture where label='Project');t jsonb:=(select payload from public.m919_fixture where label='Team');begin
 assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000919803',(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,(t->>'teamId')::uuid)->>'satisfied'='false','Draft approval bypass';
 assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000919804',(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,(t->>'teamId')::uuid)->>'satisfied'='true','Draft availability rule';
end $$;
insert into public.m919_fixture select label||'Submission',public.submit_artifact((payload#>>'{artifact,id}')::uuid,(payload#>>'{version,id}')::uuid,(payload#>>'{artifact,activity_instance_id}')::uuid) from public.m919_fixture where label in('ProblemBank','SolutionBank');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((payload->>'id')::uuid) from public.m919_fixture where label in('ProblemBankSubmission','SolutionBankSubmission');
select public.approve_artifact((payload->>'id')::uuid) from public.m919_fixture where label in('ProblemBankSubmission','SolutionBankSubmission');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare p jsonb:=(select payload from public.m919_fixture where label='Project');t jsonb:=(select payload from public.m919_fixture where label='Team');begin
 assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000919803',(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,(t->>'teamId')::uuid)->>'satisfied'='true','Approved handoff';
end $$;
insert into public.m919_fixture select 'Session5',public.start_activity('00000000-0000-4000-8000-000000919803',(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid) from public.m919_fixture p cross join public.m919_fixture t where p.label='Project' and t.label='Team';
select public.add_activity_artifact_input((a.payload#>>'{activity,id}')::uuid,(b.payload#>>'{artifact,id}')::uuid,(b.payload#>>'{version,id}')::uuid,true) from public.m919_fixture a cross join public.m919_fixture b where a.label='Session5' and b.label in('ProblemBank','SolutionBank');

-- Retry input registration and start: reuse canonical execution/links.
select public.add_activity_artifact_input((a.payload#>>'{activity,id}')::uuid,(b.payload#>>'{artifact,id}')::uuid,(b.payload#>>'{version,id}')::uuid,true) from public.m919_fixture a cross join public.m919_fixture b where a.label='Session5' and b.label in('ProblemBank','SolutionBank');
do $$declare retried jsonb;begin
 retried:=public.start_activity('00000000-0000-4000-8000-000000919803',(select (payload->>'id')::uuid from public.m919_fixture where label='Project'),(select (payload->>'primary_workspace_id')::uuid from public.m919_fixture where label='Project'),(select (payload->>'teamId')::uuid from public.m919_fixture where label='Team'));
 assert retried->>'started'='false' and retried->>'existingActiveInstanceId'=(select payload#>>'{activity,id}' from public.m919_fixture where label='Session5');
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
do $$declare n int;b record;a public.activity_instances;begin
 assert (select version_number=2 and status='CURRENT' from public.artifact_versions where id=(select (payload->>'id')::uuid from public.m919_fixture where label='ConceptV2'));
 for b in select * from public.m919_fixture where label in('ProblemActivity','SolutionActivity','Session5') loop
  select * into a from public.activity_instances where id=(b.payload#>>'{activity,id}')::uuid;
  assert a.configuration_snapshot=b.payload#>'{activity,configuration_snapshot}';
  assert a.project_id=(select (payload->>'id')::uuid from public.m919_fixture where label='Project') and a.team_id=(select (payload->>'teamId')::uuid from public.m919_fixture where label='Team');
 end loop;
 for n in 1..3 loop

  assert exists(select 1 from public.development_objects o where o.id=(select (payload->>'id')::uuid from public.m919_fixture where label='Problem'||n) and o.created_by='00000000-0000-4000-8000-000000006004' and o.project_id=(select (payload->>'id')::uuid from public.m919_fixture where label='Project') and o.workspace_id=(select (payload->>'primary_workspace_id')::uuid from public.m919_fixture where label='Project') and o.metadata->>'concept_artifact_version_id'=(select payload->>'id' from public.m919_fixture where label='ConceptV2'));
  assert exists(select 1 from public.problem_details where development_object_id=(select (payload->>'id')::uuid from public.m919_fixture where label='Problem'||n) and problem_category=(array['user','functional','technical'])[n] and priority is null);
  assert (select count(*) from public.development_object_relationships where source_object_id=(select (payload->>'id')::uuid from public.m919_fixture where label='Solution'||n) and target_object_id=(select (payload->>'id')::uuid from public.m919_fixture where label='Problem1') and relationship_type='SOLVES' and status='active')=1;
  assert exists(select 1 from public.development_objects o join public.brainstorm_entries e on e.development_object_id=o.id where o.id=(select (payload->>'id')::uuid from public.m919_fixture where label='Solution'||n) and o.created_by=e.created_by and o.origin_type='BRAINSTORM' and o.origin_reference_id=e.id and o.project_id=e.project_id and o.workspace_id=e.workspace_id and o.status is null and o.verification_status is null);
 end loop;

 assert not exists(select 1 from public.brainstorm_entries e join public.m919_fixture f on e.id=(f.payload->>'id')::uuid where f.label like 'Entry%' and (to_jsonb(e)-array['revealed_at','development_object_id','updated_at','updated_by']) is distinct from (f.payload-array['revealed_at','development_object_id','updated_at','updated_by']));
 assert (select count(*) from public.development_objects where origin_type='PROBLEM_STORMING' and origin_reference_id=(select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label='ProblemActivity'))=3;
 assert (select count(*) from public.development_objects where origin_type='BRAINSTORM' and origin_reference_id in(select (payload->>'id')::uuid from public.m919_fixture where label like 'Entry%'))=3;
 assert (select count(*) from public.artifacts where activity_instance_id in(select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label in('ProblemActivity','SolutionActivity')))=2;
 assert (select count(distinct revealed_at) from public.brainstorm_entries where id in(select (payload->>'id')::uuid from public.m919_fixture where label like 'Entry%'))=1;
 for b in select * from public.m919_fixture where label in('ProblemBank','SolutionBank') loop
  assert (select status='CURRENT' from public.artifact_versions where id=(b.payload#>>'{version,id}')::uuid);
  assert (select current_version_id=(b.payload#>>'{version,id}')::uuid from public.artifacts where id=(b.payload#>>'{artifact,id}')::uuid);
  assert (select array_agg(development_object_id order by sequence) from public.artifact_object_links where artifact_version_id=(b.payload#>>'{version,id}')::uuid)=array(select (payload->>'id')::uuid from public.m919_fixture where label in(case when b.label='ProblemBank' then 'Problem1' else 'Solution1' end,case when b.label='ProblemBank' then 'Problem2' else 'Solution2' end,case when b.label='ProblemBank' then 'Problem3' else 'Solution3' end) order by label desc);
  assert (select count(*) from public.activity_outputs where artifact_id=(b.payload#>>'{artifact,id}')::uuid)=1;
  assert (select count(*) from public.activity_inputs where activity_instance_id=(select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label='Session5') and artifact_id=(b.payload#>>'{artifact,id}')::uuid and artifact_version_id=(b.payload#>>'{version,id}')::uuid)=1;
 end loop;
 assert (select count(*) from public.activity_outputs where activity_instance_id in(select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label in('ProblemActivity','SolutionActivity')) and output_type='development_object')=6;
 assert not exists(select 1 from public.development_objects where id in(select (payload->>'id')::uuid from public.m919_fixture where label like 'Problem%' or label like 'Solution%') and (metadata ?| array['rank','score','winner','preferred_solution','decision']));
 assert (select count(*) from public.artifacts where activity_instance_id=(select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label='ConceptActivity'))=1;
 assert not exists(select 1 from public.decisions);
 -- Later schema foundations may exist; Session 4 must not execute voting.
 assert not exists(select 1 from public.voting_sessions);
 assert not exists(select 1 from public.voting_options);
 assert not exists(select 1 from public.votes);
end $$;
commit;
\echo M9.19 Session4 ConceptV2/three Problems/ordered Banks/three Solutions/SOLVES/M8 approval/Session5 exact Version handoff PASS
