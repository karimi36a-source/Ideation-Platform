begin;
create function pg_temp.s5(label0 text) returns uuid language sql as $$select id from public.m1018_ids where label=label0$$;
create temporary table s5_history as select
 (select jsonb_agg(to_jsonb(v) order by id) from public.votes v where voting_session_id=pg_temp.s5('Voting')) votes,
 (select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p where decision_id=pg_temp.s5('Decision')) participants;
create function pg_temp.s5_denied(command text) returns void language plpgsql as $$
begin begin execute command;exception when insufficient_privilege then return;end;raise exception 'Session 5 scope attack succeeded';end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member(pg_temp.s5('Team'),'00000000-0000-4000-8000-000000006004',null);
do $$declare who text;b uuid;begin
 foreach who in array array['000000006007','000000006004'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||who,true);
  assert not exists(select 1 from public.artifacts where id in(pg_temp.s5('ProblemBank'),pg_temp.s5('SolutionBank'),pg_temp.s5('Record')));
  assert not exists(select 1 from public.artifact_versions where id in(pg_temp.s5('ProblemBankVersion'),pg_temp.s5('SolutionBankVersion'),pg_temp.s5('RecordVersion')));
  assert not exists(select 1 from public.activity_instances where id in(pg_temp.s5('Activity'),pg_temp.s5('Downstream')));
  assert public.resume_activity(pg_temp.s5('Activity')) is null;
  assert not exists(select 1 from public.voting_sessions where id=pg_temp.s5('Voting'));
  assert not exists(select 1 from public.voting_options where voting_session_id=pg_temp.s5('Voting'));
  assert not exists(select 1 from public.decisions where id=pg_temp.s5('Decision'));
  assert not exists(select 1 from public.decision_participants where decision_id=pg_temp.s5('Decision'));
  assert not exists(select 1 from public.artifact_decision_sources where artifact_id=pg_temp.s5('Record'));
  perform pg_temp.s5_denied(format('select public.cast_vote(%L,%L,1)',pg_temp.s5('Voting'),(select (o->>'id')::uuid from public.m1018_data d,jsonb_array_elements(d.payload->'options') o where d.label='Voting' limit 1)));
  perform pg_temp.s5_denied(format('select public.finalize_decision(%L::jsonb)',jsonb_build_object('decisionId',pg_temp.s5('Decision'),'outcome','Spoof','reasoning','Spoof')::text));
  perform pg_temp.s5_denied(format('select public.link_decision_entity(%L::jsonb)',jsonb_build_object('decisionId',pg_temp.s5('Decision'),'linkedEntityType','ARTIFACT','linkedEntityId',pg_temp.s5('ProblemBank'),'relationshipType','CONSIDERED_IN_DECISION')::text));
  perform pg_temp.s5_denied(format('select public.create_team_decision_record_artifact(%L)',pg_temp.s5('Decision')));
  perform pg_temp.s5_denied(format('select public.add_activity_artifact_input(%L,%L,%L,true)',pg_temp.s5('Downstream'),pg_temp.s5('Record'),pg_temp.s5('RecordVersion')));
  begin assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000001018802',pg_temp.s5('Project'),pg_temp.s5('Workspace'),pg_temp.s5('Team'))->>'satisfied'='false';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
do $$begin
 assert (select votes from s5_history)=(select jsonb_agg(to_jsonb(v) order by id) from public.votes v where voting_session_id=pg_temp.s5('Voting'));
 assert (select participants from s5_history)=(select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p where decision_id=pg_temp.s5('Decision'));
 assert exists(select 1 from public.team_memberships where team_id=pg_temp.s5('Team') and user_id='00000000-0000-4000-8000-000000006004' and status='removed' and left_at is not null);
end $$;
commit;
-- Independent reconnect after committed removal, with all exact IDs known.
begin read only;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.decisions where id=pg_temp.s5('Decision'));
 assert not exists(select 1 from public.artifacts where id=pg_temp.s5('Record'));
 assert public.resume_activity(pg_temp.s5('Activity')) is null;
end $$;
commit;
select 'M10.18 TeamB/removed-member/exact-ID/Activity-Banks-Voting-Decision-TDR-downstream denial/history PASS';
