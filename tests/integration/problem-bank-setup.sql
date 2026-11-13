reset role;
update public.teams set status='active' where id in(select (payload->>'teamId')::uuid from acceptance_teams);
create temporary table pb_activities(label text primary key,payload jsonb);
create temporary table pb_problems(label text primary key,payload jsonb);
create temporary table pb_results(label text primary key,payload jsonb);
grant select,insert on pb_activities,pb_problems,pb_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into pb_activities select 'Personal',public.start_activity('00000000-0000-4000-8000-000000980801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid) from logged_projects where label='Individual';
insert into pb_activities select 'Rollback',public.start_activity('00000000-0000-4000-8000-000000980808',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid) from logged_projects where label='Individual';
insert into pb_problems select 'R1',public.create_problem_storming_problem((payload #>> '{activity,id}')::uuid,'Rollback Problem','user') from pb_activities where label='Rollback';
insert into pb_problems select 'P'||n,public.create_problem_storming_problem((payload #>> '{activity,id}')::uuid,'Problem '||n,'user') from pb_activities cross join generate_series(1,3)n where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into pb_activities select 'Team',public.start_activity('00000000-0000-4000-8000-000000980802',(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid) from logged_projects p cross join acceptance_teams t where p.label='Team' and t.label='A';
insert into pb_problems select 'T'||n,public.create_problem_storming_problem((payload #>> '{activity,id}')::uuid,'Team problem '||n,'technical') from pb_activities cross join generate_series(1,3)n where label='Team';
reset role;
select set_config('request.jwt.claim.sub','',true);
-- Real isolated Team B scope and canonical Problem output for cross-Team selection attacks.
insert into public.development_projects(id,name,project_type,owner_team_id,primary_workspace_id)
select '00000000-0000-4000-8000-000000911001','Problem Bank Team B fixture','team',(payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid from acceptance_teams where label='B';
insert into public.project_program_links(project_id,program_id,cohort_id) select '00000000-0000-4000-8000-000000911001','00000000-0000-4000-8000-000000000601',id from acceptance_cohorts where label='Test';
insert into public.project_memberships(project_id,user_id,project_role,status,starts_at)
values('00000000-0000-4000-8000-000000911001','00000000-0000-4000-8000-000000006006','participant','active',now());
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.assign_team_lead((payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006006') from acceptance_teams where label='B';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
insert into pb_activities select 'Team B',public.start_activity('00000000-0000-4000-8000-000000980802','00000000-0000-4000-8000-000000911001',(payload->>'workspaceId')::uuid,(payload->>'teamId')::uuid) from acceptance_teams where label='B';
insert into pb_problems select 'B1',public.create_problem_storming_problem((payload #>> '{activity,id}')::uuid,'Private Team B Problem','user') from pb_activities where label='Team B';
reset role;
select set_config('request.jwt.claim.sub','',true);
create temporary table pb_object_counts as select count(*) objects,count(*) filter(where object_type='SOLUTION') solutions from public.development_objects;
create temporary table pb_sources as select o.id,to_jsonb(o) object_row,to_jsonb(d) detail_row from public.development_objects o join public.problem_details d on d.development_object_id=o.id where o.id in(select (payload->>'id')::uuid from pb_problems);
create function pg_temp.pb_activity(which text) returns uuid language sql as $$select (payload #>> '{activity,id}')::uuid from pb_activities where label=which$$;
create function pg_temp.pb_ids(prefix text) returns uuid[] language sql as $$select array_agg((payload->>'id')::uuid order by label desc) from pb_problems where label like prefix||'%'$$;
-- COMPOSITION SCENARIO
