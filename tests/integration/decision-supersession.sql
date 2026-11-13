reset role;
create temporary table sd_before as select
 (select jsonb_agg(to_jsonb(d) order by id) from public.decisions d) decisions,
 (select jsonb_agg(to_jsonb(o) order by id) from public.decision_options o) options,
 (select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p) participants,
 (select jsonb_agg(to_jsonb(l) order by id) from public.decision_links l) links,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b) baselines,
 (select jsonb_agg(to_jsonb(v) order by id) from public.voting_sessions v) voting;
-- State/chronology fixtures only; normal clients have no such write path.
update public.decisions set decided_at=(select decided_at from public.decisions where id=pg_temp.sid('EqualOld')) where id=pg_temp.sid('EqualNew');
update public.decisions set decided_at=(select decided_at-interval '1 second' from public.decisions where id=pg_temp.sid('EarlierOld')) where id=pg_temp.sid('EarlierNew');
update public.decisions set status='DRAFT' where id in (pg_temp.sid('DraftOld'),pg_temp.sid('DraftNew'));
update public.decisions set status='ARCHIVED' where id in (pg_temp.sid('ArchiveOld'),pg_temp.sid('ArchiveNew'));
update public.decisions set status='SUPERSEDED' where id=pg_temp.sid('SupersededNew');
set local role authenticated;
do $$declare who int;begin
 foreach who in array array[6001,6003,6004,6005,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who::text,12,'0'),true);
 perform pg_temp.denied('Old','New','42501');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
 perform pg_temp.denied('Old','Old','22023');
 perform pg_temp.denied('Old','PersonalNew','42501');perform pg_temp.denied('Old','ForeignNew','42501');
 perform pg_temp.denied('DraftOld','New','55000');perform pg_temp.denied('Old','DraftNew','55000');
 perform pg_temp.denied('ArchiveOld','New','55000');perform pg_temp.denied('Old','ArchiveNew','55000');
 perform pg_temp.denied('Old','SupersededNew','55000');
 perform pg_temp.denied('EqualOld','EqualNew','22023');perform pg_temp.denied('EarlierOld','EarlierNew','22023');
 begin perform public.supersede_decision(jsonb_build_object('oldDecisionId',pg_temp.sid('Old'),'newDecisionId',pg_temp.sid('New'),'role','MASTER'));raise exception 'Spoof';exception when invalid_parameter_value then null;end;
 begin perform public.link_decision_entity(jsonb_build_object('decisionId',pg_temp.sid('New'),'linkedEntityType','DECISION','linkedEntityId',pg_temp.sid('Old'),'relationshipType','SUPERSEDES'));raise exception 'Generic Decision links';exception when invalid_parameter_value then null;end;
end $$;
-- Canonical Personal authorization, not Team/platform authority.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.denied('PersonalOld','New','42501');
select pg_temp.sd('PersonalOld','PersonalNew');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.denied('PersonalOld','PersonalNew','42501');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare a jsonb;b jsonb;begin a:=pg_temp.sd('Old','New');b:=pg_temp.sd('Old','New');assert a=b;
 assert a->>'decision_id'=pg_temp.sid('New')::text and a->>'linked_entity_id'=pg_temp.sid('Old')::text;
 perform pg_temp.denied('Old','Third','40001');perform pg_temp.denied('OtherOld','New','40001');end $$;
reset role;
do $$begin
 assert (select status='SUPERSEDED' from public.decisions where id=pg_temp.sid('Old'));
 assert (select status='FINALIZED' from public.decisions where id=pg_temp.sid('New'));
 assert (select count(*) from public.change_log where entity_id=pg_temp.sid('Old') and change_type='DECISION_SUPERSEDED')=1;
 assert (select to_jsonb(d)-'status' from public.decisions d where id=pg_temp.sid('Old'))=(select x-'status' from sd_before,jsonb_array_elements(decisions) x where x->>'id'=pg_temp.sid('Old')::text);
 assert (select to_jsonb(d) from public.decisions d where id=pg_temp.sid('New'))=(select x from sd_before,jsonb_array_elements(decisions) x where x->>'id'=pg_temp.sid('New')::text);
 assert (select options from sd_before) is not distinct from (select jsonb_agg(to_jsonb(o) order by id) from public.decision_options o);
 assert not exists(select 1 from sd_before,jsonb_array_elements(links) x where not exists(select 1 from public.decision_links l where to_jsonb(l)=x));
 assert (select participants from sd_before) is not distinct from (select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p);
 assert not exists(select 1 from public.decision_links where decision_id=pg_temp.sid('Old') and linked_entity_id=pg_temp.sid('New'));
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.sd('New','Third');
select pg_temp.sd('ActivityRetryOld','ActivityRetryNew');
reset role;
do $$begin assert (select count(*) from public.decisions where id in (pg_temp.sid('Old'),pg_temp.sid('New'),pg_temp.sid('Third')))=3;
assert (select count(*) from public.decision_links where linked_entity_type='DECISION' and decision_id in (pg_temp.sid('New'),pg_temp.sid('Third')))=2;end $$;
-- Inject failures after status update and after relationship insertion.
create function pg_temp.fail_link() returns trigger language plpgsql as $$begin raise exception 'Injected relationship failure' using errcode='P0001';end $$;
create trigger sd_fail_link before insert on public.decision_links for each row execute function pg_temp.fail_link();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select pg_temp.denied('RollbackOld','RollbackNew','P0001');
reset role;drop trigger sd_fail_link on public.decision_links;
create function pg_temp.fail_log() returns trigger language plpgsql as $$begin raise exception 'Injected log failure' using errcode='P0001';end $$;
create trigger sd_fail_log before insert on public.change_log for each row execute function pg_temp.fail_log();
set local role authenticated;select pg_temp.denied('LogOld','LogNew','P0001');
reset role;drop trigger sd_fail_log on public.change_log;
do $$begin
 assert (select bool_and(status='FINALIZED') from public.decisions where id in (pg_temp.sid('RollbackOld'),pg_temp.sid('LogOld')));
 assert not exists(select 1 from public.decision_links where decision_id in (pg_temp.sid('RollbackNew'),pg_temp.sid('LogNew')));
 assert not exists(select 1 from public.change_log where change_type='DECISION_SUPERSEDED' and entity_id in (pg_temp.sid('RollbackOld'),pg_temp.sid('LogOld')));
end $$;
-- Revoked/demoted Lead or revoked Master cannot retry or create history.
reset role;
update public.team_memberships set membership_role='member' where user_id='00000000-0000-4000-8000-000000006009' and status='active';
set local role authenticated;
select pg_temp.denied('OtherOld','Race1New','42501');
select pg_temp.denied('ActivityRetryOld','ActivityRetryNew','42501');
reset role;
update public.team_memberships set membership_role='team_lead' where user_id='00000000-0000-4000-8000-000000006009' and status='active';
-- First mutation fails under completed Activity, exact retry remains read-only.
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select activity_instance_id from public.decisions where id=pg_temp.sid('ActivityOld'));
set local role authenticated;
select pg_temp.denied('ActivityOld','ActivityNew','55000');
select pg_temp.sd('ActivityRetryOld','ActivityRetryNew');
reset role;
update public.activity_instances set status='archived' where id=(select activity_instance_id from public.decisions where id=pg_temp.sid('ActivityOld'));
set local role authenticated;
select pg_temp.denied('ActivityOld','ActivityNew','55000');
select pg_temp.sd('ActivityRetryOld','ActivityRetryNew');
-- D2 is no longer FINALIZED after the chain; use Personal retry (no Activity).
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.sd('PersonalOld','PersonalNew');
reset role;
-- Retry never duplicates the event, including completed/archived Activity.
do $$begin assert (select count(*) from public.change_log where change_type='DECISION_SUPERSEDED' and entity_id=pg_temp.sid('ActivityRetryOld'))=1;end $$;
-- Current Master scope revocation removes authority even on retry.
create temporary table sd_roles_before as select id,status from public.role_assignments where user_id='00000000-0000-4000-8000-000000006002';
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.denied('ActivityRetryOld','ActivityRetryNew','42501');
reset role;
update public.role_assignments a set status=b.status from sd_roles_before b where a.id=b.id;
-- No mutation of independent canonical sources.
do $$begin
 assert (select objects from sd_before) is not distinct from (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
 assert (select artifacts from sd_before) is not distinct from (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select baselines from sd_before) is not distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b);
 assert (select voting from sd_before) is not distinct from (select jsonb_agg(to_jsonb(v) order by id) from public.voting_sessions v);
end $$;
set local role authenticated;
do $$begin
 begin update public.decisions set status='SUPERSEDED' where id=pg_temp.sid('OtherOld');raise exception 'Direct status';exception when insufficient_privilege then null;end;
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(pg_temp.sid('Third'),'DECISION',pg_temp.sid('OtherOld'),'SUPERSEDES');raise exception 'Direct link';exception when insufficient_privilege then null;end;
 begin delete from public.decision_links;raise exception 'Delete';exception when insufficient_privilege then null;end;
 begin update public.decision_links set linked_entity_id=pg_temp.sid('OtherOld');raise exception 'Retarget';exception when insufficient_privilege then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) values(gen_random_uuid(),'DECISION',pg_temp.sid('Old'),'DECISION_SUPERSEDED','Forged',auth.uid());raise exception 'Forged event';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role anon;
do $$begin begin perform public.supersede_decision(jsonb_build_object('oldDecisionId',gen_random_uuid(),'newDecisionId',gen_random_uuid()));raise exception 'Anonymous execution';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
assert not has_function_privilege('anon','public.supersede_decision(jsonb)','EXECUTE');
assert not has_function_privilege('service_role','public.supersede_decision(jsonb)','EXECUTE');
assert not has_function_privilege('authenticated','private.require_decision_finalization(uuid,uuid,uuid,boolean)','EXECUTE');
assert (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.supersede_decision(jsonb)'::regprocedure);
end $$;
select 'M1012_LINK='||to_jsonb(l)::text from public.decision_links l where decision_id=pg_temp.sid('Third');
select 'M10.12 AT-DEC-002 authority/scope/state/chronology/linear-chain/retry/immutability/rollback/client-denial/no-side-effects PASS';
rollback;
