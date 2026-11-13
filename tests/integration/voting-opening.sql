
reset role;
create temporary table vo_cases(label text primary key,id uuid);
create temporary table vo_before as select to_jsonb(a) payload from public.activity_instances a;
create temporary table vo_options as select to_jsonb(o) payload from public.voting_options o;
grant select,insert on vo_cases to authenticated;
insert into vo_cases select 'objects',(payload#>>'{session,id}')::uuid from vc_results where jsonb_array_length(payload->'options')=3;
insert into vo_cases select 'masteronly',(payload#>>'{session,id}')::uuid from vc_results where payload#>>'{session,activity_instance_id}'=(select id::text from vc_activities where n=1) and jsonb_array_length(payload->'options')=2;
insert into vo_cases select 'lead',(payload#>>'{session,id}')::uuid from vc_results where payload#>>'{session,created_by}'='00000000-0000-4000-8000-000000006009';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
create temporary table vo_opened as select label,public.open_voting_session(id) payload from vo_cases where label in ('objects','masteronly');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into vo_opened select label,public.open_voting_session(id) from vo_cases where label='lead';
do $$begin
 begin perform public.open_voting_session((select id from vo_cases where label='masteronly'));raise exception 'Lead opened master-only retry';exception when insufficient_privilege then null;end;
end $$;
reset role;
grant select on vo_opened to authenticated;
do $$begin
 assert (select count(*) from public.change_log where change_type='VOTING_SESSION_OPENED')=3;
 assert not exists(select 1 from vo_opened where payload->>'status'<>'OPEN' or payload->>'opened_at' is null or payload->>'closed_at' is not null);
 assert not exists(select 1 from vo_opened x join public.change_log l on l.entity_id=(x.payload->>'id')::uuid and l.change_type='VOTING_SESSION_OPENED' join public.voting_sessions s on s.id=l.entity_id join public.activity_instances a on a.id=s.activity_instance_id where l.project_id<>a.project_id or l.changed_by<>case when x.label='lead' then '00000000-0000-4000-8000-000000006009'::uuid else '00000000-0000-4000-8000-000000006002'::uuid end or l.reason is not null or l.previous_version_id is not null or l.new_version_id is not null or l.related_decision_id is not null or l.related_evidence_id is not null or l.related_ai_output_id is not null);
 assert not exists(select payload from vo_options except select to_jsonb(o) from public.voting_options o);
 assert not exists(select payload from vo_before except select to_jsonb(a) from public.activity_instances a);
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare x record;begin
 for x in select * from vo_opened loop assert public.open_voting_session((x.payload->>'id')::uuid)=x.payload;end loop;
end $$;
-- Real sessions under unauthorized roles must be denied even after OPEN.
do $$declare who integer;x uuid;begin
 foreach who in array array[6001,6003,6004,6005,6007,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(who::text,12,'0')),true);
  for x in select id from vo_cases loop
   begin perform public.open_voting_session(x);raise exception 'Unauthorized opening';exception when insufficient_privilege then null;end;
  end loop;
  begin perform public.open_voting_session('ffffffff-ffff-4fff-8fff-ffffffffffff');raise exception 'Missing exposed';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 insert into vo_cases select label,(public.create_voting_session((select id from vc_activities where n=2),'DOT_VOTE',0,true,'HIDDEN_UNTIL_REVEAL','[{"label":"Test"}]')#>>'{session,id}')::uuid
 from unnest(array['zero','sequence','archivedobject','wrongtype','foreignobject','closed','unsupported','invalidlimit','rollback']) label;
end $$;
reset role;
delete from public.voting_options where voting_session_id=(select id from vo_cases where label='zero');
update public.voting_options set sequence=2 where voting_session_id=(select id from vo_cases where label='sequence');
update public.voting_options set development_object_id=(select id from vc_objects where kind='ARCHIVED') where voting_session_id=(select id from vo_cases where label='archivedobject');
update public.voting_options set development_object_id=(select id from vc_objects where kind='IDEA') where voting_session_id=(select id from vo_cases where label='wrongtype');
update public.voting_options set development_object_id=(select id from vc_foreign_objects limit 1) where voting_session_id=(select id from vo_cases where label='foreignobject');
update public.voting_sessions set status='CLOSED',opened_at=clock_timestamp(),closed_at=clock_timestamp() where id=(select id from vo_cases where label='closed');
update public.voting_sessions set voting_type='FIST_TO_FIVE' where id=(select id from vo_cases where label='unsupported');
-- Deliberately corrupt a trusted fixture to exercise runtime revalidation;
-- transaction rollback restores the original schema constraint.
alter table public.voting_sessions drop constraint voting_sessions_vote_limit_check;
update public.voting_sessions set vote_limit=-1 where id=(select id from vo_cases where label='invalidlimit');
set local role authenticated;
do $$declare x uuid;begin
 for x in select id from vo_cases where label in ('zero','sequence','archivedobject','wrongtype','foreignobject','closed','unsupported','invalidlimit') loop
  begin perform public.open_voting_session(x);raise exception 'Invalid precondition bypass';exception when invalid_parameter_value or insufficient_privilege or object_not_in_prerequisite_state then null;end;
 end loop;
 begin update public.voting_sessions set status='OPEN',opened_at=clock_timestamp() where id=(select id from vo_cases where label='rollback');raise exception 'Direct transition bypass';exception when insufficient_privilege then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) values((select (payload->>'id')::uuid from logged_projects where label='Team'),'VOTING_SESSION',(select id from vo_cases where label='rollback'),'VOTING_SESSION_OPENED','Forged',auth.uid());raise exception 'Forged opening log';exception when insufficient_privilege then null;end;
end $$;
reset role;
create function pg_temp.vo_fail() returns trigger language plpgsql as $$begin if new.change_type='VOTING_SESSION_OPENED' then raise exception 'Injected open log failure' using errcode='23514';end if;return new;end $$;
create trigger vo_log_failure before insert on public.change_log for each row execute function pg_temp.vo_fail();
set local role authenticated;
do $$begin
 begin perform public.open_voting_session((select id from vo_cases where label='rollback'));raise exception 'Logging failure ignored';exception when check_violation then null;end;
end $$;
reset role;
drop trigger vo_log_failure on public.change_log;
do $$begin
 assert exists(select 1 from public.voting_sessions where id=(select id from vo_cases where label='rollback') and status='DRAFT' and opened_at is null and closed_at is null);
 assert (select count(*) from public.change_log where change_type='VOTING_SESSION_OPENED')=3;
end $$;
-- Activity state is reevaluated even on retries; no reopening or snapshot edits.
savepoint before_lifecycle;
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from vc_activities where n=2);
set local role authenticated;
do $$begin begin perform public.open_voting_session((select id from vo_cases where label='lead'));raise exception 'Completed Activity opened';exception when object_not_in_prerequisite_state or insufficient_privilege then null;end;end $$;
reset role;
rollback to before_lifecycle;
update public.activity_instances set status='archived' where id=(select id from vc_activities where n=2);
set local role authenticated;
do $$begin begin perform public.open_voting_session((select id from vo_cases where label='lead'));raise exception 'Archived Activity opened';exception when object_not_in_prerequisite_state or insufficient_privilege then null;end;end $$;
reset role;
rollback to before_lifecycle;
set local role authenticated;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin begin perform public.open_voting_session((select id from vo_cases where label='lead'));raise exception 'Removed Lead opened';exception when insufficient_privilege then null;end;end $$;
reset role;
set local role anon;
do $$begin begin perform public.open_voting_session('ffffffff-ffff-4fff-8fff-ffffffffffff');raise exception 'Anonymous opened';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert not exists(select 1 from public.votes);
 assert not exists(select 1 from public.decisions);
 assert (select proconfig @> array['search_path=""'] from pg_proc where oid='public.open_voting_session(uuid)'::regprocedure);
 assert has_function_privilege('authenticated','public.open_voting_session(uuid)','execute');
 assert not has_function_privilege('anon','public.open_voting_session(uuid)','execute');
 assert not has_function_privilege('service_role','public.open_voting_session(uuid)','execute');
 assert not has_function_privilege('authenticated','private.require_voting_creation(uuid)','execute');
 assert (select count(*) from public.change_log where change_type='VOTING_SESSION_OPENED')=3;
end $$;
select 'M10.3 open Master/Lead/options/state/retry/rollback/privacy/grants/no-votes PASS';
rollback;
