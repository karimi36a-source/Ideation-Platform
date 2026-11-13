-- Canonical creation, linking, finalization and supersession; no lifecycle writes.
reset role;
create temporary table ac_cases(label text primary key,id uuid);
insert into ac_cases select 'D1',(payload#>>'{decision,id}')::uuid from df_drafts where label='Team';
grant select,insert on ac_cases to authenticated;
create function pg_temp.ac_id(label0 text) returns uuid language sql as $$select id from ac_cases where label=label0$$;
create function pg_temp.ac_snapshot(id0 uuid) returns jsonb language sql as $$
 select jsonb_build_object('decision',to_jsonb(d),
 'options',(select jsonb_agg(to_jsonb(o) order by id) from public.decision_options o where decision_id=d.id),
 'participants',(select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p where decision_id=d.id),
 'links',(select jsonb_agg(to_jsonb(l) order by id) from public.decision_links l where decision_id=d.id and relationship_type<>'SUPERSEDES'))
 from public.decisions d where id=id0;
$$;
-- Participant metadata has no public creation API. Only this isolated historical
-- fixture is written by the trusted test owner; finalizers use the real RPC.
insert into public.decision_participants(decision_id,user_id,role,position,comment)
values(pg_temp.ac_id('D1'),'00000000-0000-4000-8000-000000006005','OBSERVER','Prior assessment','Preserve contextual history');
create temporary table ac_observer as select to_jsonb(p) payload from public.decision_participants p where decision_id=pg_temp.ac_id('D1');
create temporary table ac_sources as select
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v) versions,
 (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b) baselines,
 (select jsonb_agg(to_jsonb(v) order by id) from public.votes v) votes;
create temporary table ac_input(payload jsonb);
insert into ac_input select jsonb_build_object('decisionId',payload#>>'{decision,id}',
 'selectedOptionId',payload#>>'{options,1,id}','outcome','Investigate the alternative',
 'reasoning','Human assessment values feasibility over popularity',
 'linkedObjectIds',jsonb_build_array((select id from vc_objects where kind='SOLUTION')),
 'linkedArtifactIds',jsonb_build_array((select id from df_artifacts where label='Team'))) from df_drafts where label='Team';
grant select on ac_input to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
-- Voting is already closed, with PROBLEM highest and SOLUTION lower.
do $$declare r jsonb;begin
 r:=public.get_voting_results((select (payload#>>'{session,id}')::uuid from vc_results where jsonb_array_length(payload->'options')=3));
 assert exists(select 1 from jsonb_array_elements(r->'options') o where o->>'label'='PROBLEM' and o->>'voteCount'='1');
 assert exists(select 1 from jsonb_array_elements(r->'options') o where o->>'label'='SOLUTION' and o->>'voteCount'='0');
 assert (select status='DRAFT' and reasoning is null and outcome is null and decided_at is null from public.decisions where id=pg_temp.ac_id('D1'));
 assert not exists(select 1 from public.decision_options where decision_id=pg_temp.ac_id('D1') and selected);
end $$;
select public.link_decision_entity(jsonb_build_object('decisionId',pg_temp.ac_id('D1'),'linkedEntityType','DEVELOPMENT_OBJECT','linkedEntityId',id,'relationshipType','CONSIDERED_IN_DECISION')) from vc_objects where kind='SOLUTION';
select public.link_decision_entity(jsonb_build_object('decisionId',pg_temp.ac_id('D1'),'linkedEntityType','ARTIFACT','linkedEntityId',id,'relationshipType','CONSIDERED_IN_DECISION')) from df_artifacts where label='Team';
select public.link_decision_entity(jsonb_build_object('decisionId',pg_temp.ac_id('D1'),'linkedEntityType','VOTING_SESSION','linkedEntityId',payload#>>'{session,id}','relationshipType','INFORMED_BY')) from vc_results where jsonb_array_length(payload->'options')=3;
select public.finalize_decision(payload) from ac_input;
reset role;
create temporary table ac_history(label text primary key,payload jsonb);
insert into ac_history values('D1',pg_temp.ac_snapshot(pg_temp.ac_id('D1')));
grant select on ac_history to authenticated;
do $$declare d public.decisions;begin
 select * into d from public.decisions where id=pg_temp.ac_id('D1');
 assert d.status='FINALIZED' and d.question='What next?' and d.title='Human decision' and d.method='DISCUSSION';
 assert d.outcome='Investigate the alternative' and d.reasoning='Human assessment values feasibility over popularity';
 assert d.decision_owner_user_id='00000000-0000-4000-8000-000000006009';
 assert d.project_id=(select (payload->>'id')::uuid from logged_projects where label='Team');
 assert d.workspace_id=(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team');
 assert d.activity_instance_id=(select id from vc_activities where n=2);
 assert d.decided_at is not null and d.decided_at<=clock_timestamp();
 assert d.decided_at<>(select closed_at from public.voting_sessions where id=(select (payload#>>'{session,id}')::uuid from vc_results where jsonb_array_length(payload->'options')=3));
 assert exists(select 1 from public.decision_participants p where decision_id=d.id and user_id='00000000-0000-4000-8000-000000006002' and role='FINALIZER');
 assert (select count(*) from public.decision_participants where decision_id=d.id)=2;
 assert exists(select 1 from ac_observer h join public.decision_participants p on to_jsonb(p)=h.payload);
 assert (select count(*) from public.decision_options where decision_id=d.id and selected)=1;
 assert exists(select 1 from public.decision_options where decision_id=d.id and development_object_id=(select id from vc_objects where kind='SOLUTION') and selected);
 assert (select count(*) from public.decision_links where decision_id=d.id)=3;
 assert exists(select 1 from public.decision_links where decision_id=d.id and linked_entity_type='DEVELOPMENT_OBJECT' and linked_entity_id=(select id from vc_objects where kind='SOLUTION') and relationship_type='CONSIDERED_IN_DECISION');
 assert exists(select 1 from public.decision_links where decision_id=d.id and linked_entity_type='ARTIFACT' and linked_entity_id=(select id from df_artifacts where label='Team') and relationship_type='CONSIDERED_IN_DECISION');
 assert exists(select 1 from public.decision_links where decision_id=d.id and linked_entity_type='VOTING_SESSION' and relationship_type='INFORMED_BY');
end $$;
create function pg_temp.ac_denied(command text) returns void language plpgsql as $$
begin begin execute command;exception when insufficient_privilege then return;end;raise exception 'Direct Decision forge accepted';end $$;
set local role authenticated;
do $$declare field text;begin
 foreach field in array array['status','outcome','reasoning','decided_at','decision_owner_user_id'] loop
  perform pg_temp.ac_denied(format('update public.decisions set %I=%I where id=%L',field,field,pg_temp.ac_id('D1')));
 end loop;
 perform pg_temp.ac_denied(format('update public.decision_options set selected=true where decision_id=%L',pg_temp.ac_id('D1')));
 perform pg_temp.ac_denied(format('insert into public.decision_participants(decision_id,user_id,role) values(%L,%L,''OBSERVER'')',pg_temp.ac_id('D1'),auth.uid()));
 perform pg_temp.ac_denied(format('insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(%L,''DEVELOPMENT_OBJECT'',%L,''CONSIDERED_IN_DECISION'')',pg_temp.ac_id('D1'),(select id from vc_objects where kind='PROBLEM')));
end $$;
reset role;
-- Logout clears the verified identity; reload must come from persisted rows.
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
do $$begin assert not exists(select 1 from public.decisions where id=pg_temp.ac_id('D1'));end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.finalize_decision(payload) from ac_input;
select public.get_voting_results((payload#>>'{session,id}')::uuid) from vc_results where jsonb_array_length(payload->'options')=3;
do $$begin assert pg_temp.ac_snapshot(pg_temp.ac_id('D1'))=(select payload from ac_history where label='D1');end $$;
reset role;
do $$begin assert (select count(*) from public.change_log where entity_id=pg_temp.ac_id('D1') and change_type='DECISION_FINALIZED')=1;end $$;
select 'M10.17 AT-DEC-001 canonical fields/reload/participant-history/server-time/non-top-selection/three-links/idempotency PASS';
select 'AT-DEC-001 Evidence integration is verified by the canonical M12.18 scenario';
-- D2 and D3 are created/finalized later, using the same canonical scope.
set local role authenticated;
insert into ac_cases select label,(public.create_decision(jsonb_build_object('projectId',d.project_id,'workspaceId',d.workspace_id,'activityInstanceId',d.activity_instance_id,'title',label,'question','Later evaluation','method','DISCUSSION','options','[{"label":"Human replacement"}]'::jsonb))#>>'{decision,id}')::uuid
from public.decisions d cross join unnest(array['D2','D3']) label where d.id=pg_temp.ac_id('D1');
select public.finalize_decision(jsonb_build_object('decisionId',id,'selectedOptionId',(select id from public.decision_options where decision_id=ac_cases.id),'outcome','Later explicit outcome','reasoning','Later explicit human reasoning')) from ac_cases where label in ('D2','D3') order by label;
reset role;
insert into ac_history select label,pg_temp.ac_snapshot(id) from ac_cases where label in ('D2','D3');
set local role authenticated;
select public.supersede_decision(jsonb_build_object('oldDecisionId',pg_temp.ac_id('D1'),'newDecisionId',pg_temp.ac_id('D2')));
select public.supersede_decision(jsonb_build_object('oldDecisionId',pg_temp.ac_id('D1'),'newDecisionId',pg_temp.ac_id('D2')));
do $$begin
 assert jsonb_set(pg_temp.ac_snapshot(pg_temp.ac_id('D1')),'{decision,status}','"FINALIZED"')=(select payload from ac_history where label='D1');
 assert pg_temp.ac_snapshot(pg_temp.ac_id('D2'))=(select payload from ac_history where label='D2');
 assert exists(select 1 from public.decisions where id=pg_temp.ac_id('D1') and status='SUPERSEDED' and reasoning='Human assessment values feasibility over popularity');
 assert exists(select 1 from public.decisions where id=pg_temp.ac_id('D2') and status='FINALIZED');
 assert (select count(*) from public.decision_links where decision_id=pg_temp.ac_id('D2') and linked_entity_id=pg_temp.ac_id('D1') and relationship_type='SUPERSEDES' and linked_entity_type='DECISION')=1;
 assert (select count(*) from public.change_log where entity_id=pg_temp.ac_id('D1') and related_decision_id=pg_temp.ac_id('D2') and changed_by=auth.uid() and change_type='DECISION_SUPERSEDED')=1;
end $$;
select public.supersede_decision(jsonb_build_object('oldDecisionId',pg_temp.ac_id('D2'),'newDecisionId',pg_temp.ac_id('D3')));
do $$begin
 assert (select count(*) from public.decisions where id in(select id from ac_cases))=3;
 assert (select count(*) from public.decision_links l join ac_cases a on a.id=l.decision_id join ac_cases b on b.id=l.linked_entity_id where l.relationship_type='SUPERSEDES' and l.linked_entity_type='DECISION')=2;
 assert jsonb_set(pg_temp.ac_snapshot(pg_temp.ac_id('D2')),'{decision,status}','"FINALIZED"')=(select payload from ac_history where label='D2');
 assert pg_temp.ac_snapshot(pg_temp.ac_id('D3'))=(select payload from ac_history where label='D3');
end $$;
reset role;
do $$begin
 assert (select objects from ac_sources)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
 assert (select artifacts from ac_sources)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select versions from ac_sources)=(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v);
 assert (select baselines from ac_sources) is not distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b);
 assert (select votes from ac_sources)=(select jsonb_agg(to_jsonb(v) order by id) from public.votes v);
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 perform pg_temp.ac_denied(format('update public.decisions set status=''SUPERSEDED'' where id=%L',pg_temp.ac_id('D3')));
 perform pg_temp.ac_denied(format('delete from public.decisions where id=%L',pg_temp.ac_id('D1')));
 perform pg_temp.ac_denied(format('update public.decisions set reasoning=''Overwrite'' where id=%L',pg_temp.ac_id('D1')));
 perform pg_temp.ac_denied(format('update public.decision_links set decision_id=%L,linked_entity_id=%L where decision_id=%L and relationship_type=''SUPERSEDES''',pg_temp.ac_id('D1'),pg_temp.ac_id('D2'),pg_temp.ac_id('D2')));
 perform pg_temp.ac_denied(format('delete from public.decision_links where decision_id=%L',pg_temp.ac_id('D2')));
 perform pg_temp.ac_denied(format('insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(%L,''DECISION'',%L,''SUPERSEDES'')',pg_temp.ac_id('D1'),pg_temp.ac_id('D3')));
end $$;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009',null);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005',null);
do $$declare who text;begin
 foreach who in array array['000000006007','000000006009','000000006005'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||who,true);
  assert not exists(select 1 from public.decisions where id in (select id from ac_cases));
  assert not exists(select 1 from public.decision_options where decision_id=pg_temp.ac_id('D1'));
  assert not exists(select 1 from public.decision_participants where decision_id=pg_temp.ac_id('D1'));
  assert not exists(select 1 from public.decision_links where decision_id=pg_temp.ac_id('D1'));
 end loop;
end $$;
reset role;
do $$begin assert jsonb_set(pg_temp.ac_snapshot(pg_temp.ac_id('D1')),'{decision,status}','"FINALIZED"')=(select payload from ac_history where label='D1');end $$;
select 'M10.17 AT-DEC-002 D1-D2 snapshots/current-scope-history/exact-event/retry/D3-chain/source-preservation PASS';
rollback;
