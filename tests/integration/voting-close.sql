reset role;
create temporary table close_cases as select case when jsonb_array_length(payload->'options')=3 then 'master' when payload#>>'{session,activity_instance_id}'=(select id::text from vc_activities where n=1) then 'hidden' when jsonb_array_length(payload->'options')=2 then 'lead' else 'other' end label,(payload#>>'{session,id}')::uuid id from vc_results;
grant select on close_cases to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare s uuid;begin for s in select id from close_cases loop
 begin perform public.close_voting_session(s);raise exception 'DRAFT close allowed';exception when object_not_in_prerequisite_state then null;end;
 perform public.open_voting_session(s);
end loop;end $$;
reset role;
create temporary table close_options as select o.* from public.voting_options o join close_cases s on s.id=o.voting_session_id;
grant select on close_options to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.cast_vote(voting_session_id,id,1) from close_options where sequence=1 and voting_session_id=(select id from close_cases where label='master');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.cast_vote(voting_session_id,id,1) from close_options where sequence in (1,2) and voting_session_id=(select id from close_cases where label='master');
reset role;
create temporary table close_votes_before as select to_jsonb(v) payload from public.votes v;
create temporary table close_objects_before as select to_jsonb(o) payload from public.development_objects o;
create temporary table close_projects_before as select to_jsonb(p) payload from public.development_projects p;
create temporary table close_artifacts_before as select to_jsonb(a) payload from public.artifacts a;
create temporary table close_sessions_before as select * from public.voting_sessions;
set local role authenticated;
do $$declare n int;begin foreach n in array array[6001,6003,6004,6005,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.close_voting_session((select id from close_cases where label='master'));raise exception 'Unauthorized close';exception when insufficient_privilege then null;end;
 begin update public.voting_sessions set status='CLOSED',closed_at=clock_timestamp();raise exception 'Direct close';exception when insufficient_privilege then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) values((select (payload->>'id')::uuid from logged_projects where label='Team'),'VOTING_SESSION',(select id from close_cases where label='master'),'VOTING_SESSION_CLOSED','Forged','00000000-0000-4000-8000-000000006002');raise exception 'Forged event';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
 begin perform public.close_voting_session((select id from close_cases where label='master'));raise exception 'Lead master-only';exception when insufficient_privilege then null;end;
 perform public.close_voting_session((select id from close_cases where label='lead'));
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
end $$;
reset role;
-- Activity lifecycle fixtures retain identity/configuration/history. No business archive/reopen is added.
do $$declare state public.activity_instance_status;begin
 foreach state in array array['completed','archived']::public.activity_instance_status[] loop
 begin
 update public.activity_instances set status=state,completed_at=case when state='completed' then clock_timestamp() else null end where id=(select id from vc_activities where n=1);
 set local role authenticated;
 begin perform public.close_voting_session((select id from close_cases where label='master'));raise exception 'Historical Activity first close';exception when object_not_in_prerequisite_state then null;end;
 reset role;
 raise exception 'Discard isolated lifecycle fixture' using errcode='P0002';
 exception when no_data_found then null;end;
 end loop;
 update public.activity_instances set status='active',completed_at=null where id=(select id from vc_activities where n=1);
end $$;
-- Logging fault must undo both Session fields.
create function pg_temp.fail_close_log() returns trigger language plpgsql as $$begin if new.change_type='VOTING_SESSION_CLOSED' then raise exception 'Injected close log failure';end if;return new;end $$;
create trigger fail_close_log before insert on public.change_log for each row execute function pg_temp.fail_close_log();
set local role authenticated;
do $$begin begin perform public.close_voting_session((select id from close_cases where label='master'));raise exception 'Injection missed';exception when raise_exception then if sqlerrm<>'Injected close log failure' then raise;end if;end;end $$;
reset role;
do $$begin assert (select status='OPEN' and closed_at is null from public.voting_sessions where id=(select id from close_cases where label='master'));assert not exists(select 1 from public.change_log where entity_id=(select id from close_cases where label='master') and change_type='VOTING_SESSION_CLOSED');end $$;
drop trigger fail_close_log on public.change_log;
set local role authenticated;
select public.close_voting_session(id) from close_cases where label in ('master','hidden');
reset role;
create temporary table closed_rows as select to_jsonb(s) payload from public.voting_sessions s where status='CLOSED';
-- CLOSED retry is read-only under active, completed and archived Activities.
do $$declare state public.activity_instance_status;begin
 foreach state in array array['active','completed','archived']::public.activity_instance_status[] loop
 begin
 update public.activity_instances set status=state,completed_at=case when state='completed' then clock_timestamp() else null end where id=(select id from vc_activities where n=1);
 set local role authenticated;
 perform public.close_voting_session((select id from close_cases where label='master'));
 reset role;
 assert not exists(select to_jsonb(s) from public.voting_sessions s where status='CLOSED' except select payload from closed_rows);
 raise exception 'Discard isolated lifecycle fixture' using errcode='P0002';
 exception when no_data_found then null;end;
 end loop;
 update public.activity_instances set status='active',completed_at=null where id=(select id from vc_activities where n=1);
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.cast_vote((select id from close_cases where label='master'),(select id from close_options where voting_session_id=(select id from close_cases where label='master') and sequence=3),1);raise exception 'Post close vote';exception when object_not_in_prerequisite_state then null;end;
 begin perform 1 from public.votes;raise exception 'Raw visibility';exception when insufficient_privilege then null;end;
 begin update public.votes set value=2;raise exception 'Vote mutation';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare s uuid;begin
 assert not exists(select to_jsonb(v) from public.votes v except select payload from close_votes_before);
 assert not exists(select to_jsonb(o) from public.development_objects o except select payload from close_objects_before);
 assert not exists(select to_jsonb(p) from public.development_projects p except select payload from close_projects_before);
 assert not exists(select to_jsonb(a) from public.artifacts a except select payload from close_artifacts_before);
 assert (select max(n) from (select count(*) n from public.votes group by voting_option_id) x)=2;
 assert not exists(select 1 from public.decisions);
 assert not exists(select 1 from public.change_log where change_type='VOTING_SESSION_REVEALED');
 assert not exists(select 1 from public.votes where revealed_at is not null);
 assert not exists(select 1 from public.voting_sessions s join close_sessions_before b using(id) where s.opened_at is distinct from b.opened_at or s.vote_limit<>b.vote_limit or s.anonymous<>b.anonymous or s.reveal_mode<>b.reveal_mode or s.created_by<>b.created_by);
 for s in select id from close_cases where label<>'other' loop
 assert (select count(*) from public.change_log where entity_id=s and change_type='VOTING_SESSION_CLOSED')=1;
 assert (select closed_at from public.voting_sessions where id=s)=(select created_at from public.change_log where entity_id=s and change_type='VOTING_SESSION_CLOSED');
 end loop;
 assert (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.close_voting_session(uuid)'::regprocedure);
 assert not has_function_privilege('anon','public.close_voting_session(uuid)','execute');
 assert not has_function_privilege('service_role','public.close_voting_session(uuid)','execute');
 assert not has_function_privilege('authenticated','private.require_voting_close_context(uuid)','execute');
end $$;
-- Explicit reveal still separate and available after canonical close.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.reveal_voting_session(id) from close_cases where label='hidden';
select public.close_voting_session(id) from close_cases where label='hidden';
reset role;
update public.voting_sessions set voting_type='PLANNING_POKER' where id=(select id from close_cases where label='other');
set local role authenticated;
do $$begin begin perform public.close_voting_session((select id from close_cases where label='other'));raise exception 'Unsupported type';exception when feature_not_supported then null;end;end $$;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009');
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
do $$declare n int;begin foreach n in array array[6009,6004,6007] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.close_voting_session((select id from close_cases where label='lead'));raise exception 'Removed/foreign retry';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','',true);
 begin perform public.close_voting_session((select id from close_cases where label='master'));raise exception 'Anonymous close';exception when invalid_authorization_specification then null;end;
end $$;
reset role;
select 'M10.6 AT-VOTE-003 close/authority/lifecycle/retry/hidden/history/rollback/grants PASS';
rollback;
