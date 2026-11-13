reset role;
-- A real Draft proves that results do not select/finalize a human Decision.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','Voting read-only boundary','question','Human choice remains pending','method','DISCUSSION','options','[{"label":"Human option A"},{"label":"Human option B"}]'::jsonb)) from logged_projects where label='Team';
reset role;
create function pg_temp.voting_decision_boundary() returns jsonb language sql as $$
 select jsonb_build_object(
  'objects',(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),
  'activities',(select jsonb_agg(to_jsonb(a) order by id) from public.activity_instances a),
  'sources',(select jsonb_agg(to_jsonb(s) order by artifact_id) from public.artifact_decision_sources s),
  'decisions',(select jsonb_agg(to_jsonb(d) order by id) from public.decisions d),
  'options',(select jsonb_agg(to_jsonb(o) order by id) from public.decision_options o),
  'participants',(select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p),
  'links',(select jsonb_agg(to_jsonb(l) order by id) from public.decision_links l),
  'decision_events',(select jsonb_agg(to_jsonb(c) order by id) from public.change_log c where change_type in ('DECISION_CREATED','DECISION_FINALIZED')),
  'baselines',(select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b),
  'projects',(select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p),
  'artifacts',(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a),
  'versions',(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v));
$$;
create temporary table voting_decision_before as select pg_temp.voting_decision_boundary() payload;
do $$begin
 assert (select count(*) from public.decisions)=1;
 assert (select count(*) from public.decision_options)=2;
 assert not exists(select 1 from public.decisions where status<>'DRAFT' or outcome is not null or reasoning is not null or decided_at is not null);
 assert not exists(select 1 from public.decision_options where selected);
end $$;
create temporary table result_cases as select case when jsonb_array_length(payload->'options')=3 then 'live' when payload#>>'{session,activity_instance_id}'=(select id::text from vc_activities where n=1) then 'zero_hidden' when jsonb_array_length(payload->'options')=2 then 'hidden' else 'zero_live' end label,(payload#>>'{session,id}')::uuid id from vc_results;
grant select,insert on result_cases to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
-- Use approved creation to get a non-zero-limit hidden Session.
insert into result_cases select 'hidden_votes',(public.create_voting_session((select id from vc_activities where n=1),'DOT_VOTE',3,true,'HIDDEN_UNTIL_REVEAL','[{"label":"One"},{"label":"Two"}]')#>>'{session,id}')::uuid;
do $$declare s uuid;r jsonb;begin for s in select id from result_cases loop
 r:=public.get_voting_results(s);assert r->'totalVotes'='null'::jsonb;
 perform public.open_voting_session(s);
end loop;end $$;
reset role;
create temporary table result_options as select o.* from public.voting_options o join result_cases c on c.id=o.voting_session_id;
grant select on result_options to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.cast_vote(voting_session_id,id,1) from result_options where sequence=2 and voting_session_id in (select id from result_cases where label in ('live','hidden_votes'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.cast_vote(voting_session_id,id,1) from result_options where sequence in (1,2) and voting_session_id in (select id from result_cases where label in ('live','hidden_votes'));
reset role;
create temporary table result_state as select jsonb_build_object('votes',(select jsonb_agg(to_jsonb(v) order by id) from public.votes v),'logs',(select jsonb_agg(to_jsonb(l) order by id) from public.change_log l),'sessions',(select jsonb_agg(to_jsonb(s) order by id) from public.voting_sessions s),'objects',(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),'projects',(select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p),'artifacts',(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a)) payload;
grant select on result_state to authenticated;
set local role authenticated;
do $$declare n int;r jsonb;s uuid;begin
 foreach n in array array[6002,6004,6005,6009] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 r:=public.get_voting_results((select id from result_cases where label='live'));
 assert r->>'totalVotes'='3';assert r#>>'{options,0,voteCount}'='1';assert r#>>'{options,1,voteCount}'='2';assert r#>>'{options,2,voteCount}'='0';
 assert r#>>'{options,0,sequence}'='1';assert r#>>'{options,1,sequence}'='2';assert r#>>'{options,2,sequence}'='3';
 assert r#>>'{options,0,developmentObject,id}'=(select development_object_id::text from result_options where sequence=1 and voting_session_id=(select id from result_cases where label='live'));
 assert (select count(*) from jsonb_object_keys(r#>'{options,0,developmentObject}'))=4;
 assert (select count(*) from jsonb_object_keys(r))=3;
 assert not r::text like '%user_id%';assert not r::text like '%winner%';assert not r::text like '%created_by%';
 for s in select id from result_cases where label in ('zero_hidden','hidden','hidden_votes') loop
 r:=public.get_voting_results(s);assert r->'totalVotes'='null'::jsonb;assert r#>'{options,0,voteCount}'='null'::jsonb;assert r#>>'{session,revealed}'='false';end loop;
 r:=public.get_voting_results((select id from result_cases where label='zero_live'));assert r->>'totalVotes'='0';assert r#>>'{options,0,voteCount}'='0';
 begin perform * from public.votes;raise exception 'Raw Vote SELECT allowed';exception when insufficient_privilege then null;end;
 end loop;
 foreach n in array array[6001,6003,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.get_voting_results((select id from result_cases where label='live'));raise exception 'Unauthorized result';exception when insufficient_privilege then null;end;
 begin perform public.get_voting_results('ffffffff-ffff-4fff-8fff-ffffffffffff');raise exception 'Missing resource';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
do $$begin assert (select payload from result_state)=jsonb_build_object('votes',(select jsonb_agg(to_jsonb(v) order by id) from public.votes v),'logs',(select jsonb_agg(to_jsonb(l) order by id) from public.change_log l),'sessions',(select jsonb_agg(to_jsonb(s) order by id) from public.voting_sessions s),'objects',(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),'projects',(select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p),'artifacts',(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a));end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare s uuid;r jsonb;begin for s in select id from result_cases loop perform public.close_voting_session(s);end loop;
 r:=public.get_voting_results((select id from result_cases where label='live'));assert r->>'totalVotes'='3';
 r:=public.get_voting_results((select id from result_cases where label='hidden_votes'));assert r->'totalVotes'='null'::jsonb;assert r#>>'{session,revealed}'='false';
 perform public.reveal_voting_session((select id from result_cases where label='hidden_votes'));
 r:=public.get_voting_results((select id from result_cases where label='hidden_votes'));assert r->>'totalVotes'='3';assert r#>>'{options,0,voteCount}'='1';assert r#>>'{options,1,voteCount}'='2';assert r#>>'{session,revealed}'='true';
 perform public.reveal_voting_session((select id from result_cases where label='zero_hidden'));
 r:=public.get_voting_results((select id from result_cases where label='zero_hidden'));assert r->>'totalVotes'='0';assert r#>>'{options,0,voteCount}'='0';assert r#>>'{session,revealed}'='true';
end $$;
reset role;
-- Exercise the scoped-Master branch separately from member/team_lead viewer access.
-- Contextual mentor membership retains existing read-only Project/Workspace scope;
-- only the exact MASTER role makes this actor a permitted voting-results viewer.
reset role;
do $$declare r jsonb;begin begin
 update public.team_memberships set membership_role='mentor' where team_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A') and user_id='00000000-0000-4000-8000-000000006002' and status='active';
 set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 r:=public.get_voting_results((select id from result_cases where label='live'));assert r->>'totalVotes'='3';
 reset role;
 update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and role_id=(select id from public.roles where code='MASTER');
 set local role authenticated;
 begin perform public.get_voting_results((select id from result_cases where label='live'));raise exception 'Stale Master scope';exception when insufficient_privilege then null;end;
 reset role;raise exception 'Discard' using errcode='P0002';exception when no_data_found then null;end;end $$;
-- A tied distribution stays in sequence order and carries no winner semantics.
reset role;
do $$declare r jsonb;begin begin
 delete from public.votes where voting_session_id=(select id from result_cases where label='live') and voting_option_id=(select id from result_options where sequence=2 and voting_session_id=(select id from result_cases where label='live')) and user_id='00000000-0000-4000-8000-000000006005';
 set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 r:=public.get_voting_results((select id from result_cases where label='live'));
 assert r->>'totalVotes'='2';assert r#>>'{options,0,voteCount}'='1';assert r#>>'{options,1,voteCount}'='1';
 assert r#>>'{options,0,sequence}'='1';assert r#>>'{options,1,sequence}'='2';assert not r::text like '%winner%';
 reset role;raise exception 'Discard' using errcode='P0002';exception when no_data_found then null;end;end $$;
-- Trusted corrupt/reordered/foreign fixtures are isolated, not product mutation paths.
do $$declare state public.activity_instance_status;r jsonb;begin
 foreach state in array array['completed','archived']::public.activity_instance_status[] loop begin
 update public.activity_instances set status=state,completed_at=case when state='completed' then clock_timestamp() else null end where id=(select id from vc_activities where n=1);
 set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 r:=public.get_voting_results((select id from result_cases where label='live'));assert r->>'totalVotes'='3';
 reset role;raise exception 'Discard' using errcode='P0002';exception when no_data_found then null;end;end loop;
 begin update public.votes set revealed_at=null where id=(select id from public.votes where voting_session_id=(select id from result_cases where label='hidden_votes') limit 1);
 set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 begin perform public.get_voting_results((select id from result_cases where label='hidden_votes'));raise exception 'Partial reveal leak';exception when object_not_in_prerequisite_state then null;end;
 reset role;raise exception 'Discard' using errcode='P0002';exception when no_data_found then null;end;
 begin update public.voting_options set development_object_id=(select id from vc_foreign_objects limit 1) where id=(select id from result_options where sequence=1 and voting_session_id=(select id from result_cases where label='live'));
 set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 begin perform public.get_voting_results((select id from result_cases where label='live'));raise exception 'Foreign Object exposed';exception when insufficient_privilege then null;end;
 reset role;raise exception 'Discard' using errcode='P0002';exception when no_data_found then null;end;
 begin update public.voting_sessions set voting_type='FIST_TO_FIVE' where id=(select id from result_cases where label='live');
 set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 begin perform public.get_voting_results((select id from result_cases where label='live'));raise exception 'Future runtime supported';exception when feature_not_supported then null;end;
 reset role;raise exception 'Discard' using errcode='P0002';exception when no_data_found then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.get_voting_results((select id from result_cases where label='live'));raise exception 'Removed voter bypass';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert exists(select 1 from pg_proc where oid='public.get_voting_results(uuid)'::regprocedure and provolatile='s' and prosecdef and proconfig=array['search_path=""']);
 assert not has_function_privilege('anon','public.get_voting_results(uuid)','execute');
 assert not has_function_privilege('service_role','public.get_voting_results(uuid)','execute');
 assert not has_table_privilege('authenticated','public.votes','select');
 assert not exists(select 1 from pg_proc where proname='reopen_voting_session');
 assert strpos(pg_get_functiondef('public.get_voting_results(uuid)'::regprocedure),'finalize_decision')=0;
 assert strpos(pg_get_functiondef('public.get_voting_results(uuid)'::regprocedure),'create_decision')=0;
end $$;
set local role anon;
do $$begin begin perform public.get_voting_results('ffffffff-ffff-4fff-8fff-ffffffffffff');raise exception 'Anonymous access';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert (select payload from voting_decision_before)=pg_temp.voting_decision_boundary(),'Voting Results mutated Decision/history/baseline/Artifact state';
 assert not exists(select 1 from public.decisions where status='FINALIZED');
 assert not exists(select 1 from public.decision_options where selected);
 assert not exists(select 1 from public.change_log where change_type='DECISION_FINALIZED');
end $$;
select 'M10.7 Voting Results preserves Draft/Options/outcome/reasoning/participants/links/events/baselines/Artifacts PASS';
select 'M10.7 result visibility/count/order/scope/identity/reveal/snapshot/read-only/grants PASS';
rollback;
