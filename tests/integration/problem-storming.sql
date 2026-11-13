-- Isolated trusted fixture is prepended; no hosted data or canonical seed edits.
reset role;
update public.teams set status='active' where id in(select (payload->>'teamId')::uuid from acceptance_teams);
create temporary table ps_activities(label text primary key,payload jsonb);
create temporary table ps_problems(label text primary key,payload jsonb);
create temporary table ps_concepts(label text primary key,payload jsonb);
grant select,insert on ps_activities,ps_problems,ps_concepts to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ps_activities select 'Personal',public.start_activity('00000000-0000-4000-8000-000000980801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid) from logged_projects where label='Individual';
insert into ps_activities select 'Personal required',public.start_activity('00000000-0000-4000-8000-000000980804',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid) from logged_projects where label='Individual';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into ps_activities select 'Team'||n,public.start_activity(('00000000-0000-4000-8000-'||lpad((980800+n)::text,12,'0'))::uuid,(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid)
from logged_projects p cross join acceptance_teams t cross join unnest(array[2,3,5]) n where p.label='Team' and t.label='A';
do $$begin assert not exists(select 1 from ps_activities where payload->>'started' is distinct from 'true'),'Canonical Problem Storming start failed';end $$;
-- Missing canonical Session 4 input fails before creating anything.
do $$begin begin perform public.create_problem_storming_problem((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Team3'),'Problem','user');raise exception 'Missing Concept accepted';exception when feature_not_supported then null;end;end $$;
-- Prepare CURRENT concepts using trusted disposable M8 fixtures only.
insert into ps_concepts select 'Team1',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Concept V2',null,false,false) from logged_projects where label='Team';
insert into ps_concepts select 'Team2',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Conflicting Concept',null,false,false) from logged_projects where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ps_concepts select 'Personal',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Private Concept',null,false,false) from logged_projects where label='Individual';
reset role;
select set_config('request.jwt.claim.sub','',true);
update public.artifact_versions set status='CURRENT',approved_by='00000000-0000-4000-8000-000000006002',approved_at=now() where id in(select (payload->>'initialVersionId')::uuid from ps_concepts);
update public.artifacts a set current_version_id=(select (payload->>'initialVersionId')::uuid from ps_concepts where (payload->>'artifactId')::uuid=a.id) where id in(select (payload->>'artifactId')::uuid from ps_concepts);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.add_activity_artifact_input((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Team3'),(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,true) from ps_concepts where label='Team1';
do $$begin begin perform public.add_activity_artifact_input((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Team3'),(select (payload->>'artifactId')::uuid from ps_concepts where label='Personal'),(select (payload->>'initialVersionId')::uuid from ps_concepts where label='Personal'),true);raise exception 'Private Concept injected';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.add_activity_artifact_input((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Personal required'),(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,true) from ps_concepts where label='Personal';
reset role;
create temporary table ps_before as select jsonb_build_object('artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),'solutions',(select count(*) from public.development_objects where object_type='SOLUTION')) payload;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ps_problems select c,public.create_problem_storming_problem((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Personal'),'Unchanged human text',c,'Human framing') from unnest(array['user','functional','technical','cost','safety','environmental','accessibility','maintenance']) c;
insert into ps_problems select 'Identical',public.create_problem_storming_problem((payload #>> '{activity,id}')::uuid,'Unchanged human text','user','Human framing') from ps_activities where label='Personal';
insert into ps_problems select 'Personal concept',public.create_problem_storming_problem((payload #>> '{activity,id}')::uuid,'Personal challenge','safety') from ps_activities where label='Personal required';
insert into ps_problems select 'Team',public.create_problem_storming_problem((payload #>> '{activity,id}')::uuid,'Team challenge','technical') from ps_activities where label='Team3';
do $$begin
 begin perform public.create_problem_storming_problem((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Personal'),'Problem','unknown');raise exception 'Invalid category';exception when invalid_parameter_value then null;end;
 begin perform public.create_problem_storming_problem((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Team5'),'Problem','user');raise exception 'Wrong method';exception when invalid_parameter_value then null;end;
end $$;
reset role;
do $$declare item record;o public.development_objects;d public.problem_details;a public.activity_instances;begin
 for item in select * from ps_problems loop
  select * into o from public.development_objects where id=(item.payload->>'id')::uuid;
  select * into d from public.problem_details where development_object_id=o.id;
  select * into a from public.activity_instances where id=o.origin_reference_id;
  assert o.object_type='PROBLEM' and o.origin_type='PROBLEM_STORMING' and o.created_by='00000000-0000-4000-8000-000000006004';
  assert o.project_id=a.project_id and o.workspace_id=a.workspace_id and o.current_version_number=1 and o.archived_at is null and o.status is null and o.verification_status is null;
  assert to_jsonb(o)||jsonb_build_object('problem_details',to_jsonb(d))=item.payload;
  assert d.priority is null;
  assert (select count(*) from public.activity_outputs where activity_instance_id=a.id and development_object_id=o.id and output_type='development_object')=1;
  assert (select count(*) from public.change_log where entity_id=o.id and change_type='OBJECT_CREATED')=1;
 end loop;
 assert (select count(distinct payload->>'id') from ps_problems)=11;
 assert (select payload->>'id' from ps_problems where label='user')<>(select payload->>'id' from ps_problems where label='Identical');
 assert (select payload #>> '{metadata,concept_artifact_version_id}' from ps_problems where label='Team')=(select payload->>'initialVersionId' from ps_concepts where label='Team1');
 assert jsonb_build_object('artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),'solutions',(select count(*) from public.development_objects where object_type='SOLUTION'))=(select payload from ps_before);
end $$;
-- Another current registered concept is an ambiguity, never a guessed winner.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.add_activity_artifact_input((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Team3'),(payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,true) from ps_concepts where label='Team2';
do $$begin begin perform public.create_problem_storming_problem((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Team3'),'Problem','user');raise exception 'Conflicting Concept accepted';exception when unique_violation then null;end;end $$;
-- Generic Team definition explicitly has no required Concept dependency.
insert into ps_problems select 'Generic Team',public.create_problem_storming_problem((payload #>> '{activity,id}')::uuid,'Generic Team challenge','user') from ps_activities where label='Team2';
-- Later context reuses the exact canonical Problem without a clone.
select public.add_activity_input((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Team2'),(select (payload->>'id')::uuid from ps_problems where label='Team'),true);
do $$begin assert exists(select 1 from public.activity_inputs where activity_instance_id=(select (payload #>> '{activity,id}')::uuid from ps_activities where label='Team2') and development_object_id=(select (payload->>'id')::uuid from ps_problems where label='Team'));end $$;
-- M9.14: resolve canonical Concept input and typed Problem output on reuse.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare resumed jsonb;o public.development_objects;begin
 resumed:=public.resume_activity((select (payload#>>'{activity,id}')::uuid from ps_activities where label='Personal required'));
 assert exists(select 1 from jsonb_array_elements(resumed->'inputs') i where i->>'artifact_version_id'=(select payload->>'initialVersionId' from ps_concepts where label='Personal'));
 select * into o from public.development_objects where id=(select (payload->>'id')::uuid from ps_problems where label='Personal concept');
 assert exists(select 1 from jsonb_array_elements(resumed->'outputs') x where x->>'development_object_id'=o.id::text);
 assert exists(select 1 from public.problem_details where development_object_id=o.id);
 assert public.resume_activity((resumed#>>'{activity,id}')::uuid)=resumed;
end $$;
select 'M9.14 Concept input/canonical Problem + typed details resume PASS';
-- Exact IDs and roles never override Personal or Team privacy.
do $$declare actor0 text;label0 text;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  foreach label0 in array array['Personal','Team2'] loop
   begin perform public.create_problem_storming_problem((select (payload #>> '{activity,id}')::uuid from ps_activities where label=label0),'Forbidden','user');raise exception 'Foreign creation';exception when insufficient_privilege then null;end;
  end loop;
 end loop;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
do $$begin
 begin
  update public.activity_instances set status='completed',completed_at=started_at where id=(select (payload #>> '{activity,id}')::uuid from ps_activities where label='Personal');
  set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.create_problem_storming_problem((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Personal'),'Forbidden','user');raise exception 'Completed Activity creation';
 exception when object_not_in_prerequisite_state then null;end;
end $$;
-- Forced output/log/detail failures roll back ALL newly created rows.
create function pg_temp.ps_fail() returns trigger language plpgsql as $$begin raise exception 'Forced failure' using errcode='P9090';end $$;
do $$declare table0 text;before0 jsonb;after0 jsonb;begin
 foreach table0 in array array['problem_details','activity_outputs','change_log'] loop
  execute format('create trigger ps_failure before insert on public.%I for each row execute function pg_temp.ps_fail()',table0);
  select jsonb_build_array((select count(*) from public.development_objects),(select count(*) from public.problem_details),(select count(*) from public.activity_outputs),(select count(*) from public.change_log)) into before0;
  begin
   set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
   perform public.create_problem_storming_problem((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Personal'),'Rollback','user');raise exception 'Failure hook bypassed';
  exception when sqlstate 'P9090' then null;end;
  reset role;
  execute format('drop trigger ps_failure on public.%I',table0);
  select jsonb_build_array((select count(*) from public.development_objects),(select count(*) from public.problem_details),(select count(*) from public.activity_outputs),(select count(*) from public.change_log)) into after0;
  assert before0=after0;
 end loop;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.create_problem_storming_problem((select (payload #>> '{activity,id}')::uuid from ps_activities where label='Team2'),'Forbidden','user');raise exception 'Removed creation';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from ps_problems where label='Team'));
 begin insert into public.problem_details(development_object_id) values((select (payload->>'id')::uuid from ps_problems where label='user'));raise exception 'Direct client mutation';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin
 assert (select count(*) from public.development_objects where origin_type='PROBLEM_STORMING')=12;
 assert (select count(*) from public.problem_details d join public.development_objects o on o.id=d.development_object_id where o.origin_type='PROBLEM_STORMING')=12;
 assert (select prosecdef and proconfig=array['search_path=""'] and proargnames=array['target_instance','problem_content','category','problem_perspective']::text[] and prorettype='jsonb'::regtype from pg_proc where oid='public.create_problem_storming_problem(uuid,text,text,text)'::regprocedure);
 assert has_function_privilege('authenticated','public.create_problem_storming_problem(uuid,text,text,text)','EXECUTE');
 assert not has_function_privilege('service_role','public.create_problem_storming_problem(uuid,text,text,text)','EXECUTE');
 assert not has_function_privilege('anon','public.create_problem_storming_problem(uuid,text,text,text)','EXECUTE');
end $$;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform public.create_problem_storming_problem('00000000-0000-4000-8000-000000999999','Forbidden','user');raise exception 'Anonymous command';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
\echo M9.10 PASS: Personal/Team canonical Problems / eight categories / Concept inputs / output identity / rollback / isolation / no Bank or Solutions
