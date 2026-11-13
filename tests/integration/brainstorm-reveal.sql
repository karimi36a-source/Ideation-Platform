-- M9.8 dedicated fixture: ordinary A1/A2, separate Lead, exact Master.
select set_config('request.jwt.claim.sub','',true);
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006009','brainstorm-lead@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006009','active');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
select id,u,'participant','active' from acceptance_cohorts cross join unnest(array['00000000-0000-4000-8000-000000006009'::uuid,'00000000-0000-4000-8000-000000006002'::uuid]) u where label='Test';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009','team_lead');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006002','member');
reset role;
insert into public.project_memberships(project_id,user_id)
select (payload->>'id')::uuid,u from logged_projects cross join unnest(array['00000000-0000-4000-8000-000000006009'::uuid,'00000000-0000-4000-8000-000000006002'::uuid]) u where label='Team';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into bc_activities select 'Reveal'||n,public.start_activity(('00000000-0000-4000-8000-'||lpad((970800+n)::text,12,'0'))::uuid,(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid)
from logged_projects p cross join acceptance_teams t cross join generate_series(1,3) n where p.label='Team' and t.label='A';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into bc_activities select 'Reveal Personal',public.start_activity('00000000-0000-4000-8000-000000970804',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid) from logged_projects where label='Individual';
insert into bc_entries select 'R1',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'A1 reveal source','private') from bc_activities where label='Reveal1';
insert into bc_entries select 'R3',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'Master reveal source','private') from bc_activities where label='Reveal1';
insert into bc_entries select 'R4',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'Rollback source','private') from bc_activities where label='Reveal1';
insert into bc_entries select 'R6',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'Second rollback source','private') from bc_activities where label='Reveal1';
insert into bc_entries select 'R5',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'Archived source','private') from bc_activities where label='Reveal1';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into bc_entries select 'R2',public.create_brainstorm_entry((payload #>> '{activity,id}')::uuid,'A2 reveal source','private') from bc_activities where label='Reveal1';
reset role;
select set_config('request.jwt.claim.sub','',true);
update public.brainstorm_entries set status='archived',archived_at=clock_timestamp() where id=(select (payload->>'id')::uuid from bc_entries where label='R5');
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,team_id,status,configuration_snapshot)
select '00000000-0000-4000-8000-000000970999','00000000-0000-4000-8000-000000970805',i.cohort_id,i.project_id,i.workspace_id,i.team_id,'not_started',public.activity_start_snapshot('00000000-0000-4000-8000-000000970805')
from public.activity_instances i where i.id=(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal1');
create temporary table br_before as select * from public.brainstorm_entries;
create temporary table br_outputs_before as select pg_temp.bc_outputs() payload;
create temporary table br_results(label text primary key,payload jsonb);
grant select,insert on br_results to authenticated;
-- Assertions use trusted fixture IDs; no production metadata is exposed to clients.
set local role authenticated;
do $$declare n integer;a uuid;ids uuid[];begin
 select (payload #>> '{activity,id}')::uuid into a from bc_activities where label='Reveal1';
 select array_agg((payload->>'id')::uuid order by label) into ids from bc_entries where label in('R1','R2');
 foreach n in array array[6004,6005,6001,6003,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.reveal_brainstorm_entries(a,ids);raise exception 'Unauthorized reveal';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 assert exists(select 1 from public.brainstorm_entries where id=ids[1]);assert not exists(select 1 from public.brainstorm_entries where id=ids[2]);
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 assert exists(select 1 from public.brainstorm_entries where id=ids[2]);assert not exists(select 1 from public.brainstorm_entries where id=ids[1]);
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare a uuid;good uuid;bad uuid;state text;begin
 select (payload #>> '{activity,id}')::uuid into a from bc_activities where label='Reveal1';
 select (payload->>'id')::uuid into good from bc_entries where label='R1';
 foreach bad in array array[gen_random_uuid(),(select (payload->>'id')::uuid from bc_entries where label='A1'),(select (payload->>'id')::uuid from bc_entries where label='Team B'),(select (payload->>'id')::uuid from bc_entries where label='Personal'),(select (payload->>'id')::uuid from bc_entries where label='R5')] loop
 begin perform public.reveal_brainstorm_entries(a,array[good,bad]);raise exception 'Mixed invalid accepted';exception when insufficient_privilege then assert sqlerrm='Resource unavailable';end;
 execute 'reset role';
 assert exists(select 1 from public.brainstorm_entries where id=good and revealed_at is null),'Partial reveal';
 execute 'set local role authenticated';
 end loop;
 begin perform public.reveal_brainstorm_entries(a,array[]::uuid[]);raise exception 'Empty';exception when invalid_parameter_value then null;end;
 begin perform public.reveal_brainstorm_entries(a,array[good,good]);raise exception 'Duplicate';exception when invalid_parameter_value then null;end;
 begin perform public.reveal_brainstorm_entries(a,array[good,null]);raise exception 'Null';exception when invalid_parameter_value then null;end;
 -- Missing/unsupported snapshot authority fails closed, without touching any entry.
 foreach a in array array[(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal2'),(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal3'),(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Team3'),(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Team4')] loop
 begin perform public.reveal_brainstorm_entries(a,array[good]);raise exception 'Configuration accepted';exception when feature_not_supported then null;end;
 end loop;
end $$;
-- Forced second-row failure proves statement rollback after a mutation starts.
reset role;
create temporary table br_fail_counter(n integer);
insert into br_fail_counter values(0);
create function pg_temp.br_fail_second() returns trigger language plpgsql as $$begin
 update br_fail_counter set n=n+1;
 if (select n from br_fail_counter)=2 then raise exception 'Injected reveal failure' using errcode='P9098';end if;
 return new;end $$;
create trigger zz_br_fail before update on public.brainstorm_entries for each row execute function pg_temp.br_fail_second();
set local role authenticated;
do $$begin
 begin perform public.reveal_brainstorm_entries((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal1'),array(select (payload->>'id')::uuid from bc_entries where label in('R4','R6')));raise exception 'Injected failure absent';
 exception when sqlstate 'P9098' then null;end;
end $$;
reset role;
drop trigger zz_br_fail on public.brainstorm_entries;
do $$begin assert (select count(*) from public.brainstorm_entries where id in(select (payload->>'id')::uuid from bc_entries where label in('R4','R6')) and revealed_at is null)=2,'Forced rollback failed';end $$;
set local role authenticated;
-- Lead reveals two peer-owned sources. Minimal result, stable order, one timestamp.
insert into br_results select 'Lead',public.reveal_brainstorm_entries((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal1'),array_agg((payload->>'id')::uuid order by label desc)) from bc_entries where label in('R1','R2');
insert into br_results select 'Retry',public.reveal_brainstorm_entries((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal1'),array_agg((payload->>'id')::uuid)) from bc_entries where label in('R1','R2');
do $$begin assert (select payload from br_results where label='Lead')=(select payload from br_results where label='Retry');end $$;
-- Master path requires the same explicit Project/Team access as M7, not role alone.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into br_results select 'Master',public.reveal_brainstorm_entries((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal1'),array_agg((payload->>'id')::uuid)) from bc_entries where label in('R1','R3');
do $$declare n int;a uuid;begin
 select (payload #>> '{activity,id}')::uuid into a from bc_activities where label='Reveal1';
 foreach n in array array[6004,6005,6009,6002] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 assert public.resume_activity(a) is not null and public.resume_activity(a)=public.resume_activity(a),'Revealed resume lost canonical context';
 assert (select count(*) from public.brainstorm_entries where id in(select (payload->>'id')::uuid from bc_entries where label in('R1','R2','R3')))=3,'Revealed pool missing';
 if n<>6004 then assert not exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='Personal')),'Pool broadened Personal access';end if;
 assert not exists(select 1 from public.brainstorm_entries where activity_instance_id=a and created_by<>auth.uid() and revealed_at is null),'Hidden pool leak';
 end loop;
 foreach n in array array[6001,6003,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 assert public.resume_activity(a) is null,'Foreign resume context leak';
 assert not exists(select 1 from public.brainstorm_entries where activity_instance_id=a),'Foreign pool';
 assert not exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='R1')),'Foreign exact';
 assert not exists(select 1 from public.brainstorm_entries where workspace_id=(select (payload->>'workspace_id')::uuid from bc_entries where label='R1')),'Foreign Workspace';
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into bc_entries select 'Peer revealed child',public.create_brainstorm_entry((payload->>'activity_instance_id')::uuid,'Private child from revealed peer','private',(payload->>'id')::uuid) from bc_entries where label='R1';
do $$begin
 assert public.resume_activity((select (payload->>'activity_instance_id')::uuid from bc_entries where label='Peer revealed child')) is not null;
 assert exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='Peer revealed child') and parent_entry_id=(select (payload->>'id')::uuid from bc_entries where label='R1') and revealed_at is null),'Resume lost parent/reveal separation';
end $$;
do $$begin
 begin update public.brainstorm_entries set revealed_at=null where id=(select (payload->>'id')::uuid from bc_entries where label='R1');raise exception 'Unreveal';exception when insufficient_privilege then null;end;
 begin update public.brainstorm_entries set content='Peer edit' where id=(select (payload->>'id')::uuid from bc_entries where label='R1');raise exception 'Shared editing';exception when insufficient_privilege then null;end;
end $$;
-- Personal is not a reveal target, even when it has the approved policy configuration.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.reveal_brainstorm_entries((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal Personal'),array[(select (payload->>'id')::uuid from bc_entries where label='Personal')]);raise exception 'Personal reveal';exception when feature_not_supported then null;end;
 assert exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='Personal'));
end $$;
reset role;
-- Parent, Object/output/history and immutable reveal timestamps are preserved.
select set_config('request.jwt.claim.sub','',true);
do $$declare b public.brainstorm_entries;begin
 assert pg_temp.bc_outputs()=(select payload from br_outputs_before),'Reveal mutated Activity/output/Artifact/audit history';
 assert not exists(select 1 from public.brainstorm_entries current_row join br_before old using(id) where (to_jsonb(current_row)-array['revealed_at','updated_at','updated_by']) is distinct from (to_jsonb(old)-array['revealed_at','updated_at','updated_by'])),'Source/provenance changed';
 select * into b from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='R1');
 begin update public.brainstorm_entries set revealed_at=null where id=b.id;raise exception 'Trusted unreveal';exception when check_violation then null;end;
 begin update public.brainstorm_entries set revealed_at=clock_timestamp() where id=b.id;raise exception 'Trusted timestamp rewrite';exception when check_violation then null;end;
 assert (select count(distinct revealed_at) from public.brainstorm_entries where id in(select (payload->>'id')::uuid from bc_entries where label in('R1','R2')))=1;
end $$;
-- Team B cannot use a revealed Team A entry as parent in its own Activity.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$begin begin perform public.create_brainstorm_entry((select (payload->>'activity_instance_id')::uuid from bc_entries where label='Team B'),'Foreign revealed parent','private',(select (payload->>'id')::uuid from bc_entries where label='R1'));raise exception 'Foreign revealed parent';exception when insufficient_privilege then assert sqlerrm='Resource unavailable';end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin begin perform public.reveal_brainstorm_entries('00000000-0000-4000-8000-000000970999',array[(select (payload->>'id')::uuid from bc_entries where label='R4')]);raise exception 'Not started reveal';exception when object_not_in_prerequisite_state then null;end;end $$;
reset role;
-- Non-active lifecycle never reveals. Exception subtransactions restore fixture states.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare state0 text;a uuid;begin
 select (payload #>> '{activity,id}')::uuid into a from bc_activities where label='Reveal1';
 foreach state0 in array array['submitted','under_review','revision_requested','completed','archived'] loop
 begin
 update public.activity_instances set status=state0::public.activity_instance_status,completed_at=case when state0='completed' then clock_timestamp() else null end where id=a;
 perform public.reveal_brainstorm_entries(a,array[(select (payload->>'id')::uuid from bc_entries where label='R4')]);raise exception 'Lifecycle accepted';
 exception when object_not_in_prerequisite_state then null;end;
 end loop;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009');
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
do $$declare n int;begin foreach n in array array[6004,6009] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 assert not exists(select 1 from public.brainstorm_entries where activity_instance_id=(select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal1'));
 assert not exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='R1')),'Removed exact-ID bypass';
 begin perform public.reveal_brainstorm_entries((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal1'),array[(select (payload->>'id')::uuid from bc_entries where label='R4')]);raise exception 'Removed reveal';exception when insufficient_privilege then null;end;
 end loop;end $$;
reset role;
set local role anon;
do $$begin begin perform public.reveal_brainstorm_entries(gen_random_uuid(),array[gen_random_uuid()]);raise exception 'Anonymous';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert not has_function_privilege('service_role','public.reveal_brainstorm_entries(uuid,uuid[])','EXECUTE');
 assert not has_function_privilege('authenticated','private.require_brainstorm_reveal(uuid)','EXECUTE');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.reveal_brainstorm_entries(uuid,uuid[])'::regprocedure);
 assert not has_table_privilege('authenticated','public.brainstorm_entries','UPDATE');
 assert not has_function_privilege('anon','public.can_read_brainstorm_entry(uuid)','EXECUTE');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='private.require_brainstorm_reveal(uuid)'::regprocedure);
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.can_read_brainstorm_entry(uuid)'::regprocedure);
 assert (select proargnames=array['target_instance','target_entries'] and prorettype='jsonb'::regtype from pg_proc where oid='public.reveal_brainstorm_entries(uuid,uuid[])'::regprocedure),'RPC type/argument parity';
 assert not exists(select 1 from pg_publication_tables where schemaname='public' and tablename='brainstorm_entries');
end $$;
select 'AT-BRAIN-003 PASS: exact Lead/Master reveal / atomic retry / pool RLS / parent / removal / Personal';
rollback;
