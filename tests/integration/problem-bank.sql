set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into pb_results values('P1',public.compose_problem_bank(pg_temp.pb_activity('Personal'),pg_temp.pb_ids('P'),'Custom Bank'));
insert into pb_results values('P2',public.compose_problem_bank(pg_temp.pb_activity('Personal'),(pg_temp.pb_ids('P'))[1:2],'Ignored rename'));
insert into pb_results values('P3',public.compose_problem_bank(pg_temp.pb_activity('Personal'),(pg_temp.pb_ids('P'))[1:2]));
do $$declare ids uuid[]:=pg_temp.pb_ids('P');begin
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),'{}');raise exception 'Empty accepted';exception when invalid_parameter_value then null;end;
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),array[ids[1],ids[1]]);raise exception 'Duplicate accepted';exception when invalid_parameter_value then null;end;
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),array[gen_random_uuid()]);raise exception 'Missing accepted';exception when insufficient_privilege then null;end;
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),pg_temp.pb_ids('R'));raise exception 'Another Activity accepted';exception when insufficient_privilege then null;end;
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),pg_temp.pb_ids('T'));raise exception 'Foreign workspace accepted';exception when insufficient_privilege then null;end;
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),array[(select (payload->>'id')::uuid from logged_objects where label='Problem')]);raise exception 'Unregistered accepted';exception when insufficient_privilege then null;end;
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),array[(select (payload->>'id')::uuid from logged_objects where label='Solution')]);raise exception 'Solution accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Team'),pg_temp.pb_ids('B'));raise exception 'Team B source accepted';exception when insufficient_privilege then null;end;
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Team'),pg_temp.pb_ids('P'));raise exception 'Personal source accepted';exception when insufficient_privilege then null;end;
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Team'),array[(select (payload->>'id')::uuid from logged_objects where label='Case')]);raise exception 'Foreign Project accepted';exception when insufficient_privilege then null;end;
end $$;
-- A generic M8-created Bank cannot downgrade snapshot-derived requirements.
do $$declare generic jsonb;begin
 begin
  generic:=public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),'PROBLEM_BANK','Mismatched requirements',pg_temp.pb_activity('Team'),false,false);
  perform public.compose_problem_bank(pg_temp.pb_activity('Team'),pg_temp.pb_ids('T'));
  raise exception 'Existing Bank requirements bypass';
 exception when insufficient_privilege then null;end;
end $$;
insert into pb_results values('T1',public.compose_problem_bank(pg_temp.pb_activity('Team'),pg_temp.pb_ids('T')));
do $$declare p public.development_projects;begin
 select * into p from public.development_projects where id=(select (payload->>'id')::uuid from logged_projects where label='Team');
 assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000980806',p.id,p.primary_workspace_id,p.owner_team_id)->>'satisfied'='false','Draft approval bypass';
 assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000980807',p.id,p.primary_workspace_id,p.owner_team_id)->>'satisfied'='true','Available Bank';
end $$;
insert into pb_results select 'Submission',public.submit_artifact((payload #>> '{artifact,id}')::uuid,(payload #>> '{version,id}')::uuid,pg_temp.pb_activity('Team')) from pb_results where label='T1';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((payload->>'id')::uuid) from pb_results where label='Submission';
select public.approve_artifact((payload->>'id')::uuid) from pb_results where label='Submission';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare p public.development_projects;begin
 select * into p from public.development_projects where id=(select (payload->>'id')::uuid from logged_projects where label='Team');
 assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000980806',p.id,p.primary_workspace_id,p.owner_team_id)->>'satisfied'='true','Approved Bank dependency';
end $$;
insert into pb_results values('T2',public.compose_problem_bank(pg_temp.pb_activity('Team'),(pg_temp.pb_ids('T'))[1:2]));
-- M9.14: generic resume references the stable Bank and original Objects.
do $$declare resumed jsonb;before0 jsonb;begin
 resumed:=public.resume_activity(pg_temp.pb_activity('Team'));
 assert jsonb_array_length(resumed->'outputs')>=4;
 assert (select count(*) from jsonb_array_elements(resumed->'outputs') x where x->>'output_type'='artifact' and x->>'artifact_id'=(select payload#>>'{artifact,id}' from pb_results where label='T1'))=1;
 assert (select count(*) from jsonb_array_elements(resumed->'outputs') x where x->>'output_type'='development_object' and (x->>'development_object_id')::uuid=any(pg_temp.pb_ids('T')))=3;
 before0:=jsonb_build_object('objects',(select count(*) from public.development_objects),'artifacts',(select count(*) from public.artifacts),'links',(select count(*) from public.artifact_object_links),'outputs',(select count(*) from public.activity_outputs));
 assert public.resume_activity(pg_temp.pb_activity('Team'))=resumed;
 assert before0=jsonb_build_object('objects',(select count(*) from public.development_objects),'artifacts',(select count(*) from public.artifacts),'links',(select count(*) from public.artifact_object_links),'outputs',(select count(*) from public.activity_outputs));
end $$;
select 'M9.14 PB resume preserves canonical Bank + individual outputs/no clones PASS';
-- Approved Bank is reused as an exact generic input in a new downstream context.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare p public.development_projects;started jsonb;retried jsonb;resumed jsonb;bank uuid;version0 uuid;begin
 select * into p from public.development_projects where id=(select (payload->>'id')::uuid from logged_projects where label='Team');
 started:=public.start_activity('00000000-0000-4000-8000-000000980806',p.id,p.primary_workspace_id,p.owner_team_id);
 assert started->>'started'='true','Approved Bank did not enable downstream start';
 select (payload#>>'{artifact,id}')::uuid,(payload#>>'{version,id}')::uuid into bank,version0 from pb_results where label='T1';
 perform public.add_activity_artifact_input((started#>>'{activity,id}')::uuid,bank,version0,true);
 resumed:=public.resume_activity((started#>>'{activity,id}')::uuid);
 assert (select count(*) from jsonb_array_elements(resumed->'inputs') i where i->>'input_type'='artifact_version' and i->>'artifact_id'=bank::text and i->>'artifact_version_id'=version0::text)=1;
 retried:=public.start_activity('00000000-0000-4000-8000-000000980806',p.id,p.primary_workspace_id,p.owner_team_id);
 assert retried->>'started'='false' and retried->>'reasonCode'='ACTIVE_INSTANCE_EXISTS' and retried->>'existingActiveInstanceId'=started#>>'{activity,id}','Start duplicate detection lost canonical execution';
 assert public.resume_activity((started#>>'{activity,id}')::uuid)=resumed;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select 'M9.14 PB approved Bank downstream canonical Version input/start retry PASS';


reset role;
select set_config('request.jwt.claim.sub','',true);
do $$declare item record;bank public.artifacts;v public.artifact_versions;expected uuid[];actual uuid[];begin
 for item in select * from pb_results where label in('P1','P2','P3','T1','T2') loop
  select * into bank from public.artifacts where id=(item.payload #>> '{artifact,id}')::uuid;
  select * into v from public.artifact_versions where id=(item.payload #>> '{version,id}')::uuid;
  expected:=pg_temp.pb_ids(left(item.label,1));if item.label in('P2','P3','T2') then expected:=expected[1:2];end if;
  select array_agg(development_object_id order by sequence) into actual from public.artifact_object_links where artifact_version_id=v.id;
  assert actual=expected,'Selection/order changed';
  assert (select array_agg(sequence order by sequence) from public.artifact_object_links where artifact_version_id=v.id)=case when cardinality(expected)=3 then array[1,2,3] else array[1,2] end;
  assert not exists(select 1 from public.artifact_object_links where artifact_version_id=v.id and (role_in_artifact<>'problem' or metadata<>'{}'));
  assert v.content_snapshot=jsonb_build_object('problem_count',cardinality(expected)) and v.draft_revision=0;
  assert (select count(*) from public.activity_outputs where artifact_id=bank.id and output_type='artifact')=1;
  assert v.previous_version_id is not distinct from (select id from public.artifact_versions where artifact_id=bank.id and version_number=v.version_number-1);
  if item.label<>'T1' then assert to_jsonb(v)=item.payload->'version','Prior Version changed';end if;
 end loop;
 assert (select count(*) from public.development_objects)=(select objects from pb_object_counts),'No Object cloning';
 assert (select count(*) from public.development_objects where object_type='SOLUTION')=(select solutions from pb_object_counts),'No Solution behavior';
 assert (select count(distinct payload #>> '{artifact,id}') from pb_results where label like 'P%')=1;
 assert (select count(*) from public.artifact_versions where artifact_id=(select (payload #>> '{artifact,id}')::uuid from pb_results where label='P1'))=3;
 assert (select title from public.artifacts where id=(select (payload #>> '{artifact,id}')::uuid from pb_results where label='P1'))='Custom Bank';
 assert (select review_required and approval_required from public.artifacts where id=(select (payload #>> '{artifact,id}')::uuid from pb_results where label='T1'));
 assert (select count(*) from public.audit_events where event_type='PROBLEM_BANK_COMPOSED')=5;
 assert not exists(select 1 from public.audit_events where event_type='PROBLEM_BANK_COMPOSED' and (metadata<>'{}' or actor_user_id not in('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005')));
 assert not exists(select 1 from pb_sources s join public.development_objects o on o.id=s.id join public.problem_details d on d.development_object_id=o.id where s.object_row<>to_jsonb(o) or s.detail_row<>to_jsonb(d));
 assert (select current_version_id from public.artifacts where id=(select (payload #>> '{artifact,id}')::uuid from pb_results where label='T2'))=(select (payload #>> '{version,id}')::uuid from pb_results where label='T1');
end $$;
-- Lifecycle and global identity hold even through the generic M8 creation path.
do $$begin
 begin
  set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.create_artifact((select (payload #>> '{artifact,project_id}')::uuid from pb_results where label='P1'),(select (payload #>> '{artifact,workspace_id}')::uuid from pb_results where label='P1'),'PROBLEM_BANK','Competing Bank',pg_temp.pb_activity('Personal'),false,false);
  raise exception 'Competing Bank accepted';exception when unique_violation then null;end;
 reset role;
 begin
  update public.artifacts set status='ARCHIVED',archived_at=clock_timestamp() where id=(select (payload #>> '{artifact,id}')::uuid from pb_results where label='P1');
  set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),pg_temp.pb_ids('P'));
  raise exception 'Archived Bank accepted';exception when insufficient_privilege then null;end;
 reset role;
 begin
  update public.development_objects set archived_at=clock_timestamp() where id=(pg_temp.pb_ids('P'))[1];
  set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),pg_temp.pb_ids('P'));
  raise exception 'Archived Problem accepted';exception when insufficient_privilege then null;end;
 reset role;
 begin
  update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=pg_temp.pb_activity('Personal');
  set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),pg_temp.pb_ids('P'));
  raise exception 'Completed Activity accepted';exception when object_not_in_prerequisite_state then null;end;
 reset role;perform set_config('request.jwt.claim.sub','',true);
end $$;
-- Every internal failure point rolls the entire command back, including history.
create function pg_temp.pb_fail() returns trigger language plpgsql as $$begin raise exception 'injected failure' using errcode='P9091';end $$;
create function pg_temp.pb_fingerprint() returns jsonb language sql as $$select jsonb_build_array((select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_object_links x),(select jsonb_agg(to_jsonb(x) order by id) from public.activity_outputs x),(select jsonb_agg(to_jsonb(x) order by id) from public.audit_events x))$$;
do $$declare tab text;before jsonb;begin
 foreach tab in array array['artifact_versions','artifact_object_links','activity_outputs','audit_events'] loop
  before:=pg_temp.pb_fingerprint();
  execute format('create trigger pb_fault before insert on public.%I for each row execute function pg_temp.pb_fail()',tab);
  begin
   set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
   perform public.compose_problem_bank(pg_temp.pb_activity('Rollback'),pg_temp.pb_ids('R'));raise exception 'Fault not reached';
  exception when sqlstate 'P9091' then null;end;
  reset role;perform set_config('request.jwt.claim.sub','',true);
  execute format('drop trigger pb_fault on public.%I',tab);
  assert before=pg_temp.pb_fingerprint(),'Partial composition survived failure';
 end loop;
end $$;
-- Exact IDs, role-alone callers and removal never bypass current scope.
set local role authenticated;
do $$declare actor text;begin
 foreach actor in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor,true);
  begin perform public.compose_problem_bank(pg_temp.pb_activity('Personal'),pg_temp.pb_ids('P'));raise exception 'Private bypass';exception when insufficient_privilege then null;end;
  begin perform public.compose_problem_bank(pg_temp.pb_activity('Team'),pg_temp.pb_ids('T'));raise exception 'Role/scope bypass';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006004',null) from acceptance_teams where label='A';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.compose_problem_bank(pg_temp.pb_activity('Team'),pg_temp.pb_ids('T'));raise exception 'Removed bypass';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.artifacts where id=(select (payload #>> '{artifact,id}')::uuid from pb_results where label='T1'));
 assert not exists(select 1 from public.artifact_object_links where artifact_id=(select (payload #>> '{artifact,id}')::uuid from pb_results where label='T1'));
 begin insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id) select (payload #>> '{artifact,id}')::uuid,(payload #>> '{version,id}')::uuid,(pg_temp.pb_ids('T'))[1] from pb_results where label='T1';raise exception 'Direct link insert';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin
 assert (select prosecdef and proconfig @> array['search_path=""'] and proargnames=array['target_instance','problem_ids','bank_title']::text[] from pg_proc where oid='public.compose_problem_bank(uuid,uuid[],text)'::regprocedure);
 assert not has_function_privilege('anon','public.compose_problem_bank(uuid,uuid[],text)','EXECUTE');
 assert not has_function_privilege('service_role','public.compose_problem_bank(uuid,uuid[],text)','EXECUTE');
 assert has_function_privilege('authenticated','public.compose_problem_bank(uuid,uuid[],text)','EXECUTE');
end $$;
rollback;
select 'M9.11 Problem Bank composition identity/version/order/source/history/rollback/privacy/dependency PASS';
