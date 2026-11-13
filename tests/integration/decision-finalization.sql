-- Real canonical RPCs, real auth identities, one disposable PostgreSQL transaction.
reset role;
create temporary table df_before as select
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v) versions,
 (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b) baselines;
create temporary table df_results(label text,payload jsonb);
grant select,insert on df_results to authenticated;
-- Existing contextual participant metadata and safe links must survive.
insert into public.decision_participants(decision_id,user_id,role,position,comment)
select (payload#>>'{decision,id}')::uuid,'00000000-0000-4000-8000-000000006009','OBSERVER','Before','Keep' from df_drafts where label='Existing participant';
insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type)
select (payload#>>'{decision,id}')::uuid,'DEVELOPMENT_OBJECT',(select id from vc_objects where kind='PROBLEM'),'CONSIDERED_IN_DECISION' from df_drafts where label='Team';
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from vc_activities where n=3);
update public.activity_instances set status='archived' where id=(select id from vc_activities where n=4);
update public.decisions set status='SUPERSEDED' where id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='Superseded');
update public.decisions set status='ARCHIVED' where id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='Archived Decision');
set local role authenticated;
-- Every role-only, ordinary member/voter and unrelated scope is denied identically.
do $$declare who integer;did uuid;begin
 select (payload#>>'{decision,id}')::uuid into did from df_drafts where label='Team';
 foreach who in array array[6001,6003,6004,6005,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who::text,12,'0'),true);
  begin perform public.finalize_decision(jsonb_build_object('decisionId',did,'outcome','Chosen','reasoning','Human'));raise exception 'Unauthorized finalizer';exception when insufficient_privilege then null;end;
 end loop;
 foreach who in array array[6001,6002,6003,6005,6008,6009] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who::text,12,'0'),true);
  begin perform public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Personal'),'outcome','Chosen','reasoning','Human'));raise exception 'Private bypass';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','',true);
 begin perform public.finalize_decision('{"decisionId":"00000000-0000-4000-8000-000000000000","outcome":"A","reasoning":"B"}');raise exception 'Anonymous';exception when invalid_authorization_specification then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare x jsonb;field text;case_label text;foreign_artifact uuid;begin
 x:=jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Team'),'outcome','Chosen','reasoning','Human');
 foreach field in array array['status','decidedAt','decisionOwnerUserId','finalizerUserId','participantIds','participants','votingSessionId','voteCount','winner','selectedOptionIds','projectId','workspaceId','teamId','role'] loop
  begin perform public.finalize_decision(x||jsonb_build_object(field,'spoof'));raise exception 'Unknown field';exception when invalid_parameter_value then null;end;
 end loop;
 foreach field in array array['outcome','reasoning'] loop
  begin perform public.finalize_decision(x||jsonb_build_object(field,E' 	
'));raise exception 'Blank';exception when invalid_parameter_value then null;end;
  begin perform public.finalize_decision(x||jsonb_build_object(field,chr(160)||chr(65279)));raise exception 'Unicode blank';exception when invalid_parameter_value then null;end;
 end loop;
 for case_label in select unnest(array['Completed','Archived Activity','Superseded','Archived Decision']) loop
  begin perform public.finalize_decision(x||jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts f where f.label=case_label)));raise exception 'Lifecycle bypass';exception when object_not_in_prerequisite_state then null;end;
 end loop;
 begin perform public.finalize_decision(x||jsonb_build_object('selectedOptionId',(select payload#>>'{options,0,id}' from df_drafts where label='Personal')));raise exception 'Foreign selection';exception when insufficient_privilege then null;end;
 begin perform public.finalize_decision(x||jsonb_build_object('linkedEvidenceIds',jsonb_build_array(gen_random_uuid())));raise exception 'Evidence fabricated';exception when insufficient_privilege then null;end;
 foreach field in array array['linkedArtifactIds','linkedObjectIds'] loop
  begin perform public.finalize_decision(x||jsonb_build_object(field,jsonb_build_array('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001')));raise exception 'Duplicate input';exception when invalid_parameter_value then null;end;
 end loop;
 for foreign_artifact in select id from df_artifacts where label in ('Personal','Team B') loop
  begin perform public.finalize_decision(x||jsonb_build_object('linkedArtifactIds',jsonb_build_array(foreign_artifact)));raise exception 'Foreign Artifact';exception when insufficient_privilege then null;end;
 end loop;
 begin perform public.finalize_decision(x||jsonb_build_object('linkedObjectIds',jsonb_build_array((select id from vc_foreign_objects limit 1))));raise exception 'Foreign Object';exception when insufficient_privilege then null;end;
end $$;
-- A preserved pre-existing considered link cannot silently make the same
-- finalization request conflict on its own immediate retry.
do $$begin
 begin perform public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Team'),'outcome','A','reasoning','B'));raise exception 'Omitted pre-existing link produced non-idempotent final state';exception when serialization_failure then null;end;
end $$;
-- Select the explicit human alternative, never a vote-derived default.
insert into df_results select 'Team',public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}','selectedOptionId',payload#>>'{options,1,id}','outcome',chr(160)||'Investigate alternative'||chr(65279),'reasoning',' Human explanation ','linkedEvidenceIds','[]'::jsonb,'linkedArtifactIds',jsonb_build_array((select id from df_artifacts where label='Team')),'linkedObjectIds',jsonb_build_array((select id from vc_objects where kind='PROBLEM'),(select id from vc_objects where kind='SOLUTION')))) from df_drafts where label='Team';
-- Set order is semantic; different authorized retry actor adds no participant.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into df_results select 'Retry',public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}','selectedOptionId',payload#>>'{options,1,id}','outcome','Investigate alternative','reasoning','Human explanation','linkedArtifactIds',jsonb_build_array((select id from df_artifacts where label='Team')),'linkedObjectIds',jsonb_build_array((select id from vc_objects where kind='SOLUTION'),(select id from vc_objects where kind='PROBLEM')))) from df_drafts where label='Team';
insert into df_results select 'Master different',public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}','outcome','Further work','reasoning','No choice yet')) from df_drafts where label='Master different';
insert into df_results select 'Master owner',public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}','outcome','Further work','reasoning','Human')) from df_drafts where label='Master owner';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into df_results select label,public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}','outcome','No option','reasoning','Investigate')) from df_drafts where label in ('No selection','Existing participant','Lead different');
do $$declare x jsonb;field text;begin
 x:=jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='No selection'),'outcome','No option','reasoning','Investigate');
 foreach field in array array['outcome','reasoning'] loop
  begin perform public.finalize_decision(x||jsonb_build_object(field,'Different'));raise exception 'Retry overwrote';exception when serialization_failure then null;end;
 end loop;
 begin perform public.finalize_decision(x||jsonb_build_object('selectedOptionId',(select payload#>>'{options,0,id}' from df_drafts where label='No selection')));raise exception 'Selection overwrite';exception when serialization_failure then null;end;
 begin perform public.finalize_decision(x||jsonb_build_object('linkedObjectIds',jsonb_build_array((select id from vc_objects where kind='PROBLEM'))));raise exception 'Link overwrite';exception when serialization_failure then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into df_results select 'Personal',public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}','outcome','Own decision','reasoning','Own explanation')) from df_drafts where label='Personal';
reset role;
-- Failures after Option/participant/link writes must roll back the whole operation.
create function pg_temp.df_fail() returns trigger language plpgsql as $$begin raise exception 'Injected' using errcode='23514';end $$;
create trigger df_failure before insert on public.decision_participants for each row execute function pg_temp.df_fail();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin begin perform public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Participant failure'),'selectedOptionId',(select payload#>>'{options,0,id}' from df_drafts where label='Participant failure'),'outcome','A','reasoning','B'));raise exception 'No rollback';exception when check_violation then null;end;end $$;
reset role;drop trigger df_failure on public.decision_participants;
create trigger df_failure before insert on public.decision_links for each row execute function pg_temp.df_fail();
set local role authenticated;
do $$begin begin perform public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Link failure'),'outcome','A','reasoning','B','linkedObjectIds',jsonb_build_array((select id from vc_objects where kind='PROBLEM'))));raise exception 'No rollback';exception when check_violation then null;end;end $$;
reset role;drop trigger df_failure on public.decision_links;
create trigger df_failure before insert on public.change_log for each row execute function pg_temp.df_fail();
set local role authenticated;
do $$begin begin perform public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Log failure'),'outcome','A','reasoning','B','linkedObjectIds',jsonb_build_array((select id from vc_objects where kind='PROBLEM'))));raise exception 'No rollback';exception when check_violation then null;end;end $$;
reset role;drop trigger df_failure on public.change_log;
do $$declare did uuid;begin
 for did in select (payload#>>'{decision,id}')::uuid from df_drafts where label like '%failure' loop
  assert exists(select 1 from public.decisions where id=did and status='DRAFT' and outcome is null and reasoning is null and decided_at is null);
  assert not exists(select 1 from public.decision_options where decision_id=did and selected);
  assert not exists(select 1 from public.decision_participants where decision_id=did);
  assert not exists(select 1 from public.decision_links where decision_id=did);
  assert not exists(select 1 from public.change_log where entity_id=did and change_type='DECISION_FINALIZED');
 end loop;
end $$;
-- Demotion retains membership but never the old owner's elevated authority.
update public.teams set team_lead_user_id=null where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
update public.team_memberships set membership_role='member' where user_id='00000000-0000-4000-8000-000000006009' and status='active';
set local role authenticated;
do $$declare case_label text;begin
 for case_label in select unnest(array['Owner demoted','Team']) loop
  begin perform public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts f where f.label=case_label),'outcome','A','reasoning','B'));raise exception 'Owner retained elevated grant';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
update public.team_memberships set membership_role='team_lead' where user_id='00000000-0000-4000-8000-000000006009' and status='active';
update public.teams set team_lead_user_id='00000000-0000-4000-8000-000000006009' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
-- Owner loses scoped MASTER; current Team membership alone is insufficient.
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and role_id=(select id from public.roles where code='MASTER');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Master owner'),'outcome','Further work','reasoning','Human'));raise exception 'Stale Master retry';exception when insufficient_privilege then null;end;end $$;
reset role;
update public.role_assignments set status='active' where user_id='00000000-0000-4000-8000-000000006002' and role_id=(select id from public.roles where code='MASTER');
-- Current authorization remains required but historical Activity status permits retry.
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from vc_activities where n=2);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into df_results select 'Completed retry',public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}','outcome','No option','reasoning','Investigate')) from df_drafts where label='No selection';
reset role;
update public.activity_instances set status='archived' where id=(select id from vc_activities where n=2);
set local role authenticated;
insert into df_results select 'Archived retry',public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}','outcome','No option','reasoning','Investigate')) from df_drafts where label='No selection';
-- Direct clients cannot change status/selection/participant/link/event or read private rows.
do $$declare did uuid;begin
 select (payload#>>'{decision,id}')::uuid into did from df_drafts where label='Team';
 begin update public.decisions set status='FINALIZED',outcome='Forged',reasoning='Forged',decided_at=clock_timestamp() where id=did;raise exception 'Direct finalize';exception when insufficient_privilege then null;end;
 begin update public.decision_options set selected=true where decision_id=did;raise exception 'Direct selection';exception when insufficient_privilege then null;end;
 begin insert into public.decision_participants(decision_id,user_id,role) values(did,'00000000-0000-4000-8000-000000006009','FINALIZER');raise exception 'Direct participant';exception when insufficient_privilege then null;end;
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(did,'DEVELOPMENT_OBJECT',(select id from vc_objects where kind='PROBLEM'),'CONSIDERED_IN_DECISION');raise exception 'Direct link';exception when insufficient_privilege then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,changed_by,change_summary) values((select payload#>>'{decision,project_id}' from df_drafts where label='Team')::uuid,'DECISION',did,'DECISION_FINALIZED','00000000-0000-4000-8000-000000006009','Forged');raise exception 'Direct event';exception when insufficient_privilege then null;end;
 assert exists(select 1 from public.decisions where id=did),'M10.15 authorized scope read';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin begin perform public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Owner removed'),'outcome','A','reasoning','B'));raise exception 'Removed owner';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$declare d public.decisions;begin
 assert (select payload from df_results where label='Team')=(select payload from df_results where label='Retry');
 assert (select payload from df_results where label='No selection')=(select payload from df_results where label='Completed retry');
 assert (select payload from df_results where label='No selection')=(select payload from df_results where label='Archived retry');
 assert (select count(*) from public.decisions where status='FINALIZED')=7;
 assert (select count(*) from public.change_log where change_type='DECISION_FINALIZED')=7;
 assert (select count(*) from public.decision_participants)=7,'No bulk/retry participants';
 assert (select count(*) from public.decision_links)=3,'Exact links only';
 assert (select count(*) from public.decision_options where selected)=1;
 assert exists(select 1 from public.decision_participants where role='OBSERVER' and position='Before' and comment='Keep');
 assert not exists(select 1 from public.decisions persisted join df_drafts f on persisted.id=(f.payload#>>'{decision,id}')::uuid where persisted.decision_owner_user_id<>(f.payload#>>'{decision,decision_owner_user_id}')::uuid);
 select * into d from public.decisions where id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='Master different');
 assert d.decision_owner_user_id='00000000-0000-4000-8000-000000006009';
 assert exists(select 1 from public.decision_participants where decision_id=d.id and user_id='00000000-0000-4000-8000-000000006002' and role='FINALIZER');
 assert exists(select 1 from public.change_log where entity_id=d.id and change_type='DECISION_FINALIZED' and changed_by='00000000-0000-4000-8000-000000006002' and created_at=d.decided_at and related_decision_id=d.id);
 assert (select artifacts from df_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select objects from df_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
 assert (select versions from df_before)=(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v);
 assert (select baselines from df_before) is not distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b);
 assert not has_function_privilege('anon','public.finalize_decision(jsonb)','execute');
 assert not has_function_privilege('service_role','public.finalize_decision(jsonb)','execute');
 assert not has_function_privilege('authenticated','private.require_decision_finalization(uuid,uuid,uuid,boolean)','execute');
 assert (select proconfig @> array['search_path=""'] from pg_proc where oid='public.finalize_decision(jsonb)'::regprocedure);
 -- M10.12 adds the specialized supersession RPC; preserve its security boundary.
 assert has_function_privilege('authenticated','public.supersede_decision(jsonb)','execute');
 assert not has_function_privilege('anon','public.supersede_decision(jsonb)','execute');
 assert not has_function_privilege('service_role','public.supersede_decision(jsonb)','execute');
 assert (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.supersede_decision(jsonb)'::regprocedure);
 assert not exists(select 1 from pg_proc where proname='link_decision');
end $$;
\pset format unaligned
select 'M1010_FINALIZED='||payload::text from df_results where label='Team';
select 'M10.10 AT-DEC-001 M10 core / Personal-Team authority / demotion-removal / selection / participants / links / retry-conflict / rollback / lifecycle / direct denial / no source mutation PASS';
select 'AT-DEC-001 Evidence integration is verified by the canonical M12.18 scenario';
rollback;
