reset role;
create temporary table de_before as select (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,(select jsonb_agg(to_jsonb(h) order by id) from public.evidence_verification_history h) history;
-- Existing participant is preserved alongside the verified finalizer.
insert into public.decision_participants(decision_id,user_id,role,position,comment) values(pg_temp.de_id('Main'),'00000000-0000-4000-8000-000000006004','OBSERVER','Investigate','Existing human contribution');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.finalize_decision(pg_temp.de_args('One',array[pg_temp.de_source('UNVERIFIED')]));
select public.finalize_decision(pg_temp.de_args('Main',array[pg_temp.de_source('UNVERIFIED'),pg_temp.de_source('VERIFIED'),pg_temp.de_source('CONTRADICTED'),pg_temp.de_source('PARTIALLY_VERIFIED'),pg_temp.de_source('NEEDS_REVIEW'),pg_temp.de_source('UNVERIFIED')]));
reset role;
create temporary table de_finalized as select pg_temp.de_snapshot(pg_temp.de_id('Main')) payload;
set local role authenticated;
select public.finalize_decision(pg_temp.de_args('Main',array[pg_temp.de_source('NEEDS_REVIEW'),pg_temp.de_source('CONTRADICTED'),pg_temp.de_source('VERIFIED'),pg_temp.de_source('UNVERIFIED'),pg_temp.de_source('PARTIALLY_VERIFIED')]));
do $$declare d public.decisions;begin
 select * into d from public.decisions where id=pg_temp.de_id('Main');
 assert d.status='FINALIZED' and d.question='Which approach should we investigate?' and d.outcome='Investigate human alternative' and d.reasoning='Human assessment of source confidence and uncertainty' and d.decided_at is not null;
 assert (select count(*) from public.decision_participants where decision_id=d.id)=2;
 assert exists(select 1 from public.decision_participants where decision_id=d.id and user_id='00000000-0000-4000-8000-000000006005' and role='FINALIZER');
 assert (select count(*) from public.evidence_links where linked_entity_type='DECISION' and linked_entity_id=d.id and relationship_type='SUPPORTS' and archived_at is null)=5;
 assert (select array_agg(e.verification_status::text order by e.verification_status::text) from public.evidence_links l join public.evidence e on e.id=l.evidence_id where l.linked_entity_type='DECISION' and l.linked_entity_id=d.id)=array['CONTRADICTED','NEEDS_REVIEW','PARTIALLY_VERIFIED','UNVERIFIED','VERIFIED'],'Every confidence state is queryable with the Decision';
 assert not exists(select 1 from public.decision_links where decision_id=d.id and linked_entity_type='EVIDENCE'),'One canonical link model only';
end$$;
-- Missing/foreign IDs fail the complete request, even with an authorized first ID.
select pg_temp.de_bad(pg_temp.de_args('Invalid',array[pg_temp.de_source('UNVERIFIED'),'00000000-0000-4000-8000-000000999999'::uuid]));
select pg_temp.de_bad(pg_temp.de_args('Foreign',array[pg_temp.de_source('UNVERIFIED'),pg_temp.de_source('Team B')]));
select pg_temp.de_bad(pg_temp.de_args('Foreign',array[pg_temp.de_source('Personal')]));
select pg_temp.de_bad(pg_temp.de_args('Foreign',array[pg_temp.de_source('Other Project')]));
select pg_temp.de_bad(pg_temp.de_args('Team B',array[pg_temp.de_source('UNVERIFIED')]));
select pg_temp.de_bad(pg_temp.de_args('Main',array[pg_temp.de_source('Extra')]),'40001');
reset role;
-- Failure after canonical link creation rolls every resource back.
create function pg_temp.de_fail() returns trigger language plpgsql as $$begin raise exception 'Forced Decision Evidence failure' using errcode='23514';end$$;
create trigger de_failure before insert on public.evidence_links for each row execute function pg_temp.de_fail();
set local role authenticated;
select pg_temp.de_bad(pg_temp.de_args('Link failure',array[pg_temp.de_source('UNVERIFIED')]),'23514');
reset role;drop trigger de_failure on public.evidence_links;
create trigger de_failure before insert on public.change_log for each row when(new.change_type='DECISION_FINALIZED') execute function pg_temp.de_fail();
set local role authenticated;
select pg_temp.de_bad(pg_temp.de_args('Log failure',array[pg_temp.de_source('UNVERIFIED')]),'23514');
reset role;drop trigger de_failure on public.change_log;
create trigger de_failure before insert on public.decision_participants for each row execute function pg_temp.de_fail();
set local role authenticated;
select pg_temp.de_bad(pg_temp.de_args('Participant failure',array[pg_temp.de_source('UNVERIFIED')]),'23514');
reset role;drop trigger de_failure on public.decision_participants;
do $$declare label0 text;begin
 assert pg_temp.de_snapshot(pg_temp.de_id('Main'))=(select payload from de_finalized),'Identical retry preserves every field, participant, link and event';
 foreach label0 in array array['Invalid','Foreign','Link failure','Log failure','Participant failure'] loop
  assert exists(select 1 from public.decisions where id=pg_temp.de_id(label0) and status='DRAFT' and outcome is null and reasoning is null and decided_at is null);
  assert not exists(select 1 from public.evidence_links where linked_entity_type='DECISION' and linked_entity_id=pg_temp.de_id(label0));
  assert not exists(select 1 from public.decision_participants where decision_id=pg_temp.de_id(label0));
  assert not exists(select 1 from public.decision_options where decision_id=pg_temp.de_id(label0) and selected);
  assert not exists(select 1 from public.change_log where entity_id=pg_temp.de_id(label0) and change_type='DECISION_FINALIZED');
 end loop;
end$$;
-- Existing finalized Decision attachments use the unchanged approved link authority.
set local role authenticated;
select public.finalize_decision(pg_temp.de_args('Existing',array[]::uuid[]));
reset role;
create temporary table de_existing as select pg_temp.de_snapshot(pg_temp.de_id('Existing')) payload;
set local role authenticated;
select public.link_evidence(jsonb_build_object('evidenceId',pg_temp.de_source('Extra'),'entityType','DECISION','entityId',pg_temp.de_id('Existing'),'relationshipType','SUPPORTS'));
select public.link_evidence(jsonb_build_object('evidenceId',pg_temp.de_source('Extra'),'entityType','DECISION','entityId',pg_temp.de_id('Existing'),'relationshipType','SUPPORTS'));
reset role;
do $$begin
 assert (pg_temp.de_snapshot(pg_temp.de_id('Existing'))-'links')=((select payload from de_existing)-'links'),'Post-finalization attachment never rewrites Decision history';
 assert (select count(*) from public.evidence_links where linked_entity_type='DECISION' and linked_entity_id=pg_temp.de_id('Existing'))=1;
end$$;
-- Supersession retains old links and does not copy them into the successor.
set local role authenticated;
select public.finalize_decision(pg_temp.de_args('New',array[]::uuid[]));
select public.supersede_decision(jsonb_build_object('oldDecisionId',pg_temp.de_id('Main'),'newDecisionId',pg_temp.de_id('New')));
reset role;
do $$begin
 assert (pg_temp.de_snapshot(pg_temp.de_id('Main'))#>'{decision,outcome}')=((select payload from de_finalized)#>'{decision,outcome}');
 assert (pg_temp.de_snapshot(pg_temp.de_id('Main'))#>'{decision,reasoning}')=((select payload from de_finalized)#>'{decision,reasoning}');
 assert (pg_temp.de_snapshot(pg_temp.de_id('Main'))#>'{decision,decided_at}')=((select payload from de_finalized)#>'{decision,decided_at}');
 assert (pg_temp.de_snapshot(pg_temp.de_id('Main'))->'participants')=((select payload from de_finalized)->'participants');
 assert (pg_temp.de_snapshot(pg_temp.de_id('Main'))->'links')=((select payload from de_finalized)->'links');
 assert not exists(select 1 from public.evidence_links where linked_entity_type='DECISION' and linked_entity_id=pg_temp.de_id('New'));
end$$;
-- An Evidence reader without current finalization authority cannot finalize.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.de_bad(pg_temp.de_args('Denied',array[pg_temp.de_source('UNVERIFIED')]));
select public.finalize_decision(pg_temp.de_args('Personal',array[pg_temp.de_source('Personal')]));
do $$begin begin insert into public.evidence_links(evidence_id,linked_entity_type,linked_entity_id,relationship_type) values(pg_temp.de_source('UNVERIFIED'),'DECISION',pg_temp.de_id('Denied'),'SUPPORTS');raise exception 'Forged link';exception when insufficient_privilege then null;end;end$$;
do $$declare n int;begin foreach n in array array[6001,6002,6003,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 perform pg_temp.de_bad(pg_temp.de_args('Denied',array[pg_temp.de_source('UNVERIFIED')]));
 assert not exists(select 1 from public.evidence_links where linked_entity_type='DECISION' and linked_entity_id=pg_temp.de_id('One'));
 assert not exists(select 1 from public.evidence where id=pg_temp.de_source('UNVERIFIED'));
end loop;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.de_bad(pg_temp.de_args('Denied',array[pg_temp.de_source('UNVERIFIED')]));
do $$begin assert not exists(select 1 from public.evidence_links where linked_entity_type='DECISION' and linked_entity_id=pg_temp.de_id('One'));assert not exists(select 1 from public.evidence where id=pg_temp.de_source('UNVERIFIED'));end$$;
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e)=(select evidence from de_before),'Full Evidence bodies/source/verification/claim metadata unchanged';
 assert (select jsonb_agg(to_jsonb(h) order by id) from public.evidence_verification_history h)=(select history from de_before),'Verification history unchanged';
 assert not has_table_privilege('authenticated','public.evidence_links','INSERT');
 assert not has_function_privilege('anon','public.finalize_decision(jsonb)','EXECUTE');
 assert not has_function_privilege('service_role','public.finalize_decision(jsonb)','EXECUTE');
 assert has_function_privilege('authenticated','public.finalize_decision(jsonb)','EXECUTE');
 assert exists(select 1 from pg_proc where oid='public.finalize_decision(jsonb)'::regprocedure and prosecdef and proconfig @> array['search_path=""']);
end$$;
select 'M12.18 AT-DEC-001 canonical SUPPORTS/all-five-statuses/independent-access/scope/duplicates/retry/atomic-rollback/history/supersession/no-verification/no-ACL/direct-DML PASS';
rollback;
