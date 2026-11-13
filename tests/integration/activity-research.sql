set local role authenticated;
do $$declare r jsonb;r2 jsonb;n integer;begin
 r:=public.add_activity_research_reference(pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('Patent'));
 r2:=public.add_activity_research_reference(pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('Patent'));
 assert r=r2 and r->>'created_by'='00000000-0000-4000-8000-000000006004';
 assert (select count(*) from public.activity_research_links where activity_instance_id=pg_temp.research_context('Session9'))=2;
 assert (select count(*) from public.activity_outputs where activity_instance_id=pg_temp.research_context('Session9'))=3;
 assert public.add_activity_evidence_output(pg_temp.research_context('Session9'),pg_temp.research_source('Evidence'))=public.add_activity_evidence_output(pg_temp.research_context('Session9'),pg_temp.research_source('Evidence'));
 assert exists(select 1 from jsonb_array_elements(public.resume_activity(pg_temp.research_context('Session9'))->'inputs') x where x->>'evidence_id'=pg_temp.research_source('Evidence')::text);
 assert exists(select 1 from public.activity_research_links where activity_instance_id=pg_temp.research_context('Session8') and entity_id=pg_temp.research_source('Patent'));
 assert exists(select 1 from public.evidence where id=pg_temp.research_source('Evidence') and verification_status='UNVERIFIED' and verified_by is null and verified_at is null);
 perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('PersonalPatent')));
 perform pg_temp.research_bad(format('select public.add_activity_evidence_output(%L,%L)',pg_temp.research_context('Session9'),pg_temp.research_source('PersonalEvidence')));
 perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'OTHER',pg_temp.research_source('Patent')),'22023');
 perform pg_temp.research_bad(format('select public.add_activity_evidence_input(%L,%L,false)',pg_temp.research_context('Session9'),pg_temp.research_source('Evidence')),'23505');
 perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('ForeignPatent')));
 perform pg_temp.research_bad(format('select public.add_activity_evidence_output(%L,%L)',pg_temp.research_context('Session9'),pg_temp.research_source('ForeignEvidence')));
 perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_SEARCH_LOG',pg_temp.research_source('ForeignSearch')));
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('Patent')));
  perform pg_temp.research_bad(format('select public.add_activity_evidence_output(%L,%L)',pg_temp.research_context('Session9'),pg_temp.research_source('Evidence')));
  assert not exists(select 1 from public.activity_research_links);
  assert not exists(select 1 from public.activity_outputs where activity_instance_id=pg_temp.research_context('Session9'));
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 perform pg_temp.research_bad('insert into public.activity_research_links(activity_instance_id,entity_type,entity_id,created_by) values('||quote_literal(pg_temp.research_context('Session9'))||',''PATENT_RECORD'','||quote_literal(pg_temp.research_source('Patent'))||','||quote_literal(auth.uid())||')');
 perform pg_temp.research_bad('update public.activity_research_links set created_by=auth.uid()');
 perform pg_temp.research_bad('delete from public.activity_research_links');
end$$;
reset role;
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=pg_temp.research_context('Session9');
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
 select activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,clock_timestamp(),'active',configuration_snapshot from public.activity_instances where id=pg_temp.research_context('Session9');
insert into research_context select 'Session10',id from public.activity_instances where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') and status='active';
-- Forced new-reference failure must leave neither partial link nor source mutation.
create function pg_temp.fail_research_reference() returns trigger language plpgsql as $$begin raise exception 'Forced reference failure' using errcode='23514';end$$;
create trigger test_research_failure before insert on public.activity_research_links for each row execute function pg_temp.fail_research_reference();
set local role authenticated;
select pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session10'),'PATENT_RECORD',pg_temp.research_source('Patent')),'23514');
do $$begin assert not exists(select 1 from public.activity_research_links where activity_instance_id=pg_temp.research_context('Session10'));end$$;
reset role;
drop trigger test_research_failure on public.activity_research_links;
set local role authenticated;
select public.add_activity_evidence_input(pg_temp.research_context('Session10'),pg_temp.research_source('Evidence'),true);
select public.add_activity_artifact_input(pg_temp.research_context('Session10'),pg_temp.research_source('Landscape'),null,true);
select public.add_activity_input(pg_temp.research_context('Session10'),pg_temp.research_source('Gap'),true);
select public.add_activity_research_reference(pg_temp.research_context('Session10'),'PATENT_SEARCH_LOG',pg_temp.research_source('Search'));
do $$begin
 assert exists(select 1 from public.activity_research_links where activity_instance_id=pg_temp.research_context('Session9') and entity_id=pg_temp.research_source('Search'));
 assert exists(select 1 from public.activity_inputs where activity_instance_id=pg_temp.research_context('Session10') and evidence_id=pg_temp.research_source('Evidence'));
 perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('Patent')),'55000');
 perform pg_temp.research_bad(format('select public.add_activity_evidence_output(%L,%L)',pg_temp.research_context('Session9'),pg_temp.research_source('Evidence')),'55000');
end$$;
reset role;
update public.activity_instances set status='archived' where id=pg_temp.research_context('Session9');
set local role authenticated;
do $$begin
 perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('Patent')),'55000');
 assert (select count(*) from public.activity_research_links where activity_instance_id=pg_temp.research_context('Session9'))=2;
end$$;
reset role;
-- Authenticated access and provider identity never confer mutation/deletion authority.
set local role anon;
select pg_temp.research_bad('select * from public.activity_research_links');
reset role;
select pg_temp.research_bad('delete from public.activity_research_links','55000');
-- History is unchanged, including source verification, authorship, search timestamps and all Version bodies.
do $$begin
 assert (select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p)=(select patents from research_before);
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e)=(select evidence from research_before);
 assert (select jsonb_agg(to_jsonb(s) order by id) from public.patent_search_logs s)=(select searches from research_before);
 assert (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o)=(select objects from research_before);
 assert (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a)=(select artifacts from research_before);
 assert (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v)=(select versions from research_before);
 assert not has_table_privilege('authenticated','public.activity_research_links','INSERT');
 assert not has_function_privilege('anon','public.add_activity_research_reference(uuid,text,uuid)','EXECUTE');
 assert (select proconfig=array['search_path=""'] from pg_proc where oid='public.add_activity_research_reference(uuid,text,uuid)'::regprocedure);
end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.activity_research_links where activity_instance_id=pg_temp.research_context('Session9'));
 assert not exists(select 1 from public.activity_outputs where activity_instance_id=pg_temp.research_context('Session9'));
 assert exists(select 1 from public.activity_research_links where entity_id=pg_temp.research_source('PersonalPatent'));
 perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session10'),'PATENT_RECORD',pg_temp.research_source('Patent')));
end$$;
select 'M12.19 canonical Patent/Search/Evidence/Artifact/Gap handoff/lifecycle/history/idempotency/RLS/removed/role-only PASS';
rollback;


