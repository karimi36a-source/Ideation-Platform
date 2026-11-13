reset role;
create temporary table da_before as select
 (select jsonb_agg(to_jsonb(d) order by id) from public.decisions d) decisions,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i) activities,
 (select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b) baselines;
create function pg_temp.da_denied(id uuid,expected text) returns void language plpgsql as $$
begin
 begin perform public.create_team_decision_record_artifact(id);
 exception when others then if sqlstate=expected then return;end if;raise;end;
 raise exception 'Unexpected composition success';
end $$;
grant execute on function pg_temp.da_denied(uuid,text) to authenticated;
-- Snapshot contract: each fixture was canonically started from its Definition.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare c record;begin
 for c in select * from da_cases where n<=6 loop perform pg_temp.da_denied(c.decision,'55000');end loop;
end $$;
insert into da_results select 'Single configured',public.create_team_decision_record_artifact(decision) from da_cases where n=7;
reset role;
-- Definition edits are deliberately attempted on the draft copy, not approved
-- curriculum or started snapshots. The captured execution remains authoritative.
do $$declare c uuid;s jsonb;begin
 select curriculum_version_id into c from public.session_definitions where id='00000000-0000-4000-8000-000000950702';
 assert (select status='approved' from public.curriculum_versions where id=c);
 select configuration_snapshot into s from public.activity_instances where id=(select activity from da_cases where n=7);
 begin update public.activity_definitions set configuration='{}' where id='00000000-0000-4000-8000-000001013007';raise exception 'Approved Definition rewrite';exception when check_violation then null;end;
 begin update public.activity_instances set configuration_snapshot='{}' where id=(select activity from da_cases where n=7);raise exception 'Snapshot rewrite';exception when check_violation then null;end;
 assert s=(select configuration_snapshot from public.activity_instances where id=(select activity from da_cases where n=7));
end $$;
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select activity from da_cases where n=8);
update public.activity_instances set status='archived' where id=(select activity from da_cases where n=9);
set local role authenticated;
select pg_temp.da_denied(decision,'55000') from da_cases where n in(8,9);
set local role authenticated;
do $$declare who int;begin
 foreach who in array array[6001,6003,6004,6005,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who::text,12,'0'),true);
  perform pg_temp.da_denied(pg_temp.da_id('Team'),'42501');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
 perform pg_temp.da_denied(pg_temp.da_id('No selection'),'55000');
 perform pg_temp.da_denied(gen_random_uuid(),'42501');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into da_results values('First',public.create_team_decision_record_artifact(pg_temp.da_id('Team')));
insert into da_results values('Retry',public.create_team_decision_record_artifact(pg_temp.da_id('Team')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into da_results values('Master',public.create_team_decision_record_artifact(pg_temp.da_id('Master different')));
reset role;
do $$declare r jsonb;a public.artifacts;v public.artifact_versions;d public.decisions;begin
 select payload into r from da_results where label='First';
 assert r=(select payload from da_results where label='Retry'),'exact retry returns canonical rows';
 select * into a from public.artifacts where id=(r#>>'{artifact,id}')::uuid;
 select * into v from public.artifact_versions where id=(r#>>'{version,id}')::uuid;
 select * into d from public.decisions where id=pg_temp.da_id('Team');
 assert a.artifact_type='TEAM_DECISION_RECORD' and a.title='Team Decision Record — Human decision';
 assert a.status='ACTIVE' and a.current_version_id is null and a.archived_at is null;
 assert v.status='DRAFT' and v.version_number=1 and v.draft_revision=0 and v.approved_by is null and v.approved_at is null;
 assert a.created_by='00000000-0000-4000-8000-000000006009' and v.created_by=a.created_by;
 assert (a.project_id,a.workspace_id,a.activity_instance_id)=(d.project_id,d.workspace_id,d.activity_instance_id);
 assert a.review_required=(select (configuration_snapshot->>'requires_review')::boolean from public.activity_instances where id=d.activity_instance_id);
 assert a.approval_required=(select (configuration_snapshot->>'requires_approval')::boolean from public.activity_instances where id=d.activity_instance_id);
 assert v.content_snapshot#>>'{decision,id}'=d.id::text and v.content_snapshot#>>'{decision,outcome}'=d.outcome and v.content_snapshot#>>'{decision,reasoning}'=d.reasoning;
 assert (v.content_snapshot#>>'{decision,decidedAt}')::timestamptz=d.decided_at;
 assert jsonb_array_length(v.content_snapshot->'options')=2;
 assert jsonb_array_length(v.content_snapshot->'participants')=(select count(*) from public.decision_participants where decision_id=d.id);
 assert jsonb_array_length(v.content_snapshot#>'{references,votingSessionIds}')=1;
 assert not v.content_snapshot ? 'votes' and not v.content_snapshot::text like '%voter%';
 assert (select count(*) from public.artifact_object_links where artifact_id=a.id)=1;
 assert exists(select 1 from public.artifact_object_links l join public.decision_options o on o.development_object_id=l.development_object_id where l.artifact_id=a.id and l.artifact_version_id=v.id and l.role_in_artifact='SELECTED_DECISION_OBJECT' and l.sequence=1 and o.decision_id=d.id and o.selected);
 assert not exists(select 1 from public.artifact_object_links l join public.decision_options o on o.development_object_id=l.development_object_id where l.artifact_id=a.id and o.decision_id=d.id and not o.selected);
 assert (select count(*) from public.artifact_decision_sources where decision_id=d.id and activity_instance_id=d.activity_instance_id)=1;
 assert (select count(*) from public.artifact_versions where artifact_id=a.id)=1;
 assert (select count(*) from public.activity_outputs where artifact_id=a.id and activity_instance_id=d.activity_instance_id)=1;
 assert (select count(*) from public.audit_events where entity_id=a.id and event_type='TEAM_DECISION_RECORD_COMPOSED' and actor_user_id=a.created_by and metadata='{}')=1;
 assert (select decisions from da_before)=(select jsonb_agg(to_jsonb(x) order by id) from public.decisions x);
 assert (select objects from da_before)=(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x);
 assert not exists(select 1 from public.activity_instances i join da_cases c on c.activity=i.id where c.n not in(8,9) and to_jsonb(i) is distinct from (select x from da_before,jsonb_array_elements(activities) x where x->>'id'=i.id::text));
 assert (select baselines from da_before) is not distinct from (select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x);
 assert not has_function_privilege('anon','public.create_team_decision_record_artifact(uuid)','execute');
 assert not has_function_privilege('service_role','public.create_team_decision_record_artifact(uuid)','execute');
 assert not has_function_privilege('authenticated','private.create_artifact_initial_draft(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean)','execute');
 assert (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.create_team_decision_record_artifact(uuid)'::regprocedure);
end $$;
-- Force two independently required stages to fail; SQL subtransactions prove
-- Artifact, Version, source, links, output and audit all roll back together.
create function pg_temp.da_fail() returns trigger language plpgsql as $$begin raise exception 'Injected composition failure' using errcode='P0001';end $$;
create trigger da_fail before insert on public.artifact_object_links for each row execute function pg_temp.da_fail();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select pg_temp.da_denied(pg_temp.da_id('Link failure'),'P0001');
reset role;
drop trigger da_fail on public.artifact_object_links;
create trigger da_fail before insert on public.activity_outputs for each row execute function pg_temp.da_fail();
set local role authenticated;
select pg_temp.da_denied(pg_temp.da_id('Log failure'),'P0001');
reset role;
drop trigger da_fail on public.activity_outputs;
do $$begin
 assert (select count(*) from public.artifact_decision_sources)=3;
 assert (select count(*) from public.artifacts where artifact_type='TEAM_DECISION_RECORD')=3;
 assert (select count(distinct o.object_type) from public.artifact_object_links l join public.development_objects o on o.id=l.development_object_id where l.role_in_artifact='SELECTED_DECISION_OBJECT')=3,'canonical PROBLEM/SOLUTION/FEATURE identities reused';
end $$;
-- Ordinary direct clients cannot manufacture configured output or write source.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare p jsonb;begin
 select payload into p from logged_projects where label='Team';
 begin perform public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'TEAM_DECISION_RECORD','Spoof',null,false,false);raise exception 'Generic bypass';exception when object_not_in_prerequisite_state then null;end;
 begin insert into public.artifact_decision_sources select (payload#>>'{artifact,id}')::uuid,(payload#>>'{version,id}')::uuid,pg_temp.da_id('Team'),(payload#>>'{artifact,activity_instance_id}')::uuid from da_results where label='First';raise exception 'Source spoof';exception when insufficient_privilege then null;end;
 begin delete from public.artifact_decision_sources;raise exception 'Source deletion';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$begin
 assert not exists(select 1 from public.artifacts where artifact_type='TEAM_DECISION_RECORD');
 assert not exists(select 1 from public.artifact_decision_sources);
 assert not exists(select 1 from public.artifact_object_links where artifact_id=(select (payload#>>'{artifact,id}')::uuid from da_results where label='First'));
 perform pg_temp.da_denied(pg_temp.da_id('Team'),'42501');
end $$;
reset role;
-- Current authority, including retry, must survive neither demotion nor removal.
update public.teams set team_lead_user_id=null where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
update public.team_memberships set membership_role='member' where user_id='00000000-0000-4000-8000-000000006009' and status='active';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select pg_temp.da_denied(pg_temp.da_id('Team'),'42501');
reset role;
update public.team_memberships set membership_role='team_lead' where user_id='00000000-0000-4000-8000-000000006009' and status='active';
update public.teams set team_lead_user_id='00000000-0000-4000-8000-000000006009' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
-- Canonical M8 workflow: Draft availability is separate from formal approval.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare r jsonb;i jsonb;begin
 select payload into r from da_results where label='First';
 i:=public.list_activity_artifact_candidates('00000000-0000-4000-8000-000001013010',(r#>>'{artifact,project_id}')::uuid,(r#>>'{artifact,workspace_id}')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'));
 assert i='[]'::jsonb,'Draft never satisfies approved_output';
 i:=public.list_activity_artifact_candidates('00000000-0000-4000-8000-000001013011',(r#>>'{artifact,project_id}')::uuid,(r#>>'{artifact,workspace_id}')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'));
 assert jsonb_array_length(i)=2,'artifact_available sees each canonical configured output without granting approval';
end $$;
insert into da_results select 'Submission',public.submit_artifact((payload#>>'{artifact,id}')::uuid,(payload#>>'{version,id}')::uuid,(payload#>>'{artifact,activity_instance_id}')::uuid) from da_results where label='First';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((payload->>'id')::uuid) from da_results where label='Submission';
select public.approve_artifact((payload->>'id')::uuid,'Human approval') from da_results where label='Submission';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare r jsonb;i jsonb;begin
 select payload into r from da_results where label='First';
 i:=public.list_activity_artifact_candidates('00000000-0000-4000-8000-000001013010',(r#>>'{artifact,project_id}')::uuid,(r#>>'{artifact,workspace_id}')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'));
 assert jsonb_array_length(i)=1 and i#>>'{0,artifactVersionId}'=r#>>'{version,id}','formal Current Version qualifies';
end $$;
reset role;
set local role authenticated;
insert into da_results select 'Downstream',public.start_activity('00000000-0000-4000-8000-000001013010',(payload#>>'{artifact,project_id}')::uuid,(payload#>>'{artifact,workspace_id}')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')) from da_results where label='First';
select public.add_activity_artifact_input((b.payload#>>'{activity,id}')::uuid,(a.payload#>>'{artifact,id}')::uuid,(a.payload#>>'{version,id}')::uuid,true) from da_results a cross join da_results b where a.label='First' and b.label='Downstream';
reset role;
-- Source supersession preserves the independent immutable Artifact history.
create temporary table da_preserved as select to_jsonb(a) artifact,to_jsonb(v) version from public.artifacts a join public.artifact_versions v on v.artifact_id=a.id where a.id=(select (payload#>>'{artifact,id}')::uuid from da_results where label='First');
update public.decisions set status='SUPERSEDED' where id=pg_temp.da_id('Team');
update public.decisions set status='ARCHIVED' where id=pg_temp.da_id('Participant failure');
set local role authenticated;
select pg_temp.da_denied(pg_temp.da_id('Team'),'55000');
select pg_temp.da_denied(pg_temp.da_id('Participant failure'),'55000');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.da_denied(pg_temp.da_id('Personal'),'42501');
reset role;
do $$begin
 assert (select artifact from da_preserved)=(select to_jsonb(a) from public.artifacts a where a.id=(select (payload#>>'{artifact,id}')::uuid from da_results where label='First'));
 assert (select version from da_preserved)=(select to_jsonb(v) from public.artifact_versions v where v.id=(select (payload#>>'{version,id}')::uuid from da_results where label='First'));
 assert exists(select 1 from public.artifact_decision_sources where decision_id=pg_temp.da_id('Team'));
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select pg_temp.da_denied(pg_temp.da_id('Master different'),'42501');
do $$begin assert not exists(select 1 from public.artifact_decision_sources);end $$;
reset role;
select 'M10.13 composition/configured-snapshot/source/selected-links/retry/rollback/privacy PASS';
select 'M1013_RESULT='||payload::text from da_results where label='First';
select 'M1013_SOURCE='||to_jsonb(s)::text from public.artifact_decision_sources s where decision_id=pg_temp.da_id('Team');
rollback;
