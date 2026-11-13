-- Fresh configured Definitions are started through M7; no historical snapshot rewrite.
reset role;
update public.teams set status='active' where id in (select (payload->>'teamId')::uuid from acceptance_teams);
create temporary table bc_activities(label text primary key,payload jsonb);
create temporary table bc_entries(label text primary key,payload jsonb);
grant select,insert on bc_activities,bc_entries to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into bc_activities select 'Personal',public.start_activity('00000000-0000-4000-8000-000000960801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid) from logged_projects where label='Individual';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into bc_activities select 'Team'||n,public.start_activity(('00000000-0000-4000-8000-'||lpad((960800+n)::text,12,'0'))::uuid,(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid) from logged_projects p cross join acceptance_teams t cross join generate_series(2,7) n where p.label='Team' and t.label='A';
do $$begin
 assert (select count(*) from bc_activities)=7;
 assert not exists(select 1 from bc_activities where payload->>'started' is distinct from 'true'),'Canonical start failed';
 assert (select payload #>> '{activity,configuration_snapshot,configuration,brainstorming,visibility_mode}' from bc_activities where label='Team2')='private_before_reveal';
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
set local role authenticated;
insert into logged_projects values('Brainstorm Team B',public.create_development_project('M9.6 Team B','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='B'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='B')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007');
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006007' from logged_projects where label='Brainstorm Team B';
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test') from logged_projects where label='Brainstorm Team B';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
insert into bc_activities select 'Team B',public.start_activity('00000000-0000-4000-8000-000000960802',(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid) from logged_projects p cross join acceptance_teams t where p.label='Brainstorm Team B' and t.label='B';
insert into bc_entries select 'Team B',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'Team B only','private') from bc_activities where label='Team B';
reset role;
create function pg_temp.bc_outputs() returns jsonb language plpgsql set search_path='' as $$
declare result jsonb:='{}';t text;rows0 jsonb;begin
 foreach t in array array['activity_instances','activity_participants','activity_inputs','activity_outputs','artifacts','artifact_versions','artifact_object_links','submissions','feedback_items','review_actions','project_baseline_items','development_objects','idea_details','problem_details','change_log','audit_events'] loop
 execute format('select coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text),''[]''::jsonb) from public.%I x',t) into rows0;result:=result||jsonb_build_object(t,rows0);end loop;return result;end $$;
create temporary table bc_outputs_before as select pg_temp.bc_outputs() payload;
revoke all on function pg_temp.bc_outputs() from public,anon,authenticated,service_role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into bc_entries select 'A1',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,E'  Exact content\nwithout transformation  ','private') from bc_activities where label='Team2';
insert into bc_entries select 'Personal',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'Personal content','private') from bc_activities where label='Personal';
insert into bc_entries select 'Child',public.create_brainstorm_entry((a.payload #>> '{activity,id}')::uuid,'Own build-on','private',(e.payload->>'id')::uuid) from bc_activities a cross join bc_entries e where a.label='Team2' and e.label='A1';
do $$begin
 assert exists(select 1 from public.brainstorm_entries b join bc_entries e on b.id=(e.payload->>'id')::uuid where e.label='A1' and to_jsonb(b)=e.payload),'Persisted canonical A1 row';
 assert not exists(select 1 from bc_entries where label<>'Team B' and (payload->>'created_by'<>'00000000-0000-4000-8000-000000006004' or payload->>'status'<>'active' or payload->>'revealed_at' is not null or payload->>'archived_at' is not null or payload->>'development_object_id' is not null));
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into bc_entries select 'A2',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'A2 private content','private') from bc_activities where label='Team2';
do $$declare a uuid;bad uuid;err text;missing_err text;begin
 select (payload #>> '{activity,id}')::uuid into a from bc_activities where label='Team2';
 assert exists(select 1 from public.brainstorm_entries b join bc_entries e on b.id=(e.payload->>'id')::uuid where e.label='A2' and to_jsonb(b)=e.payload);
 assert not exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='A1')),'A2 peer read';
 begin perform public.create_brainstorm_entry(a,'Unsafe parent','private',(select (payload->>'id')::uuid from bc_entries where label='A1'));raise exception 'Peer parent allowed';exception when insufficient_privilege then get stacked diagnostics err=message_text;end;
 begin perform public.create_brainstorm_entry(a,'Missing parent','private',gen_random_uuid());raise exception 'Missing parent allowed';exception when insufficient_privilege then get stacked diagnostics missing_err=message_text;end;
 assert err=missing_err and err='Resource unavailable','Parent existence leaked';
 begin perform public.create_brainstorm_entry(a,'Foreign Team B parent','private',(select (payload->>'id')::uuid from bc_entries where label='Team B'));raise exception 'Foreign Team B parent allowed';exception when insufficient_privilege then assert sqlerrm=err;end;
 begin perform public.create_brainstorm_entry(a,'Foreign Personal parent','private',(select (payload->>'id')::uuid from bc_entries where label='Personal'));raise exception 'Foreign parent allowed';exception when insufficient_privilege then assert sqlerrm=err;end;
 foreach bad in array array[(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Team3'),(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Team4'),(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Team6'),(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Team7')] loop
 begin perform public.create_brainstorm_entry(bad,'Unsupported config','private');raise exception 'Config accepted';exception when feature_not_supported then assert sqlerrm='Required Activity configuration unavailable';end;
 end loop;
 begin perform public.create_brainstorm_entry((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Team5'),'Wrong method','private');raise exception 'Custom method accepted';exception when invalid_parameter_value then null;end;
 begin perform public.create_brainstorm_entry(a,'Wrong visibility','shared');raise exception 'Shared accepted';exception when invalid_parameter_value then null;end;
 begin perform public.create_brainstorm_entry(a,null,'private');raise exception 'Null content accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='A2')),'A1 peer read';
 assert exists(select 1 from public.brainstorm_entries b join bc_entries e on b.id=(e.payload->>'id')::uuid where e.label='A1' and b.created_by=auth.uid() and b.revealed_at is null and b.content=E'  Exact content\nwithout transformation  ');
 assert (select payload->>'activity_instance_id' from bc_entries where label='A1')=(select payload->>'activity_instance_id' from bc_entries where label='A2');
 assert (select payload->>'project_id' from bc_entries where label='A1')=(select payload->>'project_id' from bc_entries where label='A2');
 assert (select payload->>'workspace_id' from bc_entries where label='A1')=(select payload->>'workspace_id' from bc_entries where label='A2');
 assert (select payload->>'id' from bc_entries where label='A1')<>(select payload->>'id' from bc_entries where label='A2');
 assert (select payload->>'created_by' from bc_entries where label='A2')='00000000-0000-4000-8000-000000006005';
end $$;
reset role;
do $$begin assert pg_temp.bc_outputs()=(select payload from bc_outputs_before),'Creation mutated canonical outputs/history/Activity';end $$;
-- A trusted own revealed fixture is allowed only under the existing creator read policy.
select set_config('request.jwt.claim.sub','',true);
insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,created_by,content,revealed_at)
select (payload->>'activity_instance_id')::uuid,(payload->>'project_id')::uuid,(payload->>'workspace_id')::uuid,'00000000-0000-4000-8000-000000006004','Trusted revealed fixture',clock_timestamp() from bc_entries where label='A1';
insert into bc_entries select 'Revealed',to_jsonb(b) from public.brainstorm_entries b where content='Trusted revealed fixture';
update public.brainstorm_entries set status='archived',archived_at=clock_timestamp() where id=(select (payload->>'id')::uuid from bc_entries where label='Child');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into bc_entries select 'Own revealed child',public.create_brainstorm_entry((payload->>'activity_instance_id')::uuid,'Still private','private',(payload->>'id')::uuid) from bc_entries where label='Revealed';
do $$declare a uuid;begin select (payload #>> '{activity,id}')::uuid into a from bc_activities where label='Team2';
 begin perform public.create_brainstorm_entry(a,'Archived parent','private',(select (payload->>'id')::uuid from bc_entries where label='Child'));raise exception 'Archived parent accepted';exception when insufficient_privilege then assert sqlerrm='Resource unavailable';end;
 begin insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,created_by,content) select a,(payload->>'project_id')::uuid,(payload->>'workspace_id')::uuid,'00000000-0000-4000-8000-000000006005','Spoof' from bc_entries where label='A1';raise exception 'Direct insert';exception when insufficient_privilege then null;end;
end $$;
-- Team B/ordinary Admin/unrelated Master/Mentor cannot contribute to Team A, and no role bypasses Personal privacy.
do $$declare n int;begin foreach n in array array[6001,6002,6003,6006,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.create_brainstorm_entry((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Team2'),'Unauthorized','private');raise exception 'Unrelated contribution';exception when insufficient_privilege then assert sqlerrm='Resource unavailable';end;
 begin perform public.create_brainstorm_entry((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Personal'),'Personal bypass','private');raise exception 'Personal contribution';exception when insufficient_privilege then null;end;
end loop;end $$;
reset role;
-- Lifecycle failure rolls back the fixture state; no historical snapshot is changed.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare a uuid;begin select (payload #>> '{activity,id}')::uuid into a from bc_activities where label='Team2';
 begin update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=a;perform public.create_brainstorm_entry(a,'Completed write','private');raise exception 'Completed accepted';exception when object_not_in_prerequisite_state then null;end;
 assert (select status from public.activity_instances where id=a)='active';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.create_brainstorm_entry((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Team2'),'Removed','private');raise exception 'Removed author';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='A1'));
 assert exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='Personal'));
end $$;
reset role;
set local role anon;
do $$begin begin perform public.create_brainstorm_entry(gen_random_uuid(),'Anonymous','private');raise exception 'Anonymous RPC';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert not has_function_privilege('service_role','public.create_brainstorm_entry(uuid,text,text,uuid)','EXECUTE');
 assert not has_function_privilege('authenticated','private.require_brainstorm_write(uuid)','EXECUTE');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.create_brainstorm_entry(uuid,text,text,uuid)'::regprocedure);
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='private.require_brainstorm_write(uuid)'::regprocedure);
 assert not has_table_privilege('authenticated','public.brainstorm_entries','INSERT');
 assert (select count(*) from public.brainstorm_entries where id in (select (payload->>'id')::uuid from bc_entries))=(select count(*) from bc_entries),'Canonical identities persist';
 assert not exists(select 1 from public.brainstorm_entries where content='Unauthorized' or content='Removed' or content='Spoof');
end $$;
select 'AT-BRAIN-001 PASS: A1/A2 canonical private creation / reload / exact scope / no peer leakage';
select 'M9.6 parent privacy / snapshot configuration / hostile IDs / removal / no outputs or promotion PASS';
rollback;
