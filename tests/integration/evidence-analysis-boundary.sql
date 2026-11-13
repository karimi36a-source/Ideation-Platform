-- AT-EV-002: appended to the canonical M8 fixture, no AI entity or provider.
reset role;
create temporary table analysis_fixture as select
 '{"outputType":"ANALYSIS","text":"The existing patents appear to leave a possible gap around X.","source":null,"verification":"unverified"}'::jsonb payload;
grant select on analysis_fixture to authenticated;
create temporary table boundary_evidence(id uuid);
grant select,insert on boundary_evidence to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into boundary_evidence select (public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'MEASUREMENT','Explicit source','Recorded measurement','Lab notebook')->>'id')::uuid from logged_projects where label='Team';
select public.link_evidence(jsonb_build_object('evidenceId',(select id from boundary_evidence),'entityType','ARTIFACT','entityId',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),'relationshipType','SUPPORTS'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.verify_evidence((select id from boundary_evidence),'VERIFIED','Explicit human verification');
reset role;
create function pg_temp.evidence_boundary_state() returns jsonb language sql as $$
 select jsonb_build_object(
  'evidence',coalesce((select jsonb_agg(to_jsonb(e) order by id) from public.evidence e),'[]'),
  'links',coalesce((select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l),'[]'),
  'history',coalesce((select jsonb_agg(to_jsonb(h) order by id) from public.evidence_verification_history h),'[]'),
  'decisionLinks',coalesce((select jsonb_agg(to_jsonb(d) order by id) from public.decision_links d),'[]'))
$$;
create temporary table boundary_before as select pg_temp.evidence_boundary_state() payload;
-- Tripwires prove neither Evidence RPC is invoked, even for a no-op attempt.
-- DDL is transactional and rolled back; no production function is changed.
alter function public.create_evidence(uuid,uuid,public.evidence_type,text,text,text,text,uuid) rename to boundary_original_create;
create function public.create_evidence(uuid,uuid,public.evidence_type,text,text,text,text,uuid default null)
 returns jsonb language plpgsql as $$begin raise exception 'Unexpected automatic Evidence creation' using errcode='P1205';end$$;
alter function public.verify_evidence(uuid,public.evidence_verification_status,text) rename to boundary_original_verify;
create function public.verify_evidence(uuid,public.evidence_verification_status,text default null)
 returns jsonb language plpgsql as $$begin raise exception 'Unexpected automatic Evidence verification' using errcode='P1205';end$$;
alter function public.link_patent_to_evidence(jsonb) rename to boundary_original_patent;
create function public.link_patent_to_evidence(input jsonb) returns jsonb language plpgsql as $$begin raise exception 'Unexpected automatic Patent Evidence creation' using errcode='P1205';end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Save factual-sounding text in an existing approved generic Artifact domain.
select public.update_artifact_draft((select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),0,(select payload from analysis_fixture),'Analysis notes',true);
select public.update_artifact_draft((select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),0,(select payload from analysis_fixture));
do $$begin
 assert (select content_snapshot from public.artifact_versions where id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'))=(select payload from analysis_fixture);
 assert (select content_snapshot from public.artifact_versions where id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'))=(select payload from analysis_fixture);
end$$;
-- Real and missing exact IDs have identical safe SQLSTATE/message responses.
create function pg_temp.denied_analysis_save(target uuid) returns text language plpgsql as $$
begin perform public.update_artifact_draft(target,1,(select payload from analysis_fixture));raise exception 'Unauthorized analysis save';
exception when insufficient_privilege then return sqlstate||':'||sqlerrm;end$$;
do $$declare n int;known uuid;missing uuid:='00000000-0000-4000-8000-000000999999';begin
 select (payload->>'initialVersionId')::uuid into known from submitted_fixtures where label='Team';
 foreach n in array array[6007,6001,6002,6003,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  assert pg_temp.denied_analysis_save(known)=pg_temp.denied_analysis_save(missing),'No private existence details';
  assert not exists(select 1 from public.artifact_versions where id=known);
  assert not exists(select 1 from public.evidence where id=(select id from boundary_evidence));
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.denied_analysis_save((select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'));
reset role;
do $$begin
 assert pg_temp.evidence_boundary_state()=(select payload from boundary_before),'Full Evidence IDs/rows, links, verification and history unchanged';
 assert (select count(*) from public.evidence)=1;
 assert (select count(*) from public.evidence_links)=1;
 assert (select count(*) from public.evidence_verification_history)=1;
end$$;
drop function public.create_evidence(uuid,uuid,public.evidence_type,text,text,text,text,uuid);
alter function public.boundary_original_create(uuid,uuid,public.evidence_type,text,text,text,text,uuid) rename to create_evidence;
drop function public.verify_evidence(uuid,public.evidence_verification_status,text);
alter function public.boundary_original_verify(uuid,public.evidence_verification_status,text) rename to verify_evidence;
drop function public.link_patent_to_evidence(jsonb);
alter function public.boundary_original_patent(jsonb) rename to link_patent_to_evidence;
-- Inspect the live, fully migrated PostgreSQL function/trigger catalog.
do $$declare writers text[];calls text[];begin
 select array_agg(n.nspname||'.'||p.proname order by p.proname) into writers
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private')
 and p.prokind='f' and p.prosrc ~* 'insert\s+into\s+(public\.)?"?evidence"?\s*\(';
 assert writers=array['public.create_evidence','public.link_patent_to_evidence'],'Only the two approved narrow RPCs insert Evidence';
 select array_agg(n.nspname||'.'||p.proname) into calls
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prokind='f'
 and p.proname<>'create_evidence' and p.prosrc ~* '(public\.)?create_evidence\s*\(';
 assert calls is null,'No function automatically invokes create_evidence';
 assert not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prokind='f' and p.prosrc ~* '(public[.])?link_patent_to_evidence\s*[(]'),'No function automatically invokes Patent Evidence creation';
 assert not exists(select 1 from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and not t.tgisinternal and (p.prosrc ~* '(insert\s+into\s+(public\.)?evidence\s*\(|link_patent_to_evidence\s*\(|create_evidence\s*\(|verify_evidence\s*\()')),'No automatic creation/verification trigger';
 assert not has_table_privilege('authenticated','public.evidence','INSERT');
 assert not has_table_privilege('authenticated','public.evidence','UPDATE');
 assert not has_table_privilege('authenticated','public.evidence_links','INSERT');
 assert not exists(select 1 from public.ai_outputs),'Analysis does not automatically persist AI results';
end$$;
select 'AT-EV-002 Artifact analysis save/no automatic creation/verification/links + TeamB/removed/role-only + database catalog PASS';
rollback;
