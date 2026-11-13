-- AT-PAT-002: real canonical Patent/Evidence/Artifact operations; no M14 domain.
reset role;
create temporary table patent_boundary_sources(label text,id uuid);
grant select on patent_boundary_sources to authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into patent_boundary_sources select label,(public.create_patent_record(jsonb_build_object(
 'projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id',
 'publicationNumber',' WO 2025/123 A1 ','applicationNumber',' PCT/2024/123 ',
 'title','Original source title','applicant','Source applicant','inventor','Source inventor',
 'priorityDate','2023-02-28','filingDate','2024-02-29','publicationDate','2025-01-16',
 'ipcCpc',' G01B 1/00 ','sourceDatabase','PATENTSCOPE','sourceUrl','https://source.example.test/patent',
 'abstractText','Exact source abstract: the disclosed apparatus comprises X.',
 'relevanceStatus','POSSIBLY_RELEVANT','whyRetained','Human screening note; source may inform the gap.'
 ))->>'id')::uuid from logged_projects where label in ('Team','Individual');
create temporary table patent_boundary_evidence(label text,id uuid);
grant select on patent_boundary_evidence to authenticated;
insert into patent_boundary_evidence select label,(public.link_patent_to_evidence(jsonb_build_object('patentRecordId',id,'evidenceType','PATENT','title','Source observation','description','Explicit human-recorded source facts'))->>'id')::uuid from patent_boundary_sources;
insert into patent_boundary_evidence select label||'Claim',(public.link_patent_to_evidence(jsonb_build_object('patentRecordId',id,'evidenceType','PATENT_CLAIM','claimLocator',' Claim 7, lines 2–4 ','title','Claim reference','description','Explicit source claim locator'))->>'id')::uuid from patent_boundary_sources;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.verify_evidence((select id from patent_boundary_evidence where label='TeamClaim'),'VERIFIED','Human source check only');
reset role;
-- Simulated future analysis exists only in this isolated temporary fixture.
create temporary table simulated_patent_analysis as select jsonb_build_object(
 'type','AI_ANALYSIS','label','AI Analysis','text','A possible technical difference requires human investigation.',
 'sourcePatentRecordId',(select id from patent_boundary_sources where label='Team'),
 'proposedSourceOverwrite',jsonb_build_object('abstract_text','AI-rewritten abstract','source_url','https://analysis.example.test','source_database','GOOGLE_PATENTS','relevance_status','RELEVANT','why_retained','AI recommendation'),
 'proposedVerification','VERIFIED','proposedClaimLocator','AI-interpreted claim') payload;
grant select on simulated_patent_analysis to authenticated;
create function pg_temp.patent_boundary_state() returns jsonb language sql as $$
 select jsonb_build_object(
 'patents',coalesce((select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p),'[]'),
 'evidence',coalesce((select jsonb_agg(to_jsonb(e) order by id) from public.evidence e),'[]'),
 'links',coalesce((select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l),'[]'),
 'verificationHistory',coalesce((select jsonb_agg(to_jsonb(h) order by id) from public.evidence_verification_history h),'[]'),
 'decisions',coalesce((select jsonb_agg(to_jsonb(d) order by id) from public.decisions d),'[]'),
 'decisionLinks',coalesce((select jsonb_agg(to_jsonb(d) order by id) from public.decision_links d),'[]'))
$$;
create temporary table patent_boundary_before as select pg_temp.patent_boundary_state() payload;
-- Tripwires catch automatic invocation, including attempts that would be no-ops.
alter function public.create_patent_record(jsonb) rename to boundary_original_patent_create;
create function public.create_patent_record(jsonb) returns jsonb language plpgsql as $$begin raise exception 'Automatic Patent creation is forbidden' using errcode='P1216';end$$;
alter function public.create_evidence(uuid,uuid,public.evidence_type,text,text,text,text,uuid) rename to boundary_original_evidence_create;
create function public.create_evidence(uuid,uuid,public.evidence_type,text,text,text,text,uuid default null) returns jsonb language plpgsql as $$begin raise exception 'Automatic Evidence creation is forbidden' using errcode='P1216';end$$;
alter function public.link_patent_to_evidence(jsonb) rename to boundary_original_patent_link;
create function public.link_patent_to_evidence(jsonb) returns jsonb language plpgsql as $$begin raise exception 'Automatic Patent Evidence conversion is forbidden' using errcode='P1216';end$$;
alter function public.verify_evidence(uuid,public.evidence_verification_status,text) rename to boundary_original_evidence_verify;
create function public.verify_evidence(uuid,public.evidence_verification_status,text default null) returns jsonb language plpgsql as $$begin raise exception 'Automatic Evidence verification is forbidden' using errcode='P1216';end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Human interpretation uses an already-approved Artifact Draft, not source columns.
select public.update_artifact_draft((select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),0,
 jsonb_build_object('type','HUMAN_ANALYSIS','label','Human analysis','sourcePatentRecordId',(select id from patent_boundary_sources where label='Team'),'notes','Private human interpretation; investigate the possible gap.'),'Human analysis notes',true);
select public.update_artifact_draft((select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'),0,
 jsonb_build_object('type','HUMAN_ANALYSIS','label','Human analysis','sourcePatentRecordId',(select id from patent_boundary_sources where label='Individual'),'notes','Private Personal reading notes.'));
do $$begin
 assert (select payload->>'type' from simulated_patent_analysis)='AI_ANALYSIS';
 assert (select payload->>'label' from simulated_patent_analysis)='AI Analysis';
 assert (select content_snapshot->>'type' from public.artifact_versions where id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'))='HUMAN_ANALYSIS';
 assert (select content_snapshot->>'label' from public.artifact_versions where id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'))='Human analysis';
 assert not exists(select 1 from public.artifact_versions where content_snapshot->>'type'='AI_ANALYSIS'),'No simulated AI persistence';
 begin
  update public.patent_records set publication_number='AI number',application_number='AI application',title='AI title',applicant='AI applicant',inventor='AI inventor',priority_date='2020-01-01',filing_date='2020-01-02',publication_date='2020-01-03',ipc_cpc='AI classification',source_database='GOOGLE_PATENTS',source_url='https://analysis.example.test',abstract_text='AI abstract',relevance_status='RELEVANT',why_retained='AI retained';
  raise exception 'Analysis source overwrite succeeded';exception when insufficient_privilege then null;end;
 begin update public.evidence set description='AI interpretation',source_name='AI Analysis',source_url='https://analysis.example.test',verification_status='VERIFIED',verified_by=public.current_platform_user_id(),verified_at=clock_timestamp(),claim_locator='AI claim';raise exception 'Evidence overwrite succeeded';exception when insufficient_privilege then null;end;
end$$;
-- Normal Artifact authorization protects both human notes and source associations.
create function pg_temp.denied_patent_analysis_save(target uuid) returns text language plpgsql as $$
begin perform public.update_artifact_draft(target,1,jsonb_build_object('type','HUMAN_ANALYSIS','notes','spoof'));raise exception 'Unauthorized analysis save succeeded';
exception when insufficient_privilege then return sqlstate||':'||sqlerrm;end$$;
do $$declare n int;known uuid;missing uuid:='00000000-0000-4000-8000-000000999999';begin
 select (payload->>'initialVersionId')::uuid into known from submitted_fixtures where label='Team';
 foreach n in array array[6006,6007,6001,6002,6003,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  assert pg_temp.denied_patent_analysis_save(known)=pg_temp.denied_patent_analysis_save(missing),'Known ID leaks no private existence';
  assert not exists(select 1 from public.patent_records where id=(select id from patent_boundary_sources where label='Team'));
  assert not exists(select 1 from public.evidence where id in (select id from patent_boundary_evidence where label in ('Team','TeamClaim')));
  assert not exists(select 1 from public.artifact_versions where id=known),'Human research notes remain private';
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 assert not exists(select 1 from public.patent_records where id=(select id from patent_boundary_sources where label='Individual'));
 assert not exists(select 1 from public.artifact_versions where id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Personal'));
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.denied_patent_analysis_save((select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'));
do $$begin
 assert not exists(select 1 from public.patent_records where id=(select id from patent_boundary_sources where label='Team'));
 assert not exists(select 1 from public.evidence where id in (select id from patent_boundary_evidence where label in ('Team','TeamClaim')));
 assert not exists(select 1 from public.artifact_versions where id=(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'));
 assert exists(select 1 from public.patent_records where id=(select id from patent_boundary_sources where label='Individual')),'Personal source privacy unaffected';
end$$;
reset role;
do $$begin
 assert pg_temp.patent_boundary_state()=(select payload from patent_boundary_before),'Exact Patent, Evidence, verification, claim, Decision and link rows unchanged';
 assert (select count(*) from public.patent_records)=2;
 assert (select count(*) from public.evidence)=4;
 assert not has_table_privilege('authenticated','public.patent_records','UPDATE');
 assert not has_table_privilege('authenticated','public.evidence','UPDATE');
 assert not exists(select 1 from public.ai_outputs),'Patent analysis does not automatically persist AI results';
 assert not exists(select 1 from information_schema.columns where table_schema='public' and table_name='patent_records' and column_name in ('novelty_score','patentability_status','infringement_risk','legal_status_conclusion','ai_analysis'));
end$$;
select 'AT-PAT-002 M12.16 exact source/abstract/URL/database/relevance/notes + human Artifact separation + AI_ANALYSIS fixture-only + no Evidence/verification/claim/Decision mutation + TeamB/removed/role-only/Personal/privacy PASS';
rollback;
