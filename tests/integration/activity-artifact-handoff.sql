-- Runner prepends shared isolated M7 fixture; all writes roll back.
create temporary table artifact_handoff_context as select f.id upstream,c.project,c.workspace,c.team from resumed_fixture f join av_context c on c.label=f.label where f.label='Team';
grant select on artifact_handoff_context to authenticated,anon;
create temporary table artifact_handoff(label text primary key,data jsonb);grant all on artifact_handoff to authenticated;
-- A private Personal Artifact is accessible to its owner only, even when that
-- owner is also a Team participant. No cross-Workspace sharing exists here.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into artifact_handoff select 'personal',public.create_artifact(c.project,c.workspace,'PROBLEM_BANK','Private source',f.id,false,false) from av_context c join resumed_fixture f on f.label=c.label where c.label='Personal';
do $$begin assert (select public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000814802',project,workspace,null)->>'satisfied' from av_context where label='Personal')='true','Personal owner Artifact availability';end$$;
reset role;
create function pg_temp.artifact_deps(def uuid) returns jsonb language sql as $$select public.evaluate_activity_dependencies(def,project,workspace,team) from artifact_handoff_context$$;
create function pg_temp.artifact_candidates(def uuid) returns jsonb language sql as $$select public.list_activity_artifact_candidates(def,project,workspace,team) from artifact_handoff_context$$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into artifact_handoff select 'source',public.create_artifact(project,workspace,'PROBLEM_BANK','Session 4 Problem Bank',upstream,true,true) from artifact_handoff_context;
do $$begin
 assert pg_temp.artifact_deps('00000000-0000-4000-8000-000000740803')->>'satisfied'='false','Draft cannot satisfy approval';
 assert pg_temp.artifact_deps('00000000-0000-4000-8000-000000750805')->>'satisfied'='true','exact Draft-backed Artifact is available';
 assert pg_temp.artifact_deps('00000000-0000-4000-8000-000000750801')->>'satisfied'='false','Artifact availability does not complete Activity';
 assert pg_temp.artifact_deps('00000000-0000-4000-8000-000000750806')->>'satisfied'='false','gate remains unsatisfied';
 assert (select public.start_activity('00000000-0000-4000-8000-000000740803',project,workspace,team)->>'reasonCode' from artifact_handoff_context)='DEPENDENCY_NOT_MET';
end$$;
insert into artifact_handoff select 'availableActivity',public.start_activity('00000000-0000-4000-8000-000000750805',project,workspace,team) from artifact_handoff_context;
insert into artifact_handoff select 'artifactInput',public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='availableActivity'),(data->>'artifactId')::uuid,null,true) from artifact_handoff where label='source';
insert into artifact_handoff select 'output',public.add_activity_artifact_output((select upstream from artifact_handoff_context),(data->>'artifactId')::uuid) from artifact_handoff where label='source';
insert into artifact_handoff select 'outputRetry',public.add_activity_artifact_output((select upstream from artifact_handoff_context),(data->>'artifactId')::uuid) from artifact_handoff where label='source';
insert into artifact_handoff select 'submission',public.submit_artifact((data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,(select upstream from artifact_handoff_context)) from artifact_handoff where label='source';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((data->>'id')::uuid) from artifact_handoff where label='submission';
select public.approve_artifact((data->>'id')::uuid) from artifact_handoff where label='submission';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare before jsonb;after jsonb;begin
 before:=pg_temp.public_fingerprint();
 assert pg_temp.artifact_deps('00000000-0000-4000-8000-000000740803')->>'satisfied'='true','CURRENT satisfies';
 assert pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803')->0->>'artifactVersionId'=(select data->>'initialVersionId' from artifact_handoff where label='source');
 after:=pg_temp.public_fingerprint();assert before=after,'dependency/candidate evaluation read-only';
 assert (select public.resolve_activity_availability('00000000-0000-4000-8000-000000740803',project,workspace,team)->>'available' from artifact_handoff_context)='true';
end$$;
insert into artifact_handoff select 'downstream',public.start_activity('00000000-0000-4000-8000-000000740803',project,workspace,team) from artifact_handoff_context;
insert into artifact_handoff select 'versionInput',public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='downstream'),(data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,true) from artifact_handoff where label='source';
insert into artifact_handoff select 'inputRetry',public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='downstream'),(data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,true) from artifact_handoff where label='source';
reset role;
create temporary table handoff_sources_before as select pg_temp.public_fingerprint() data,(select count(*) from public.artifacts) artifact_count,(select count(*) from public.artifact_versions) version_count;
do $$begin
 assert (select data from artifact_handoff where label='output')=(select data from artifact_handoff where label='outputRetry');
 assert (select data from artifact_handoff where label='versionInput')=(select data from artifact_handoff where label='inputRetry');
 assert (select count(*) from public.project_baseline_items)=0,'no baseline requirement or mutation';
 assert (select status from public.activity_instances where id=(select upstream from artifact_handoff_context))='active','approval does not complete Activity';
 assert (select count(*) from public.activity_inputs where artifact_id=(select (data->>'artifactId')::uuid from artifact_handoff where label='source'))=2;
 assert (select count(*) from public.artifacts where project_id=(select project from artifact_handoff_context))=1,'input/output handoff creates no clone';
 assert (select count(*) from public.artifact_versions where artifact_id=(select (data->>'artifactId')::uuid from artifact_handoff where label='source'))=1,'no cloned Version';
end$$;
-- Rollback after actual association insertion, not merely failed validation.
create function pg_temp.fail_handoff() returns trigger language plpgsql as $$begin raise exception 'Injected handoff failure' using errcode='P0002';end$$;
do $$declare before jsonb;begin
 before:=pg_temp.public_fingerprint();
 create trigger fail_handoff after insert on public.activity_inputs for each row execute function pg_temp.fail_handoff();
 begin perform public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='availableActivity'),(select (data->>'artifactId')::uuid from artifact_handoff where label='source'),(select (data->>'initialVersionId')::uuid from artifact_handoff where label='source'),true);raise exception 'Missing input failure';exception when no_data_found then null;end;
 drop trigger fail_handoff on public.activity_inputs;
 assert before=pg_temp.public_fingerprint(),'input rollback/source unchanged';
end$$;
set local role authenticated;
-- Additional matching candidate does not trigger automatic selection/linking.
insert into artifact_handoff select 'second',public.create_artifact(project,workspace,'PROBLEM_BANK','Second candidate',upstream,false,false) from artifact_handoff_context;
insert into artifact_handoff select 'wrongType',public.create_artifact(project,workspace,'SOLUTION_BANK','Wrong type',upstream,false,false) from artifact_handoff_context;
insert into artifact_handoff select 'wrongUpstream',public.create_artifact(project,workspace,'PROBLEM_BANK','Different upstream',(select (data->'activity'->>'id')::uuid from artifact_handoff where label='availableActivity'),false,false) from artifact_handoff_context;
reset role;
do $$declare before jsonb;begin
 before:=pg_temp.public_fingerprint();
 create trigger fail_handoff after insert on public.activity_outputs for each row execute function pg_temp.fail_handoff();
 begin perform public.add_activity_artifact_output((select upstream from artifact_handoff_context),(select (data->>'artifactId')::uuid from artifact_handoff where label='wrongType'));raise exception 'Missing output failure';exception when no_data_found then null;end;
 drop trigger fail_handoff on public.activity_outputs;
 assert before=pg_temp.public_fingerprint(),'output rollback/source unchanged';
end$$;
set local role authenticated;
do $$begin assert jsonb_array_length(pg_temp.artifact_candidates('00000000-0000-4000-8000-000000750805'))=2,'return all exact candidates without guessing';end$$;
insert into artifact_handoff select 'v2',public.create_artifact_version((data->>'artifactId')::uuid,'{"new":true}','Replacement') from artifact_handoff where label='source';
insert into artifact_handoff select 'submission2',public.submit_artifact((data->>'artifact_id')::uuid,(data->>'id')::uuid,(select upstream from artifact_handoff_context)) from artifact_handoff where label='v2';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((data->>'id')::uuid) from artifact_handoff where label='submission2';select public.approve_artifact((data->>'id')::uuid) from artifact_handoff where label='submission2';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803')->0->>'artifactVersionId'=(select data->>'id' from artifact_handoff where label='v2');
 assert (select artifact_version_id from public.activity_inputs where id=(select (data->>'id')::uuid from artifact_handoff where label='versionInput'))=(select (data->>'initialVersionId')::uuid from artifact_handoff where label='source'),'historical input not retargeted';
 begin perform public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='availableActivity'),(select (data->>'artifactId')::uuid from artifact_handoff where label='source'),(select (data->>'initialVersionId')::uuid from artifact_handoff where label='source'),true);raise exception 'SUPERSEDED input';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='downstream'),(select (data->>'artifactId')::uuid from artifact_handoff where label='second'),(select (data->>'initialVersionId')::uuid from artifact_handoff where label='second'),true);raise exception 'Draft input';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_artifact_output((select (data->'activity'->>'id')::uuid from artifact_handoff where label='downstream'),(select (data->>'artifactId')::uuid from artifact_handoff where label='source'));raise exception 'Rewritten output provenance';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='downstream'),(select (data->>'artifactId')::uuid from artifact_handoff where label='wrongType'),null,true);raise exception 'Wrong type';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='downstream'),(select (data->>'artifactId')::uuid from artifact_handoff where label='personal'),null,true);raise exception 'Private Personal into Team';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='availableActivity'),(select (data->>'artifactId')::uuid from artifact_handoff where label='wrongUpstream'),null,true);raise exception 'Wrong upstream same Project/type';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='downstream'),(select (data->>'artifactId')::uuid from artifact_handoff where label='source'),gen_random_uuid(),true);raise exception 'Mismatched Version';exception when insufficient_privilege then null;end;
end$$;
reset role;
-- Trusted malformed rows prove shape/FK/history guards, beyond revoked grants.
do $$declare i uuid;a uuid;v uuid;begin
 select (data->'activity'->>'id')::uuid into i from artifact_handoff where label='downstream';select (data->>'artifactId')::uuid into a from artifact_handoff where label='source';
 select (data->>'initialVersionId')::uuid into v from artifact_handoff where label='second';
 begin insert into public.activity_inputs(activity_instance_id,input_type,artifact_id,artifact_version_id,required) values(i,'artifact_version',a,v,true);raise exception 'Foreign Version FK';exception when foreign_key_violation then null;end;
 begin update public.activity_inputs set artifact_version_id=v where artifact_id=a;raise exception 'Historical retarget';exception when check_violation then null;end;
 begin delete from public.activity_inputs where artifact_id=a;raise exception 'Historical delete';exception when check_violation then null;end;
end$$;
-- More than one compatible upstream execution has no approved selector policy.
do $$declare c record;begin
 select * into c from artifact_handoff_context;
 begin
 insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,completed_at,configuration_snapshot)
 select activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,'completed',clock_timestamp(),configuration_snapshot from public.activity_instances where id=c.upstream;
 assert pg_temp.artifact_deps('00000000-0000-4000-8000-000000740803')->>'satisfied'='false','ambiguous upstream denied';
 assert pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803')='[]'::jsonb,'ambiguous upstream exposes no candidates';
 raise exception 'Undo isolated ambiguity fixture' using errcode='P0002';exception when no_data_found then null;end;
end$$;
-- Team B has a real CURRENT same-type Artifact, through the same approved
-- workflow. Even a caller authorized for both Teams cannot cross their scopes.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into acceptance_teams values('Handoff B',public.create_team((select id from acceptance_cohorts where label='Availability'),'Handoff Team B',null,'00000000-0000-4000-8000-000000006004'));
reset role;
update public.teams set status='active' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='Handoff B');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects select 'Handoff B',public.create_development_project('Handoff B','team',(payload->>'workspaceId')::uuid,null,null,(payload->>'teamId')::uuid) from acceptance_teams where label='Handoff B';
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006004' from logged_projects where label='Handoff B';
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Availability') from logged_projects where label='Handoff B';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into artifact_handoff select 'TeamBActivity',public.start_activity('00000000-0000-4000-8000-000000740801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,(payload->>'owner_team_id')::uuid) from logged_projects where label='Handoff B';
insert into artifact_handoff select 'TeamBArtifact',public.create_artifact((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','Foreign approved source',(f.data->'activity'->>'id')::uuid,true,true) from logged_projects p cross join artifact_handoff f where p.label='Handoff B' and f.label='TeamBActivity';
insert into artifact_handoff select 'TeamBSubmission',public.submit_artifact((data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,(select (data->'activity'->>'id')::uuid from artifact_handoff where label='TeamBActivity')) from artifact_handoff where label='TeamBArtifact';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((data->>'id')::uuid) from artifact_handoff where label='TeamBSubmission';select public.approve_artifact((data->>'id')::uuid) from artifact_handoff where label='TeamBSubmission';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='downstream'),(select (data->>'artifactId')::uuid from artifact_handoff where label='TeamBArtifact'),(select (data->>'initialVersionId')::uuid from artifact_handoff where label='TeamBArtifact'),true);raise exception 'Cross Team despite both memberships';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_artifact_input((select (data->'activity'->>'id')::uuid from artifact_handoff where label='downstream'),(select (data->>'artifactId')::uuid from artifact_handoff where label='personal'),null,true);raise exception 'Own Personal into Team';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not exists(select 1 from jsonb_array_elements(pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803')) c where c->>'artifactId'=(select data->>'artifactId' from artifact_handoff where label='TeamBArtifact')),'Team B candidate hidden';end$$;
reset role;
-- Archive changes new evaluation, never stored references or Activity state.
set local role authenticated;select public.archive_artifact((data->>'artifactId')::uuid) from artifact_handoff where label='source';
do $$begin assert pg_temp.artifact_deps('00000000-0000-4000-8000-000000740803')->>'satisfied'='false','archived approved Artifact cannot unlock';end$$;
reset role;
-- Removed and unrelated actors cannot enumerate or fabricate associations.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member(team,'00000000-0000-4000-8000-000000006005',null) from artifact_handoff_context;
set local role authenticated;
do $$declare n integer;i uuid;a uuid;begin
 select (data->'activity'->>'id')::uuid into i from artifact_handoff where label='downstream';select (data->>'artifactId')::uuid into a from artifact_handoff where label='second';
 foreach n in array array[6003,6005,6006] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 assert not exists(select 1 from public.activity_inputs where artifact_id=a),'foreign/removed input hidden';
 begin perform pg_temp.artifact_candidates('00000000-0000-4000-8000-000000740803');raise exception 'Candidate leak';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_artifact_input(i,a,null,true);raise exception 'Removed/foreign input';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_artifact_output((select upstream from artifact_handoff_context),a);raise exception 'Removed/foreign output';exception when insufficient_privilege then null;end;
 begin insert into public.activity_inputs(activity_instance_id,input_type,artifact_id,required) values(i,'artifact',a,true);raise exception 'Direct insert';exception when insufficient_privilege then null;end;
 begin update public.activity_inputs set required=false;raise exception 'Direct update';exception when insufficient_privilege then null;end;
 begin delete from public.activity_inputs;raise exception 'Direct delete';exception when insufficient_privilege then null;end;
 end loop;
end$$;
reset role;
do $$begin assert (select count(*) from public.activity_inputs where artifact_id is not null)=2,'history remains';assert (select count(*) from public.project_baseline_items)=0;end$$;
select 'M8.14 AT-ACT-004 formal / AT-CUR-001 Problem Bank reuse / Artifact availability / privacy / rollback PASS';
rollback;
