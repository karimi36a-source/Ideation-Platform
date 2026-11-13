reset role;
create temporary table reveal_cases as select case when jsonb_array_length(payload->'options')=3 then 'live' when payload#>>'{session,activity_instance_id}'=(select id::text from vc_activities where n=1) then 'master' when jsonb_array_length(payload->'options')=2 then 'lead' else 'zero' end label,(payload#>>'{session,id}')::uuid id from vc_results;
grant select on reveal_cases to authenticated;
-- CLOSED fixtures are trusted-only; no closing operation is introduced in M10.5.
update public.voting_sessions set reveal_mode='HIDDEN_UNTIL_REVEAL',vote_limit=3 where id in(select id from reveal_cases where label<>'live');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare s uuid;begin for s in select id from reveal_cases loop
 begin perform public.reveal_voting_session(s);raise exception 'DRAFT reveal allowed';exception when object_not_in_prerequisite_state then null;end;
 perform public.open_voting_session(s);
 begin perform public.reveal_voting_session(s);raise exception 'OPEN reveal allowed';exception when object_not_in_prerequisite_state then null;end;
end loop;end $$;
reset role;
create temporary table reveal_options as select o.* from public.voting_options o join reveal_cases s on s.id=o.voting_session_id;
grant select on reveal_options to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.cast_vote(voting_session_id,id,1) from reveal_options where sequence=1 and voting_session_id in(select id from reveal_cases where label<>'zero');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.cast_vote(voting_session_id,id,1) from reveal_options where sequence=1 and voting_session_id in(select id from reveal_cases where label<>'zero');
reset role;
create temporary table reveal_before as select to_jsonb(v)-'revealed_at' payload from public.votes v;
create temporary table reveal_activity_before as select to_jsonb(a) payload from public.activity_instances a;
update public.voting_sessions set status='CLOSED',closed_at=clock_timestamp() where id in(select id from reveal_cases);
set local role authenticated;
-- No raw read/history surface, even for own successful casts or known IDs.
do $$declare t text;n int;begin
 foreach n in array array[6001,6003,6004,6005,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.reveal_voting_session((select id from reveal_cases where label='master'));raise exception 'Unauthorized reveal';exception when insufficient_privilege then null;end;
 begin perform 1 from public.votes;raise exception 'Raw read allowed';exception when insufficient_privilege then null;end;
 begin update public.votes set revealed_at=clock_timestamp();raise exception 'Direct timestamp edit';exception when insufficient_privilege then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) values((select (payload->>'id')::uuid from logged_projects where label='Team'),'VOTING_SESSION',(select id from reveal_cases where label='master'),'VOTING_SESSION_REVEALED','Forged','00000000-0000-4000-8000-000000006002');raise exception 'Forged event';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
 begin perform public.reveal_voting_session((select id from reveal_cases where label='master'));raise exception 'Lead master-only';exception when insufficient_privilege then null;end;
 perform public.reveal_voting_session((select id from reveal_cases where label='lead'));
 perform public.reveal_voting_session((select id from reveal_cases where label='zero'));
 perform public.reveal_voting_session((select id from reveal_cases where label='zero'));
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 begin perform public.reveal_voting_session((select id from reveal_cases where label='live'));raise exception 'LIVE applicable';exception when object_not_in_prerequisite_state then null;end;
end $$;
reset role;
-- Fault after timestamp updates: outer exception subtransaction must undo every update.
create function pg_temp.fail_reveal_log() returns trigger language plpgsql as $$begin if new.change_type='VOTING_SESSION_REVEALED' then raise exception 'Injected reveal log failure';end if;return new;end $$;
create trigger fail_reveal_log before insert on public.change_log for each row execute function pg_temp.fail_reveal_log();
set local role authenticated;
do $$begin begin perform public.reveal_voting_session((select id from reveal_cases where label='master'));raise exception 'Injection missed';exception when raise_exception then if sqlerrm<>'Injected reveal log failure' then raise;end if;end;end $$;
reset role;
do $$begin assert not exists(select 1 from public.votes where voting_session_id=(select id from reveal_cases where label='master') and revealed_at is not null);assert not exists(select 1 from public.change_log where entity_id=(select id from reveal_cases where label='master') and change_type='VOTING_SESSION_REVEALED');end $$;
drop trigger fail_reveal_log on public.change_log;
-- Partial corruption is never silently repaired.
update public.votes set revealed_at=clock_timestamp() where voting_session_id=(select id from reveal_cases where label='master') and user_id='00000000-0000-4000-8000-000000006004';
set local role authenticated;
do $$begin begin perform public.reveal_voting_session((select id from reveal_cases where label='master'));raise exception 'Partial accepted';exception when object_not_in_prerequisite_state then null;end;end $$;
reset role;
update public.votes set revealed_at=null where voting_session_id=(select id from reveal_cases where label='master');
set local role authenticated;
select public.reveal_voting_session(id) from reveal_cases where label='master';
reset role;
create temporary table reveal_stamps as select id,revealed_at from public.votes;
set local role authenticated;
select public.reveal_voting_session(id) from reveal_cases where label='master';
reset role;
do $$declare s uuid;begin
 assert not exists(select to_jsonb(v)-'revealed_at' from public.votes v except select payload from reveal_before);
 assert not exists(select id,revealed_at from public.votes except select id,revealed_at from reveal_stamps);
 assert not exists(select to_jsonb(a) from public.activity_instances a except select payload from reveal_activity_before);
 assert not exists(select 1 from public.votes where voting_session_id=(select id from reveal_cases where label='live') and revealed_at is not null);
 for s in select id from reveal_cases where label<>'live' loop
 assert (select count(*) from public.change_log where entity_id=s and change_type='VOTING_SESSION_REVEALED')=1;
 assert not exists(select 1 from public.votes v join public.change_log l on l.entity_id=v.voting_session_id and l.change_type='VOTING_SESSION_REVEALED' where v.voting_session_id=s and v.revealed_at is distinct from l.created_at);
 end loop;
 assert (select count(*) from public.votes where voting_session_id=(select id from reveal_cases where label='zero'))=0;
 assert not exists(select 1 from public.decisions);
 assert not exists(select 1 from pg_proc where proname in ('reopen_voting_session'));
 assert not exists(select 1 from information_schema.columns where table_name='voting_sessions' and column_name='revealed_at');
 assert (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.reveal_voting_session(uuid)'::regprocedure);
 assert not has_function_privilege('anon','public.reveal_voting_session(uuid)','execute');
 assert not has_function_privilege('service_role','public.reveal_voting_session(uuid)','execute');
 assert not has_function_privilege('authenticated','private.require_voting_creation(uuid)','execute');
end $$;
-- Runtime type, removed authority, anonymous, exact-ID and post-reveal privacy.
update public.voting_sessions set voting_type='FIST_TO_FIVE' where id=(select id from reveal_cases where label='master');
set local role authenticated;
do $$begin begin perform public.reveal_voting_session((select id from reveal_cases where label='master'));raise exception 'Future runtime accepted';exception when feature_not_supported then null;end;end $$;
reset role;
update public.voting_sessions set voting_type='DOT_VOTE' where id=(select id from reveal_cases where label='master');
set local role authenticated;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin begin perform public.reveal_voting_session((select id from reveal_cases where label='lead'));raise exception 'Removed Lead allowed';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.reveal_voting_session((select id from reveal_cases where label='lead'));raise exception 'Removed member reveal';exception when insufficient_privilege then null;end;
 begin perform count(*) from public.votes v join public.voting_options o on o.id=v.voting_option_id where v.voting_session_id=(select id from reveal_cases where label='master');raise exception 'Direct join/count leak';exception when insufficient_privilege then null;end;
 begin perform 1 from public.votes where voting_session_id=(select id from reveal_cases where label='lead');raise exception 'Anonymous identity exposed';exception when insufficient_privilege then null;end;
 begin update public.votes set revealed_at=null;raise exception 'Clear allowed';exception when insufficient_privilege then null;end;
 begin update public.votes set revealed_at='2000-01-01';raise exception 'Backdate allowed';exception when insufficient_privilege then null;end;
 begin perform public.reveal_voting_session('00000000-0000-4000-8000-000000000001');raise exception 'Missing accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform public.reveal_voting_session((select id from reveal_cases where label='master'));raise exception 'Anonymous allowed';exception when invalid_authorization_specification then null;end;end $$;
reset role;
select 'M10.5 reveal authority/hidden/LIVE/anonymous/retry/zero/corruption/rollback/grants PASS';
rollback;
