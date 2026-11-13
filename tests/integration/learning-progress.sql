\set ON_ERROR_STOP on
create function pg_temp.check_progress(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'M15.24: %',label;end if;end$$;
create function pg_temp.progress0() returns jsonb language sql as $$
 select public.get_my_learning_progress(
 (select (payload->>'id')::uuid from public.current_work_fixture where label='Project Team'),
 (select (payload->>'workspaceId')::uuid from public.current_work_fixture where label='Team A'),
 (select cohort_id from public.teams where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A')),
 (select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A'));
$$;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.add_activity_input((select (payload->>'id')::uuid from public.current_work_fixture where label='Instance Team'),
 (select id from public.development_objects where project_id=(select (payload->>'id')::uuid from public.current_work_fixture where label='Project Team') and object_type='PROBLEM' order by id limit 1),false);
select pg_temp.check_progress(pg_temp.progress0()=jsonb_build_object('requiredActivitiesTotal',4,'completedRequiredActivities',0,'inProgressActivities',2,'blockedActivities',1,'notStartedActivities',1,'optionalActivities',jsonb_build_object('total',0,'completed',0),'completionPercentage',0),'default required includes locked/future Definitions, distinct instances and revision/submission are not completion');
-- These actors know every exact fixture identifier, but have no self execution scope.
do $$declare uid text;begin
 foreach uid in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',uid,true);
  perform pg_temp.check_progress(pg_temp.progress0() is null,'role-only/cross-Team direct-ID denied');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
end$$;
reset role;
-- Isolated fixture status transitions; all rolled back. No canonical output or
-- approval changes count as Activity completion.
update public.activity_instances set status='completed',completed_at=clock_timestamp()
 where id=(select (payload->>'id')::uuid from public.current_work_fixture where label='Instance Team');
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,completed_at,status,configuration_snapshot)
 select activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,completed_at,'completed',configuration_snapshot
 from public.activity_instances where id=(select (payload->>'id')::uuid from public.current_work_fixture where label='Instance Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.check_progress((pg_temp.progress0()->>'completedRequiredActivities')::int=1 and (pg_temp.progress0()->>'requiredActivitiesTotal')::int=4 and (pg_temp.progress0()->>'completionPercentage')::numeric=25,'completed repeated history counts Definition once; no weighting');
reset role;
-- Fresh draft curricula exercise configuration without rewriting approved history.
do $$declare cv uuid;sid uuid;cid uuid;program0 uuid;mode0 text;cfg jsonb;result jsonb;aid uuid;project0 uuid;workspace0 uuid;team0 uuid;created0 jsonb;
begin
 select cohort_id into cid from public.teams where id=(select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A');
 select program_id into program0 from public.cohorts where id=cid;
 select (payload->>'id')::uuid into project0 from public.current_work_fixture where label='Project Team';
 select (payload->>'workspaceId')::uuid,(payload->>'teamId')::uuid into workspace0,team0 from public.current_work_fixture where label='Team A';
 foreach mode0 in array array['mixed','zero','bad_string','bad_null','bad_object','unknown'] loop
  insert into public.curriculum_versions(program_id,version_label,status) values(program0,'M15.24 '||mode0,'draft') returning id into cv;
  insert into public.session_definitions(curriculum_version_id,session_number,title,description,learning_goal,sequence,status) values(cv,99,'Future private curriculum','fixture','Progress fixture',1,'active') returning id into sid;
  cfg:=case mode0 when 'bad_string' then '{"learning_progress":{"required":"false"}}'::jsonb
   when 'bad_null' then '{"learning_progress":{"required":null}}'::jsonb
   when 'bad_object' then '{"learning_progress":null}'::jsonb
   when 'unknown' then '{"learning_progress":{"weight":2}}'::jsonb
   else '{"learning_progress":{"required":false}}'::jsonb end;
  insert into public.activity_definitions(session_definition_id,name,method_type,workspace_mode,sequence,status,configuration)
   values(sid,'Private optional label','custom','Team Workspace',1,'active',cfg) returning id into aid;
  if mode0='mixed' then
   insert into public.activity_definitions(session_definition_id,name,method_type,workspace_mode,sequence,status,configuration) values
    (sid,'Required default','custom','Team Workspace',2,'active','{}'),
    (sid,'Required explicit','custom','Team Workspace',3,'active','{"learning_progress":{"required":true}}'),
    (sid,'Disabled malformed','custom','Team Workspace',4,'inactive','{"learning_progress":null}'),
    (sid,'Other execution mode','custom','Personal Workspace',5,'active','{}'),
    (sid,'Required nested default','custom','Team Workspace',6,'active','{"learning_progress":{}}'),
    (sid,'Instructor only','custom','Case Study Workspace',7,'active','{}');
  end if;
  update public.curriculum_versions set status='approved' where id=cv;
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
  cid:=(public.create_cohort(program0,cv,'M15.24 '||mode0,'2026-10-01',null,'00000000-0000-4000-8000-000000006002','active','{}')->>'id')::uuid;
  insert into public.enrollments(cohort_id,user_id,enrollment_role,status) values
   (cid,'00000000-0000-4000-8000-000000006004','participant','active'),(cid,'00000000-0000-4000-8000-000000006005','participant','active');
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
  created0:=public.create_team(cid,'M15.24 '||mode0);
  team0:=(created0->>'teamId')::uuid;workspace0:=(created0->>'workspaceId')::uuid;
  perform public.add_team_member(team0,'00000000-0000-4000-8000-000000006004','member');
  perform public.add_team_member(team0,'00000000-0000-4000-8000-000000006005','team_lead');
  update public.teams set status='active' where id=team0;
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
  project0:=(public.create_development_project('M15.24 '||mode0,'team',workspace0,null,null,team0)->>'id')::uuid;
  insert into public.project_memberships(project_id,user_id) values(project0,'00000000-0000-4000-8000-000000006004'),(project0,'00000000-0000-4000-8000-000000006005') on conflict do nothing;
  -- Trusted disposable participation fixture, matching the existing M8 Team
  -- fixture. Scoped Master provisioning does not grant private Project reads.
  insert into public.project_program_links(project_id,program_id,cohort_id) values(project0,program0,cid);
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  if mode0 in ('mixed','zero') then
   result:=public.get_my_learning_progress(project0,workspace0,cid,team0);
   perform pg_temp.check_progress((result->>'requiredActivitiesTotal')::int=case when mode0='mixed' then 3 else 0 end,'exact active/applicable required denominator');
   perform pg_temp.check_progress(result->'optionalActivities'=jsonb_build_object('total',1,'completed',0),'explicit optional separate');
   if mode0='zero' then perform pg_temp.check_progress(result->'completionPercentage'='null'::jsonb,'zero denominator null');end if;
   insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,completed_at,status,configuration_snapshot)
    values(aid,cid,project0,workspace0,team0,'00000000-0000-4000-8000-000000006005',clock_timestamp(),clock_timestamp(),'completed','{}');
   result:=public.get_my_learning_progress(project0,workspace0,cid,team0);
   perform pg_temp.check_progress(result->'optionalActivities'=jsonb_build_object('total',1,'completed',1) and (result->>'completedRequiredActivities')::int=0,'optional completion does not inflate numerator');
   if mode0='mixed' then
    insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,completed_at,status,configuration_snapshot)
     select a.id,cid,project0,workspace0,team0,'00000000-0000-4000-8000-000000006005',clock_timestamp(),clock_timestamp(),'completed','{}' from public.activity_definitions a where a.session_definition_id=sid and a.sequence=2;
    result:=public.get_my_learning_progress(project0,workspace0,cid,team0);perform pg_temp.check_progress((result->>'completionPercentage')::numeric=33.3,'one decimal deterministic rounding');
    insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,completed_at,status,configuration_snapshot)
     select a.id,cid,project0,workspace0,team0,'00000000-0000-4000-8000-000000006005',clock_timestamp(),clock_timestamp(),'completed','{}' from public.activity_definitions a where a.session_definition_id=sid and a.sequence in (3,6);
    result:=public.get_my_learning_progress(project0,workspace0,cid,team0);perform pg_temp.check_progress((result->>'completionPercentage')::numeric=100 and (result->>'completedRequiredActivities')::int=3,'all required completed');
   end if;
  else
   begin perform public.get_my_learning_progress(project0,workspace0,cid,team0);raise exception 'Malformed configuration accepted';exception when invalid_parameter_value then null;end;
  end if;
 end loop;
end$$;
rollback;
-- Removal/archive tests use the original canonical fixture and roll back.
begin;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from public.current_work_fixture where label='Team A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin if pg_temp.progress0() is not null then raise exception 'Removed member progress leaked';end if;end$$;
rollback;
begin;
update public.development_projects set status='archived',archived_at=clock_timestamp() where id=(select (payload->>'id')::uuid from public.current_work_fixture where label='Project Team');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin if pg_temp.progress0() is not null then raise exception 'Archived context exposed';end if;end$$;
rollback;
select pg_temp.check_progress(not has_function_privilege('anon','public.get_my_learning_progress(uuid,uuid,uuid,uuid)','execute') and not has_function_privilege('service_role','public.get_my_learning_progress(uuid,uuid,uuid,uuid)','execute'),'minimal grants');
\echo M15.24 denominator/configuration/completion/history/privacy checks PASS
