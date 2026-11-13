reset role;
create temporary table cast_cases(label text primary key,id uuid,option_ids uuid[]);
grant select on cast_cases to authenticated;
insert into cast_cases select 'main',(payload#>>'{session,id}')::uuid,array(select (x->>'id')::uuid from jsonb_array_elements(payload->'options') x order by (x->>'sequence')::int) from vc_results where jsonb_array_length(payload->'options')=3;
insert into cast_cases select 'zero',(payload#>>'{session,id}')::uuid,array(select (x->>'id')::uuid from jsonb_array_elements(payload->'options') x) from vc_results where payload#>>'{session,activity_instance_id}'=(select id::text from vc_activities where n=1) and jsonb_array_length(payload->'options')=2;
-- Extra label option allows a genuine fourth attempt against the total budget.
insert into public.voting_options(voting_session_id,label,sequence) select id,'Fourth',4 from cast_cases where label='main';
update cast_cases set option_ids=option_ids||array(select id from public.voting_options where voting_session_id=cast_cases.id and sequence=4) where label='main';
create temporary table cast_before as select to_jsonb(a) payload from public.activity_instances a;
-- Explicit historical participant fixture: current membership remains decisive.
insert into public.activity_participants(activity_instance_id,user_id,joined_at)
select id,'00000000-0000-4000-8000-000000006004',clock_timestamp() from vc_activities where n=1;
create temporary table cast_participant_before as select to_jsonb(p) payload from public.activity_participants p where p.user_id='00000000-0000-4000-8000-000000006004' and p.activity_instance_id=(select id from vc_activities where n=1);
create temporary table cast_log_before as select count(*) n from public.change_log;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.open_voting_session(id) from cast_cases;
create temporary table cast_sessions_before as select jsonb_agg(to_jsonb(s) order by id) payload from public.voting_sessions s;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006002');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare s uuid;o uuid;x jsonb;n int;begin
 select id,option_ids[1] into s,o from cast_cases where label='main';
 foreach n in array array[0,2,-1] loop
  begin perform public.cast_vote(s,o,n);raise exception 'Invalid value accepted';exception when invalid_parameter_value then null;end;
 end loop;
 x:=public.cast_vote(s,o,1);
 assert x->>'user_id'='00000000-0000-4000-8000-000000006005' and x->>'value'='1' and x->>'created_at' is not null and x->>'revealed_at' is null;
 begin perform public.cast_vote(s,o,1);raise exception 'Duplicate accepted';exception when unique_violation then null;end;
 perform public.cast_vote(s,(select option_ids[2] from cast_cases where label='main'),1);
 perform public.cast_vote(s,(select option_ids[3] from cast_cases where label='main'),1);
 begin perform public.cast_vote(s,(select option_ids[4] from cast_cases where label='main'),1);raise exception 'Fourth accepted';exception when unique_violation then null;end;
 begin perform public.cast_vote((select id from cast_cases where label='zero'),(select option_ids[1] from cast_cases where label='zero'),1);raise exception 'Zero allowed';exception when unique_violation then null;end;
 begin perform public.cast_vote(s,(select option_ids[1] from cast_cases where label='zero'),1);raise exception 'Cross Session accepted';exception when insufficient_privilege then null;end;
end $$;
-- A current Lead and another ordinary member may each vote on the same option.
do $$declare n int;begin foreach n in array array[6009,6004] loop
 perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
 perform public.cast_vote((select id from cast_cases where label='main'),(select option_ids[1] from cast_cases where label='main'),1);
end loop;end $$;
-- Global/instructional roles and contextual mentor membership confer no vote.
do $$declare n int;begin foreach n in array array[6001,6002,6003,6007,6008] loop
 perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
 begin perform public.cast_vote((select id from cast_cases where label='main'),(select option_ids[2] from cast_cases where label='main'),1);raise exception 'Role bypass';exception when insufficient_privilege then null;end;
end loop;end $$;
reset role;
do $$begin
 assert (select count(*) from public.votes)=5;
 assert (select payload from cast_sessions_before)=(select jsonb_agg(to_jsonb(s) order by id) from public.voting_sessions s);
 assert (select count(*) from public.votes where user_id='00000000-0000-4000-8000-000000006005' and voting_session_id=(select id from cast_cases where label='main'))=3;
 assert (select vote_limit from public.voting_sessions where id=(select id from cast_cases where label='main'))=3;
 assert not exists(select 1 from public.votes where voting_option_id=(select option_ids[4] from cast_cases where label='main'));
 assert not exists(select 1 from public.votes where revealed_at is not null or value<>1);
 assert not exists(select payload from cast_before except select to_jsonb(a) from public.activity_instances a);
 assert (select count(*) from public.change_log)=(select n+2 from cast_log_before);
 assert not exists(select 1 from public.voting_sessions where status='CLOSED');
 assert not exists(select 1 from public.decisions);
 assert (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.cast_vote(uuid,uuid,integer)'::regprocedure);
 assert not has_function_privilege('anon','public.cast_vote(uuid,uuid,integer)','execute');
 assert not has_function_privilege('service_role','public.cast_vote(uuid,uuid,integer)','execute');
end $$;
-- Independently joining as member permits an instructional-role user to vote.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006002','member');
select public.cast_vote((select id from cast_cases where label='main'),(select option_ids[2] from cast_cases where label='main'),1);
reset role;
-- Mentor platform role is independent of participant membership context.
insert into public.role_assignments(user_id,role_id,team_id,status,starts_at,assigned_by)
select '00000000-0000-4000-8000-000000006005',r.id,(t.payload->>'teamId')::uuid,'active',now()-interval '1 day','00000000-0000-4000-8000-000000006002' from public.roles r cross join acceptance_teams t where r.code='MENTOR' and t.label='A';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
-- New Session has a fresh budget; independent member + Mentor remains eligible.
reset role;
update public.voting_sessions set vote_limit=3 where id=(select id from cast_cases where label='zero');
set local role authenticated;
select public.cast_vote((select id from cast_cases where label='zero'),(select option_ids[1] from cast_cases where label='zero'),1);
-- Deny direct client CRUD, including hidden/peer SELECT.
do $$begin
 begin perform 1 from public.votes;raise exception 'Vote read bypass';exception when insufficient_privilege then null;end;
 begin insert into public.votes(voting_session_id,voting_option_id,user_id,value) select id,option_ids[4],'00000000-0000-4000-8000-000000006005',1 from cast_cases where label='main';raise exception 'Direct insert bypass';exception when insufficient_privilege then null;end;
 begin update public.votes set value=2;raise exception 'Update bypass';exception when insufficient_privilege then null;end;
 begin delete from public.votes;raise exception 'Delete bypass';exception when insufficient_privilege then null;end;
end $$;
-- Current removal wins over historical Activity/Project participation.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='main'),(select option_ids[2] from cast_cases where label='main'),1);raise exception 'Removed bypass';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Trusted fixtures isolate Session state checks without introducing close/reveal APIs.
do $$begin assert not exists(select payload from cast_participant_before except select to_jsonb(p) from public.activity_participants p);end $$;
update public.voting_sessions set status='DRAFT',opened_at=null where id=(select id from cast_cases where label='zero');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='zero'),(select option_ids[2] from cast_cases where label='zero'),1);raise exception 'Draft allowed';exception when object_not_in_prerequisite_state then null;end;
end $$;
reset role;
update public.voting_sessions set status='CLOSED',closed_at=clock_timestamp() where id=(select id from cast_cases where label='zero');
set local role authenticated;
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='zero'),(select option_ids[2] from cast_cases where label='zero'),1);raise exception 'Closed allowed';exception when object_not_in_prerequisite_state then null;end;
end $$;
reset role;
update public.voting_sessions set status='OPEN',opened_at=clock_timestamp(),closed_at=null,voting_type='FIST_TO_FIVE' where id=(select id from cast_cases where label='zero');
set local role authenticated;
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='zero'),(select option_ids[2] from cast_cases where label='zero'),1);raise exception 'Non dot allowed';exception when invalid_parameter_value then null;end;
end $$;
reset role;
-- A post-insert failure proves that even the row itself rolls back.
create function pg_temp.fail_vote() returns trigger language plpgsql as $$begin raise exception 'Fixture failure' using errcode='P0001';end $$;
create trigger fixture_fail_vote after insert on public.votes for each row execute function pg_temp.fail_vote();
set local role authenticated;
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='main'),(select option_ids[2] from cast_cases where label='main'),1);raise exception 'Expected trigger failure' using errcode='XX000';exception when raise_exception then null;end;
end $$;
reset role;
drop trigger fixture_fail_vote on public.votes;
do $$begin assert (select count(*) from public.votes)=7;end $$;
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000006009';
set local role authenticated;
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='main'),(select option_ids[2] from cast_cases where label='main'),1);raise exception 'Suspended allowed';exception when insufficient_privilege then null;end;
 begin perform public.cast_vote('ffffffff-ffff-4fff-8fff-ffffffffffff',(select option_ids[2] from cast_cases where label='main'),1);raise exception 'Guessed ID allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
update public.users set account_status='active' where id='00000000-0000-4000-8000-000000006009';
update public.activity_instances set status='submitted' where id=(select id from vc_activities where n=1);
set local role authenticated;
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='main'),(select option_ids[2] from cast_cases where label='main'),1);raise exception 'Noneditable allowed';exception when object_not_in_prerequisite_state then null;end;
end $$;
reset role;
update public.activity_instances set status='active' where id=(select id from vc_activities where n=1);
-- Completed/archived execution cannot receive votes; its prior history survives.
set local role authenticated;
select public.complete_activity((select id from vc_activities where n=1));
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='main'),(select option_ids[2] from cast_cases where label='main'),1);raise exception 'Completed allowed';exception when object_not_in_prerequisite_state then null;end;
end $$;
reset role;
update public.activity_instances set status='archived' where id=(select id from vc_activities where n=1);
set local role authenticated;
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='main'),(select option_ids[2] from cast_cases where label='main'),1);raise exception 'Archived allowed';exception when object_not_in_prerequisite_state then null;end;
end $$;
select set_config('request.jwt.claim.sub','',true);
do $$begin
 begin perform public.cast_vote((select id from cast_cases where label='main'),(select option_ids[2] from cast_cases where label='main'),1);raise exception 'Anonymous allowed';exception when invalid_authorization_specification then null;end;
end $$;
reset role;
select 'M10.4 AT-VOTE-001/AT-VOTE-002 foundation eligibility/limits/rollback/direct-client PASS';
rollback;
