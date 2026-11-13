-- Real M7/M8/M12 operations; context labels never create competing domain models.
insert into reading select 'landscape',public.create_artifact(project,workspace,'PATENT_LANDSCAPE','Session 9 human research',pg_temp.reading_id('session9'),false,false) from av_context where label='Team';
insert into reading select 'decision',public.create_decision(jsonb_build_object('projectId',project,'workspaceId',workspace,'title','Research decision','question','What needs further investigation?','method','DISCUSSION','options','[{"label":"Investigate"},{"label":"Defer"}]'::jsonb)) from av_context where label='Team';
do $$declare c record;t text;o jsonb;a jsonb;s jsonb;e jsonb;n integer;begin
 select * into c from av_context where label='Team';
 -- Additional canonical input Artifacts use existing generic M8 representation.
 foreach t in array array['MIND_MAP','MINIMUM_ESSENTIAL_STRUCTURE'] loop
  select data into a from reading where label=t;
  perform public.add_activity_artifact_input(pg_temp.reading_id('session9'),(a->>'artifactId')::uuid,null,true);
 end loop;
 perform public.add_activity_artifact_input(pg_temp.reading_id('session9'),(select (data->>'artifactId')::uuid from reading where label='concept'),null,true);
 foreach t in array array['PROBLEM','SOLUTION','GAP','REQUIREMENT'] loop
  o:=public.create_development_object(c.project,c.workspace,t::public.development_object_type,'Searchable element '||t,'Human research structure','User');
  insert into reading values(t,o);
  perform public.add_activity_input(pg_temp.reading_id('session9'),(o->>'id')::uuid,true);
 end loop;
 for n in 1..2 loop
  s:=public.create_patent_search_log(jsonb_build_object('projectId',c.project,'workspaceId',c.workspace,'activityInstanceId',pg_temp.reading_id('session9'),'databaseName','PATENTSCOPE','queryText',case n when 1 then 'support mechanism' else 'support mechanism articulated joint' end,'searchMethod','Keyword refinement','reason','Inspect searchable component','termsLearned',jsonb_build_array('articulated joint'),'classificationsLearned',jsonb_build_array('F16M'),'notes','Human search strategy '||n));
  insert into reading values('search'||n,s);
  perform public.add_activity_research_reference(pg_temp.reading_id('session9'),'PATENT_SEARCH_LOG',(s->>'id')::uuid);
 end loop;
 e:=public.link_patent_to_evidence(jsonb_build_object('patentRecordId',pg_temp.reading_id('patent'),'evidenceType','PATENT','title','Source-backed observation','description','Human recorded source reference'));
 insert into reading values('evidence',e);
 foreach t in array array['GAP','REQUIREMENT','ARTIFACT','DECISION'] loop
  perform public.link_evidence(jsonb_build_object('evidenceId',e->>'id','entityType',t,'entityId',case t when 'ARTIFACT' then (select data->>'artifactId' from reading where label='landscape') when 'DECISION' then (select data#>>'{decision,id}' from reading where label='decision') else (select data->>'id' from reading where label=t) end,'relationshipType','SUPPORTS'));
 end loop;
 perform public.add_activity_research_reference(pg_temp.reading_id('session9'),'PATENT_RECORD',pg_temp.reading_id('patent'));
 perform public.add_activity_evidence_output(pg_temp.reading_id('session9'),(e->>'id')::uuid);
 perform public.add_activity_output(pg_temp.reading_id('session9'),pg_temp.reading_id('GAP'));
end$$;
insert into reading select 'savedLandscape',public.update_artifact_draft((data->>'initialVersionId')::uuid,0,jsonb_build_object('human_research_notes','Retain for further source-backed investigation; not a legal conclusion','patent_record_ids',jsonb_build_array(pg_temp.reading_id('patent')),'search_log_ids',jsonb_build_array(pg_temp.reading_id('search1'),pg_temp.reading_id('search2')),'evidence_ids',jsonb_build_array(pg_temp.reading_id('evidence')),'gap_object_ids',jsonb_build_array(pg_temp.reading_id('GAP'))),null,false) from reading where label='landscape';
select public.add_activity_artifact_output(pg_temp.reading_id('session9'),(data->>'artifactId')::uuid) from reading where label='landscape';
insert into reading select 'patentBefore',to_jsonb(p) from public.patent_records p where id=pg_temp.reading_id('patent');
insert into reading select 'logBefore',to_jsonb(p) from public.patent_search_logs p where id=pg_temp.reading_id('search1');
select public.complete_activity(pg_temp.reading_id('session9'));
insert into reading select 'session10',public.start_activity('00000000-0000-4000-8000-000001227810',project,workspace,team)->'activity' from av_context where label='Team';
select public.add_activity_artifact_input(pg_temp.reading_id('session10'),(data->>'artifactId')::uuid,null,true) from reading where label='landscape';
select public.add_activity_evidence_input(pg_temp.reading_id('session10'),pg_temp.reading_id('evidence'),true);
select public.add_activity_input(pg_temp.reading_id('session10'),pg_temp.reading_id('GAP'),true);
select public.add_activity_research_reference(pg_temp.reading_id('session10'),'PATENT_RECORD',pg_temp.reading_id('patent'));
select public.add_activity_research_reference(pg_temp.reading_id('session10'),'PATENT_SEARCH_LOG',pg_temp.reading_id('search1'));
select public.add_activity_research_reference(pg_temp.reading_id('session10'),'PATENT_SEARCH_LOG',pg_temp.reading_id('search2'));
do $$begin
 assert (select count(*) from public.activity_inputs where activity_instance_id=pg_temp.reading_id('session9'))=8,'five input families plus gap/requirement';
 assert pg_temp.reading_id('search1')<>pg_temp.reading_id('search2');
 assert (select to_jsonb(p) from public.patent_search_logs p where id=pg_temp.reading_id('search1'))=(select data from reading where label='logBefore');
 assert (select terms_learned=array['articulated joint'] and classifications_learned=array['F16M'] from public.patent_search_logs where id=pg_temp.reading_id('search2'));
 assert (select to_jsonb(p) from public.patent_records p where id=pg_temp.reading_id('patent'))=(select data from reading where label='patentBefore');
 assert (select why_retained='Human source selection' and relevance_status='NOT_REVIEWED' from public.patent_records where id=pg_temp.reading_id('patent'));
 assert (select verification_status='UNVERIFIED' and verified_by is null and verified_at is null from public.evidence where id=pg_temp.reading_id('evidence'));
 assert (select count(*) from public.evidence_links where evidence_id=pg_temp.reading_id('evidence'))=5;
 assert (select count(*) from public.artifacts where artifact_type='PATENT_LANDSCAPE')=1;
 assert exists(select 1 from public.artifact_versions v join reading r on r.label='landscape' and v.id=(r.data->>'initialVersionId')::uuid
  where v.status='DRAFT' and v.content_snapshot->>'human_research_notes'='Retain for further source-backed investigation; not a legal conclusion'
  and v.content_snapshot->'search_log_ids'=jsonb_build_array(pg_temp.reading_id('search1'),pg_temp.reading_id('search2'))
  and v.content_snapshot->'patent_record_ids'=jsonb_build_array(pg_temp.reading_id('patent'))
  and v.content_snapshot->'evidence_ids'=jsonb_build_array(pg_temp.reading_id('evidence'))
  and v.content_snapshot->'gap_object_ids'=jsonb_build_array(pg_temp.reading_id('GAP'))),'canonical Landscape content persists';
 assert exists(select 1 from public.activity_outputs where activity_instance_id=pg_temp.reading_id('session9') and artifact_id=(select (data->>'artifactId')::uuid from reading where label='landscape'));
 assert exists(select 1 from public.activity_inputs where activity_instance_id=pg_temp.reading_id('session10') and evidence_id=pg_temp.reading_id('evidence'));
 assert exists(select 1 from public.activity_inputs where activity_instance_id=pg_temp.reading_id('session10') and development_object_id=pg_temp.reading_id('GAP'));
 assert (select count(*) from public.patent_records)=1;
 assert (select count(*) from public.patent_search_logs)=2;
 assert exists(select 1 from jsonb_array_elements(public.resume_activity(pg_temp.reading_id('session10'))->'inputs') x where x->>'artifact_id'=(select data->>'artifactId' from reading where label='landscape'));
 assert (select count(*) from public.activity_research_links where activity_instance_id=pg_temp.reading_id('session10'))=3;
 assert to_regclass('public.patent_comparisons') is null;
end$$;
-- Current authority, never historical participation or public source identity.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006004',null);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006008',null);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006002',null);
do $$declare u integer;begin
 foreach u in array array[6001,6002,6003,6004,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
  assert not exists(select 1 from public.patent_records where id=pg_temp.reading_id('patent'));
  assert not exists(select 1 from public.patent_search_logs where id=pg_temp.reading_id('search1'));
  assert not exists(select 1 from public.evidence where id=pg_temp.reading_id('evidence'));
  assert not exists(select 1 from public.evidence_links where evidence_id=pg_temp.reading_id('evidence'));
  assert not exists(select 1 from public.artifacts where id=(select (data->>'artifactId')::uuid from reading where label='landscape'));
  assert public.resume_activity(pg_temp.reading_id('session10')) is null,'inaccessible Activity returns no metadata';
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 assert exists(select 1 from public.evidence where id=pg_temp.reading_id('evidence'));
end$$;
select 'M12.27 Session9 canonical inputs/refined immutable research/source-backed Evidence/Landscape/Session10 same-ID handoff/privacy PASS';
rollback;
