reset role;
create temporary table dc_inputs(label text primary key,payload jsonb);
create temporary table dc_results(label text,payload jsonb);
insert into dc_inputs select 'Team',jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','  Formal question  ','question','  What should we do?  ','method','DOT_VOTE','options',(select jsonb_agg(jsonb_build_object('label',kind,'developmentObjectId',id) order by kind) from vc_objects where kind in ('PROBLEM','SOLUTION','FEATURE'))) from logged_projects where label='Team';
insert into dc_inputs select 'Personal',jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','Personal','question','Choose?','method','DISCUSSION','options','[{"label":" Same "},{"label":"Same","description":""}]'::jsonb) from logged_projects where label='Individual';
grant select on dc_inputs to authenticated;
grant select,insert on dc_results to authenticated;
create temporary table dc_objects_before as select jsonb_agg(to_jsonb(o) order by id) payload from public.development_objects o;
-- Complete voting first: its canonical Objects can be referenced, but counts and
-- links never enter the new human-authored Decision.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.open_voting_session((payload#>>'{session,id}')::uuid) from vc_results where jsonb_array_length(payload->'options')=3;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.cast_vote((payload#>>'{session,id}')::uuid,(payload#>>'{options,0,id}')::uuid,1) from vc_results where jsonb_array_length(payload->'options')=3;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.close_voting_session((payload#>>'{session,id}')::uuid) from vc_results where jsonb_array_length(payload->'options')=3;
reset role;
do $$begin assert not exists(select 1 from public.decisions),'AT-VOTE-003';end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into dc_results select 'Master',public.create_decision(payload) from dc_inputs where label='Team';
insert into dc_results select 'Retry distinct',public.create_decision(payload) from dc_inputs where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into dc_results select 'Lead Activity',public.create_decision(payload||jsonb_build_object('activityInstanceId',(select id from vc_activities where n=2))) from dc_inputs where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into dc_results select 'Personal',public.create_decision(payload||jsonb_build_object('activityInstanceId',(select payload#>>'{activity,id}' from bc_activities where label='Personal'))) from dc_inputs where label='Personal';
insert into dc_results select 'Method '||method,public.create_decision(payload||jsonb_build_object('method',method)) from dc_inputs cross join unnest(array['DOT_VOTE','DISCUSSION','CONSENSUS','OTHER']) method where label='Personal';
-- Exact IDs and forged claims do not establish authority.
do $$declare who integer;x jsonb;begin
 select payload into x from dc_inputs where label='Team';
 foreach who in array array[6001,6003,6004,6005,6007,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(who::text,12,'0')),true);
  begin perform public.create_decision(x);raise exception 'Unauthorized Team creator';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 begin perform public.create_decision((select payload from dc_inputs where label='Personal'));raise exception 'Master Personal bypass';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 begin perform public.create_decision((select payload from dc_inputs where label='Personal'));raise exception 'Foreign Personal bypass';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare x jsonb;field text;oid uuid;aid uuid;begin
 select payload into x from dc_inputs where label='Team';
 foreach field in array array['id','status','outcome','reasoning','decidedAt','decisionOwnerUserId','createdBy','participantIds','participants','selectedOptionId','votingSessionId','linkedArtifactIds','linkedObjectIds','voteCount','winner','role','teamId'] loop
  begin perform public.create_decision(x||jsonb_build_object(field,'spoof'));raise exception 'Extra input accepted';exception when invalid_parameter_value then null;end;
 end loop;
 foreach field in array array['id','decisionId','selected','sequence','voteCount','score','winner','projectId','workspaceId'] loop
  begin perform public.create_decision(x||jsonb_build_object('options',jsonb_build_array(jsonb_build_object('label','x',field,'spoof'))));raise exception 'Extra Option accepted';exception when invalid_parameter_value then null;end;
 end loop;
 foreach field in array array['title','question'] loop
  begin perform public.create_decision(x||jsonb_build_object(field,E' \n\t '));raise exception 'Blank accepted';exception when invalid_parameter_value then null;end;
 end loop;
 foreach field in array array['title','question'] loop
  begin perform public.create_decision(x||jsonb_build_object(field,chr(160)||chr(65279)));raise exception 'Unicode whitespace accepted';exception when invalid_parameter_value then null;end;
 end loop;
 begin perform public.create_decision(x||jsonb_build_object('options',jsonb_build_array(jsonb_build_object('label',chr(160)||chr(65279)))));raise exception 'Unicode label accepted';exception when invalid_parameter_value then null;end;
 begin
  declare normalized jsonb;
  begin
   normalized:=public.create_decision(x||jsonb_build_object('title',chr(160)||'Title'||chr(65279),'question',chr(160)||'Question'||chr(65279),'options',jsonb_build_array(jsonb_build_object('label',chr(160)||'Option'||chr(65279)))));
   assert normalized#>>'{decision,title}'='Title';assert normalized#>>'{decision,question}'='Question';assert normalized#>>'{options,0,label}'='Option';
   raise exception 'Discard normalization fixture' using errcode='P0002';
  end;
 exception when no_data_found then null;end;
 foreach field in array array['FIST_TO_FIVE','PLANNING_POKER','FAKE'] loop
  begin perform public.create_decision(x||jsonb_build_object('method',field));raise exception 'Unknown method';exception when invalid_parameter_value then null;end;
 end loop;
 begin perform public.create_decision(x||'{"options":[]}');raise exception 'Empty options';exception when invalid_parameter_value then null;end;
 begin perform public.create_decision(x||'{"options":[{"label":" "}]}');raise exception 'Blank label';exception when invalid_parameter_value then null;end;
 select id into oid from vc_objects where kind='PROBLEM';
 begin perform public.create_decision(x||jsonb_build_object('options',jsonb_build_array(jsonb_build_object('label','one','developmentObjectId',oid),jsonb_build_object('label','two','developmentObjectId',oid))));raise exception 'Duplicate Object';exception when invalid_parameter_value then null;end;
 for oid in select id from vc_objects where kind in ('IDEA','ARCHIVED') union all select id from vc_foreign_objects union all select gen_random_uuid() loop
  begin perform public.create_decision(x||jsonb_build_object('options',jsonb_build_array(jsonb_build_object('label','Wrong Object','developmentObjectId',oid))));raise exception 'Wrong Object accepted';exception when insufficient_privilege then null;end;
 end loop;
 for aid in select id from vc_foreign_activities union all select gen_random_uuid() loop
  begin perform public.create_decision(x||jsonb_build_object('activityInstanceId',aid));raise exception 'Foreign Activity';exception when insufficient_privilege then null;end;
 end loop;
 begin perform public.create_decision(x||jsonb_build_object('workspaceId',(select payload->>'workspaceId' from acceptance_teams where label='B')));raise exception 'Workspace mismatch';exception when insufficient_privilege then null;end;
end $$;
reset role;
create function pg_temp.dc_fail() returns trigger language plpgsql as $$begin raise exception 'Injected failure' using errcode='23514';end $$;
create trigger dc_option_failure before insert on public.decision_options for each row execute function pg_temp.dc_fail();
set local role authenticated;
do $$begin
 begin perform public.create_decision((select payload from dc_inputs where label='Team'));raise exception 'Option failure ignored';exception when check_violation then null;end;
end $$;
reset role;
drop trigger dc_option_failure on public.decision_options;
create trigger dc_log_failure before insert on public.change_log for each row execute function pg_temp.dc_fail();
set local role authenticated;
do $$begin
 begin perform public.create_decision((select payload from dc_inputs where label='Team'));raise exception 'Log failure ignored';exception when check_violation then null;end;
end $$;
reset role;
drop trigger dc_log_failure on public.change_log;
-- Trusted lifecycle fixtures change no historical scope/snapshot.
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from vc_activities where n=3);
update public.activity_instances set status='archived' where id=(select id from vc_activities where n=4);
set local role authenticated;
do $$declare a uuid;x jsonb;begin
 select payload into x from dc_inputs where label='Team';
 for a in select id from vc_activities where n in (3,4) loop
  begin perform public.create_decision(x||jsonb_build_object('activityInstanceId',a));raise exception 'Non-editable Activity';exception when object_not_in_prerequisite_state or insufficient_privilege then null;end;
 end loop;
end $$;
-- Normal credentials cannot forge rows, ownership, selection or log events.
do $$declare x jsonb;begin
 select payload into x from dc_inputs where label='Team';
 begin insert into public.decisions(project_id,workspace_id,title,question,method,decision_owner_user_id,status,decided_at) values((x->>'projectId')::uuid,(x->>'workspaceId')::uuid,'Forged','Q','OTHER','00000000-0000-4000-8000-000000006002','FINALIZED',clock_timestamp());raise exception 'Direct insert';exception when insufficient_privilege then null;end;
 begin insert into public.decision_options(decision_id,label,selected) values((select payload#>>'{decision,id}' from dc_results limit 1)::uuid,'Forged',true);raise exception 'Direct selected';exception when insufficient_privilege then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) values((x->>'projectId')::uuid,'DECISION',gen_random_uuid(),'DECISION_CREATED','Forged','00000000-0000-4000-8000-000000006002');raise exception 'Direct log';exception when insufficient_privilege then null;end;
 begin perform private.require_decision_creation((x->>'projectId')::uuid,(x->>'workspaceId')::uuid,null);raise exception 'Private helper reachable';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.decisions where not public.can_read_decision(id));
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin begin perform public.create_decision((select payload from dc_inputs where label='Team'));raise exception 'Removed lead';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform public.create_decision((select payload from dc_inputs where label='Personal'));raise exception 'Anonymous';exception when invalid_authorization_specification then null;end;end $$;
reset role;
do $$declare r jsonb;d public.decisions;begin
 assert (select count(*) from public.decisions)=8,'Failure left orphan Decision';
 assert (select count(*) from public.decision_options)=19,'Partial Options or orphan Options';
 assert (select count(*) from public.change_log where change_type='DECISION_CREATED')=8,'Exactly one event per deliberate creation';
 assert not exists(select 1 from public.decision_participants);
 assert not exists(select 1 from public.decision_links);
 assert not exists(select 1 from public.decision_options where selected);
 assert not exists(select 1 from public.decisions where status<>'DRAFT' or outcome is not null or reasoning is not null or decided_at is not null);
 assert (select payload from dc_objects_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),'Canonical Objects changed';
 assert (select payload#>>'{decision,id}' from dc_results where label='Master')<>(select payload#>>'{decision,id}' from dc_results where label='Retry distinct');
 for r in select payload from dc_results loop
  select * into strict d from public.decisions where id=(r#>>'{decision,id}')::uuid;
  assert to_jsonb(d)=r->'decision';
  assert (select count(*) from public.decision_options where decision_id=d.id)=jsonb_array_length(r->'options');
  assert exists(select 1 from public.change_log l where l.entity_id=d.id and l.entity_type='DECISION' and l.change_type='DECISION_CREATED' and l.project_id=d.project_id and l.changed_by=d.decision_owner_user_id and l.reason is null and l.previous_version_id is null and l.new_version_id is null and l.related_decision_id is null and l.related_evidence_id is null and l.related_ai_output_id is null);
 end loop;
 assert not has_function_privilege('anon','public.create_decision(jsonb)','execute');
 assert not has_function_privilege('service_role','public.create_decision(jsonb)','execute');
 assert not has_function_privilege('authenticated','private.require_decision_creation(uuid,uuid,uuid)','execute');
 assert (select proconfig @> array['search_path=""'] from pg_proc where oid='public.create_decision(jsonb)'::regprocedure);
 assert has_function_privilege('authenticated','public.supersede_decision(jsonb)','execute');
 assert not has_function_privilege('anon','public.supersede_decision(jsonb)','execute');
 assert not has_function_privilege('service_role','public.supersede_decision(jsonb)','execute');
end $$;
\pset format unaligned
select 'M109_CREATED='||payload::text from dc_results where label='Master';
select 'M10.9 Personal/Lead/Master strict input/scope/Object reuse/Draft/owner/no participants-links-votes/log/rollback/new identity/direct denial/AT-VOTE-003 PASS';
rollback;
