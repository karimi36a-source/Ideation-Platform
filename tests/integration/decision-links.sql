reset role;
create temporary table dl_results(payload jsonb);
grant select,insert on dl_results to authenticated;
create temporary table dl_before as select
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v) versions,
 (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b) baselines,
 (select jsonb_agg(to_jsonb(v) order by id) from public.votes v) votes;
set local role authenticated;
do $$declare who integer;did uuid;target uuid;k text;rel text;first jsonb;again jsonb;begin
 select (payload#>>'{decision,id}')::uuid into did from df_drafts where label='Team';
 select id into target from df_artifacts where label='Team';
 foreach who in array array[6001,6003,6004,6005,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who::text,12,'0'),true);
  begin perform public.link_decision_entity(jsonb_build_object('decisionId',did,'linkedEntityType','ARTIFACT','linkedEntityId',target,'relationshipType','CONSIDERED_IN_DECISION'));raise exception 'Unauthorized link';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
 foreach k in array array['ARTIFACT','DEVELOPMENT_OBJECT','VOTING_SESSION'] loop
  target:=case k when 'ARTIFACT' then (select id from df_artifacts where label='Team') when 'DEVELOPMENT_OBJECT' then (select id from vc_objects where kind='SOLUTION') else (select (payload#>>'{session,id}')::uuid from vc_results where jsonb_array_length(payload->'options')=3 limit 1) end;
  rel:=case k when 'VOTING_SESSION' then 'INFORMED_BY' else 'CONSIDERED_IN_DECISION' end;
  first:=public.link_decision_entity(jsonb_build_object('decisionId',did,'linkedEntityType',k,'linkedEntityId',target,'relationshipType',rel));
  again:=public.link_decision_entity(jsonb_build_object('decisionId',did,'linkedEntityType',k,'linkedEntityId',target,'relationshipType',rel));
  assert first=again,'Canonical retry';insert into dl_results values(first);
  begin perform public.link_decision_entity(jsonb_build_object('decisionId',did,'linkedEntityType',k,'linkedEntityId',target,'relationshipType',case rel when 'INFORMED_BY' then 'CONSIDERED_IN_DECISION' else 'INFORMED_BY' end));raise exception 'Wrong mapping';exception when invalid_parameter_value then null;end;
 end loop;
 foreach k in array array['EVIDENCE','AI_OUTPUT'] loop
  begin perform public.link_decision_entity(jsonb_build_object('decisionId',did,'linkedEntityType',k,'linkedEntityId',target,'relationshipType','CONSIDERED_IN_DECISION'));raise exception 'Premature target';exception when feature_not_supported then null;end;
 end loop;
 begin perform public.link_decision_entity(jsonb_build_object('decisionId',did,'linkedEntityType','ARTIFACT','linkedEntityId',(select id from df_artifacts where label='Team B'),'relationshipType','CONSIDERED_IN_DECISION'));raise exception 'Foreign target';exception when insufficient_privilege then null;end;
 begin perform public.link_decision_entity(jsonb_build_object('decisionId',did,'linkedEntityType','DEVELOPMENT_OBJECT','linkedEntityId',(select id from vc_objects where kind='ARCHIVED'),'relationshipType','CONSIDERED_IN_DECISION'));raise exception 'Archived Object';exception when insufficient_privilege then null;end;
 -- Personal owner can link own Artifact; Team authority does not expose it.
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 perform public.link_decision_entity(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Personal'),'linkedEntityType','ARTIFACT','linkedEntityId',(select id from df_artifacts where label='Personal'),'relationshipType','CONSIDERED_IN_DECISION'));
end $$;
reset role;
-- Lifecycle and finalized-body checks use trusted setup only.
update public.decisions set status='ARCHIVED' where id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='Archived Decision');
update public.decisions set status='SUPERSEDED' where id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='Superseded');
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from vc_activities where n=3);
update public.activity_instances set status='archived' where id=(select id from vc_activities where n=4);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare label0 text;begin
 foreach label0 in array array['Completed','Archived Activity','Superseded','Archived Decision'] loop
  begin perform public.link_decision_entity(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label=label0),'linkedEntityType','ARTIFACT','linkedEntityId',(select id from df_artifacts where label='Team'),'relationshipType','CONSIDERED_IN_DECISION'));raise exception 'Invalid lifecycle';exception when object_not_in_prerequisite_state then null;end;
 end loop;
 perform public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='No selection'),'outcome','Human','reasoning','Human reasoning'));
end $$;
reset role;
create temporary table dl_final_before as select to_jsonb(d) body from public.decisions d where id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='No selection');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select public.link_decision_entity(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='No selection'),'linkedEntityType','ARTIFACT','linkedEntityId',(select id from df_artifacts where label='Team'),'relationshipType','CONSIDERED_IN_DECISION'));
reset role;
do $$begin
 assert (select to_jsonb(d) from public.decisions d where id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='No selection'))=(select body from dl_final_before),'Finalized body preserved';
 assert (select count(*) from public.change_log where change_type='DECISION_LINK_ADDED')=5,'One event per new link';
 assert (select artifacts from dl_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select objects from dl_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
 assert (select versions from dl_before)=(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v);
 assert (select baselines from dl_before) is not distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b);
 assert (select votes from dl_before)=(select jsonb_agg(to_jsonb(v) order by id) from public.votes v);
 assert not has_table_privilege('authenticated','public.decision_links','INSERT');
 assert not has_table_privilege('authenticated','public.decision_links','UPDATE');
 assert not has_table_privilege('authenticated','public.decision_links','DELETE');
 assert not has_function_privilege('anon','public.link_decision_entity(jsonb)','EXECUTE');
 assert not has_function_privilege('service_role','public.link_decision_entity(jsonb)','EXECUTE');
end $$;
create function pg_temp.dl_fail() returns trigger language plpgsql as $$begin if new.change_type='DECISION_LINK_ADDED' then raise exception 'Injected log failure' using errcode='23514';end if;return new;end $$;
create trigger dl_fail before insert on public.change_log for each row execute function pg_temp.dl_fail();
set local role authenticated;
do $$begin
 begin perform public.link_decision_entity(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Log failure'),'linkedEntityType','ARTIFACT','linkedEntityId',(select id from df_artifacts where label='Team'),'relationshipType','CONSIDERED_IN_DECISION'));raise exception 'Missing rollback';exception when check_violation then null;end;
end $$;
reset role;
do $$begin assert not exists(select 1 from public.decision_links where decision_id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='Log failure')),'Log failure rolls back link';end $$;
select 'M1011_LINK='||payload::text from dl_results limit 1;
select 'M10.11 Decision links authority/scope/target/retry/lifecycle/immutability/log/rollback/client-denial PASS';
rollback;
