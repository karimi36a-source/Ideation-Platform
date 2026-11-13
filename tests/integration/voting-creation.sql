reset role;
create temporary table vc_activities(n integer primary key,id uuid);
create temporary table vc_objects(kind text primary key,id uuid);
create temporary table vc_results(payload jsonb);
-- Capture known private IDs as trusted attack fixtures, not through attacker RLS.
create temporary table vc_foreign_objects as select id from public.development_objects where project_id<>(select (payload->>'id')::uuid from logged_projects where label='Team');
create temporary table vc_foreign_activities as select id from public.activity_instances where project_id<>(select (payload->>'id')::uuid from logged_projects where label='Team');
grant select,insert on vc_activities,vc_objects,vc_results to authenticated;
grant select on vc_foreign_objects,vc_foreign_activities to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into vc_activities select n,(public.start_activity(('00000000-0000-4000-8000-'||lpad((1020800+n)::text,12,'0'))::uuid,(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid)#>>'{activity,id}')::uuid
from generate_series(1,6) n cross join logged_projects p cross join acceptance_teams t where p.label='Team' and t.label='A';
insert into vc_objects select kind,(public.create_development_object((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,kind::public.development_object_type,'Voting test','Canonical content',null)->>'id')::uuid
from unnest(array['PROBLEM','SOLUTION','FEATURE','IDEA']) kind cross join logged_projects p where p.label='Team';
insert into vc_objects select 'ARCHIVED',(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM','Archived choice','Preserved content',null)->>'id')::uuid from logged_projects where label='Team';
select public.archive_development_object(id) from vc_objects where kind='ARCHIVED';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into vc_results select public.create_voting_session(id,'DOT_VOTE',3,false,'LIVE',
(select jsonb_agg(jsonb_build_object('developmentObjectId',id,'label',kind) order by kind desc) from vc_objects where kind in ('PROBLEM','SOLUTION','FEATURE'))) from vc_activities where n=1;
insert into vc_results select public.create_voting_session(id,'DOT_VOTE',0,true,'HIDDEN_UNTIL_REVEAL','[{"label":"Same"},{"label":"Same","description":""}]') from vc_activities where n in (1,2);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into vc_results select public.create_voting_session(id,'DOT_VOTE',3,false,'LIVE','[{"label":"Lead"}]') from vc_activities where n=2;
do $$declare a uuid;begin
 select id into a from vc_activities where n=1;
 begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'LIVE','[{"label":"Lead denied"}]');raise exception 'Lead bypassed master-only';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare r jsonb;s public.voting_sessions;before bigint;begin
 assert (select count(*) from public.voting_sessions)=4;
 assert (select count(*) from public.change_log where change_type='VOTING_SESSION_CREATED')=4;
 assert not exists(select 1 from public.votes);
 assert not exists(select 1 from public.voting_sessions where status<>'DRAFT' or opened_at is not null or closed_at is not null);
 assert not exists(select 1 from information_schema.columns where table_schema='public' and table_name='change_log' and column_name='activity_instance_id');
 for r in select payload from vc_results loop
  select * into strict s from public.voting_sessions where id=(r#>>'{session,id}')::uuid;
  assert exists(select 1 from public.change_log l join public.activity_instances a on a.id=s.activity_instance_id where l.entity_id=s.id and l.project_id=a.project_id and l.entity_type='VOTING_SESSION' and l.changed_by=s.created_by and l.change_type='VOTING_SESSION_CREATED' and l.reason is null and l.previous_version_id is null and l.new_version_id is null and l.related_decision_id is null and l.related_evidence_id is null and l.related_ai_output_id is null);
  assert (select array_agg((x.value->>'sequence')::integer order by x.ordinality) from jsonb_array_elements(r->'options') with ordinality x)=array(select generate_series(1,jsonb_array_length(r->'options')));
 end loop;
 assert (select count(distinct id) from public.voting_sessions where activity_instance_id=(select id from vc_activities where n=1))=2;
 assert not exists(select 1 from public.voting_options where label='PROBLEM' and sequence<>2);
 assert not exists(select 1 from public.decisions);
 assert not exists(select 1 from pg_proc where proname in ('reopen_voting_session'));
end $$;
-- Unauthorized roles and exact/foreign resource IDs must not leave partial records.
set local role authenticated;
do $$declare who integer;a uuid;begin
 select id into a from vc_activities where n=2;
 foreach who in array array[6001,6003,6004,6005,6007,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(who::text,12,'0')),true);
  begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'LIVE','[{"label":"Denied"}]');raise exception 'Unauthorized creator';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 for a in select id from vc_activities where n>=3 loop
  begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'LIVE','[{"label":"Bad config"}]');raise exception 'Configuration bypass';exception when feature_not_supported then null;end;
 end loop;
end $$;
do $$declare a uuid;o uuid;x jsonb;begin
 select id into a from vc_activities where n=2;
 for x in select value from jsonb_array_elements('[[],[{"label":" "}],[{"label":"x","sequence":1}],[{"label":"x","description":null}]]') loop
  begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'LIVE',x);raise exception 'Invalid options accepted';exception when invalid_parameter_value then null;end;
 end loop;
 for o in select id from vc_objects where kind in ('IDEA','ARCHIVED') loop
  begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'LIVE',jsonb_build_array(jsonb_build_object('label','Unsupported','developmentObjectId',o)));raise exception 'Unsupported or archived Object accepted';exception when insufficient_privilege then null;end;
 end loop;
 select id into o from vc_objects where kind='PROBLEM';
 begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'LIVE',jsonb_build_array(jsonb_build_object('label','One','developmentObjectId',o),jsonb_build_object('label','Two','developmentObjectId',o)));raise exception 'Duplicate accepted';exception when invalid_parameter_value then null;end;
 for o in select id from vc_foreign_objects loop
  begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'LIVE',jsonb_build_array(jsonb_build_object('label','Foreign','developmentObjectId',o)));raise exception 'Foreign Object accepted';exception when insufficient_privilege then null;end;
 end loop;
 begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'LIVE',jsonb_build_array(jsonb_build_object('label','Missing','developmentObjectId',gen_random_uuid())));raise exception 'Missing Object accepted';exception when insufficient_privilege then null;end;
 begin perform public.create_voting_session(a,'FIST_TO_FIVE',3,false,'LIVE','[{"label":"x"}]');raise exception 'Future type accepted';exception when invalid_parameter_value then null;end;
 begin perform public.create_voting_session(a,'PLANNING_POKER',3,false,'LIVE','[{"label":"x"}]');raise exception 'Future type accepted';exception when invalid_parameter_value then null;end;
 begin perform public.create_voting_session(a,'DOT_VOTE',-1,false,'LIVE','[{"label":"x"}]');raise exception 'Negative limit accepted';exception when invalid_parameter_value then null;end;
 begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'PUBLIC','[{"label":"x"}]');raise exception 'Unknown reveal accepted';exception when invalid_parameter_value then null;end;
 for o in select id from vc_foreign_activities union all select gen_random_uuid() loop
  begin perform public.create_voting_session(o,'DOT_VOTE',3,false,'LIVE','[{"label":"Known foreign Activity"}]');raise exception 'Foreign Activity accepted';exception when insufficient_privilege or feature_not_supported then null;end;
 end loop;
end $$;
reset role;
create function pg_temp.vc_fail() returns trigger language plpgsql as $$begin raise exception 'Injected transaction failure' using errcode='23514';end $$;
create trigger vc_option_failure before insert on public.voting_options for each row execute function pg_temp.vc_fail();
set local role authenticated;
do $$begin
 begin perform public.create_voting_session((select id from vc_activities where n=2),'DOT_VOTE',3,false,'LIVE','[{"label":"Force failure"}]');raise exception 'Option failure ignored';exception when check_violation then null;end;
end $$;
reset role;
drop trigger vc_option_failure on public.voting_options;
create trigger vc_log_failure before insert on public.change_log for each row execute function pg_temp.vc_fail();
set local role authenticated;
do $$begin
 begin perform public.create_voting_session((select id from vc_activities where n=2),'DOT_VOTE',3,false,'LIVE','[{"label":"Force log failure"}]');raise exception 'Log failure ignored';exception when check_violation then null;end;
 begin insert into public.voting_sessions(activity_instance_id,voting_type,vote_limit,created_by) values((select id from vc_activities where n=2),'DOT_VOTE',3,auth.uid());raise exception 'Direct insert permitted';exception when insufficient_privilege then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) values(gen_random_uuid(),'VOTING_SESSION',gen_random_uuid(),'VOTING_SESSION_CREATED','Forged',auth.uid());raise exception 'Log forged';exception when insufficient_privilege then null;end;
end $$;
reset role;
drop trigger vc_log_failure on public.change_log;
do $$begin
 assert (select count(*) from public.voting_sessions)=4;
 assert (select count(*) from public.voting_options)=8;
 assert (select count(*) from public.change_log where change_type='VOTING_SESSION_CREATED')=4;
 assert not exists(select 1 from public.votes);
 assert not has_function_privilege('anon','public.create_voting_session(uuid,text,integer,boolean,text,jsonb)','execute');
 assert not has_function_privilege('service_role','public.create_voting_session(uuid,text,integer,boolean,text,jsonb)','execute');
 assert not has_function_privilege('authenticated','private.require_voting_creation(uuid)','execute');
 assert (select proconfig @> array['search_path=""'] from pg_proc where oid='public.create_voting_session(uuid,text,integer,boolean,text,jsonb)'::regprocedure);
end $$;
-- Trusted lifecycle fixtures preserve started identity/snapshot; no runtime transitions added.
update public.activity_instances set status='archived' where id=(select id from vc_activities where n=3);
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from vc_activities where n=4);
set local role authenticated;
do $$declare a uuid;begin
 for a in select id from vc_activities where n in (3,4) loop
  begin perform public.create_voting_session(a,'DOT_VOTE',3,false,'LIVE','[{"label":"Non-editable"}]');raise exception 'Non-editable Activity allowed';exception when object_not_in_prerequisite_state or insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
do $$begin assert (select count(*) from public.voting_sessions)=4;end $$;
set local role authenticated;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin
 begin perform public.create_voting_session((select id from vc_activities where n=2),'DOT_VOTE',3,false,'LIVE','[{"label":"Removed lead"}]');raise exception 'Removed lead authorized';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'M10.2 create voting Master/Lead/configuration/options/order/new identity/log/rollback/privacy/grants PASS';
select 'M102_CHANGE_TYPES='||json_agg(enumlabel order by enumsortorder)::text from pg_enum where enumtypid='public.project_change_type'::regtype;
select 'M102_CHANGE_ENTITIES='||json_agg(enumlabel order by enumsortorder)::text from pg_enum where enumtypid='public.project_change_entity_type'::regtype;
rollback;
