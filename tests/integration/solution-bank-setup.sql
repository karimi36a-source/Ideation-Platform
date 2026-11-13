reset role;
create temporary table sb_activities(label text primary key,payload jsonb);
create temporary table sb_solutions(label text primary key,payload jsonb);
create temporary table sb_results(label text primary key,payload jsonb);
grant select,insert on sb_activities,sb_solutions,sb_results to authenticated;
insert into sb_activities select 'Personal',payload from bc_activities where label='Personal';
insert into sb_activities select 'Team',payload from bc_activities where label='Reveal1';
insert into sb_activities select 'Rollback',payload from bc_activities where label='Reveal Personal';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into sb_solutions select 'P'||n,public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry(case n when 1 then 'Personal' when 2 then 'S2' when 3 then 'S3' when 4 then 'Blank' else 'Race' end),pg_temp.sp_problem(case when n<=3 then 'Problem' else 'P2' end)) from generate_series(1,5)n;
insert into sp_sources select 'BankRollback',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'Rollback source','private') from sb_activities where label='Rollback';
insert into sb_solutions select 'R1',public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('BankRollback'),pg_temp.sp_problem('Problem'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into sb_solutions values('T1',public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Team'),pg_temp.sp_problem('Team')));
-- More real revealed sources in the same Team Activity; reveal through the approved operation.
insert into sp_sources select 'BankTeam'||n,public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'Team Solution '||n,'private') from sb_activities cross join generate_series(2,3)n where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select public.reveal_brainstorm_entries((payload #>> '{activity,id}')::uuid,array(select (payload->>'id')::uuid from sp_sources where label like 'BankTeam%')) from sb_activities where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into sb_solutions select 'T'||n,public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('BankTeam'||n),pg_temp.sp_problem('Team')) from generate_series(2,3)n;
reset role;
-- Isolated trusted foreign-Activity/Team Solution fixture; no invented production records.
insert into public.development_objects(id,project_id,workspace_id,object_type,title,content,created_by)
select '00000000-0000-4000-8000-000000913001',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'SOLUTION','Foreign Solution','Private','00000000-0000-4000-8000-000000006007' from logged_projects where label='Brainstorm Team B';
insert into sb_solutions select 'B1',to_jsonb(o) from public.development_objects o where id='00000000-0000-4000-8000-000000913001';
create temporary table sb_object_counts as select count(*) objects,count(*) filter(where object_type='SOLUTION') solutions from public.development_objects;
create temporary table sb_sources as select o.id,to_jsonb(o) object_row from public.development_objects o;
create temporary table sb_edges as select id,to_jsonb(x) payload from public.development_object_relationships x;
create temporary table sb_brainstorm as select id,to_jsonb(x) payload from public.brainstorm_entries x;
create temporary table sb_object_outputs as select id,to_jsonb(x) payload from public.activity_outputs x where output_type='development_object';
create function pg_temp.sb_activity(which text) returns uuid language sql as $$select (payload #>> '{activity,id}')::uuid from sb_activities where label=which$$;
create function pg_temp.sb_ids(prefix text) returns uuid[] language sql as $$select array_agg((payload->>'id')::uuid order by label desc) from sb_solutions where label like prefix||'%'$$;
