-- Runner prepends an isolated approved curriculum and real M7 start fixtures.
reset role;
create temporary table reading(label text primary key,data jsonb);grant all on reading to authenticated;
create function pg_temp.reading_id(label0 text) returns uuid language sql as $$select (data->>'id')::uuid from reading where label=$1$$;
create function pg_temp.reading_bad(statement text,expected text default '42501') returns void language plpgsql as $$begin execute statement;raise exception 'Reading attack succeeded';exception when others then if sqlstate<>expected then raise;end if;end$$;
create temporary table reading_before as select (select count(*) from public.evidence) evidence_count;
grant select on reading_before to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into reading select 'concept',public.create_artifact(c.project,c.workspace,'INVENTION_CONCEPT','Invention Concept V1',f.id,false,false) from av_context c join resumed_fixture f on c.label=f.label where c.label='Team';
select public.add_activity_artifact_output(f.id,(r.data->>'artifactId')::uuid) from resumed_fixture f cross join reading r where f.label='Team' and r.label='concept';
insert into reading select 'session8',public.start_activity('00000000-0000-4000-8000-000001226808',project,workspace,team)->'activity' from av_context where label='Team';
select public.add_activity_artifact_input(pg_temp.reading_id('session8'),(data->>'artifactId')::uuid,null,true) from reading where label='concept';
insert into reading select 'patent',public.create_patent_record(jsonb_build_object('projectId',project,'workspaceId',workspace,'publicationNumber',' WO 123 A1 ','title','Source title','sourceDatabase','PATENTSCOPE','sourceUrl','https://patentscope.wipo.int/','abstractText','Source abstract','whyRetained','Human source selection')) from av_context where label='Team';
insert into reading values('notes','{"title":"My title reading","abstract":"My abstract reading","description":"My structure notes","claims":"Claim 1 reference","drawings":"Figure 2 reference","bibliographic_information":"My family/date notes"}');
insert into reading select 'framework',public.save_patent_reading_framework(pg_temp.reading_id('session8'),pg_temp.reading_id('patent'),data,null) from reading where label='notes';
insert into reading select 'retry',public.save_patent_reading_framework(pg_temp.reading_id('session8'),pg_temp.reading_id('patent'),data,null) from reading where label='notes';
do $$declare saved jsonb;begin
 assert (select data from reading where label='framework')=(select data from reading where label='retry'),'retry canonical identity';
 select data into saved from reading where label='framework';
 assert saved#>>'{artifact,artifact_type}'='PATENT_READING_FRAMEWORK';
 assert saved#>'{version,content_snapshot,learner_notes}'=(select data from reading where label='notes'),'six sections exact';
 assert saved#>>'{version,content_snapshot,source_patent_record_ids,0}'=pg_temp.reading_id('patent')::text;
 assert (select count(*) from public.artifacts where artifact_type='PATENT_READING_FRAMEWORK')=1;
 assert exists(select 1 from public.activity_outputs where activity_instance_id=pg_temp.reading_id('session8') and artifact_id=(saved#>>'{artifact,id}')::uuid);
 assert exists(select 1 from public.activity_research_links where activity_instance_id=pg_temp.reading_id('session8') and entity_id=pg_temp.reading_id('patent'));
 assert exists(select 1 from public.activity_inputs where activity_instance_id=pg_temp.reading_id('session8') and artifact_id=(select (data->>'artifactId')::uuid from reading where label='concept'));
 perform pg_temp.reading_bad(format('select public.save_patent_reading_framework(%L,%L,%L,0,%L)',pg_temp.reading_id('session8'),pg_temp.reading_id('patent'),(select data from reading where label='notes'),saved#>>'{version,id}'),'23505');
 perform pg_temp.reading_bad(format('select public.save_patent_reading_framework(%L,%L,%L,null)',pg_temp.reading_id('session8'),pg_temp.reading_id('patent'),'{}'),'22023');
 assert exists(select 1 from public.patent_records where id=pg_temp.reading_id('patent') and title='Source title' and abstract_text='Source abstract' and publication_number=' WO 123 A1 ' and relevance_status='NOT_REVIEWED');
end$$;
-- Explicit M8 CAS save, then an independent V2 preserves V1 and the null pointer.
insert into reading select 'saved',public.save_patent_reading_framework(pg_temp.reading_id('session8'),pg_temp.reading_id('patent'),data,1,(select (data#>>'{version,id}')::uuid from reading where label='framework')) from reading where label='notes';
insert into reading select 'v1',to_jsonb(v) from public.artifact_versions v where id=(select (data#>>'{version,id}')::uuid from reading where label='framework');
insert into reading select 'v2',public.create_artifact_version((data#>>'{artifact,id}')::uuid,data#>'{version,content_snapshot}','Explicit reading checkpoint') from reading where label='saved';
do $$begin
 assert (select data from reading where label='v1')=(select to_jsonb(v) from public.artifact_versions v where id=(select (data->>'id')::uuid from reading where label='v1'));
 assert (select data->>'previous_version_id' from reading where label='v2')=(select data->>'id' from reading where label='v1');
 assert (select data->>'status' from reading where label='v2')='DRAFT';
 assert (select current_version_id is null from public.artifacts where id=(select (data#>>'{artifact,id}')::uuid from reading where label='framework'));
end$$;
select public.complete_activity(pg_temp.reading_id('session8'));
insert into reading select 'session9',public.start_activity('00000000-0000-4000-8000-000001226809',project,workspace,team)->'activity' from av_context where label='Team';
insert into reading select 'input',public.add_activity_artifact_input(pg_temp.reading_id('session9'),(data#>>'{artifact,id}')::uuid,null,true) from reading where label='framework';
do $$begin
 assert (select data->>'artifact_id' from reading where label='input')=(select data#>>'{artifact,id}' from reading where label='framework'),'same canonical handoff';
 assert exists(select 1 from jsonb_array_elements(public.resume_activity(pg_temp.reading_id('session9'))->'inputs') x where x->>'artifact_id'=(select data#>>'{artifact,id}' from reading where label='framework'));
 assert (select count(*) from public.artifacts where artifact_type='PATENT_READING_FRAMEWORK')=1;
 assert (select count(*) from public.patent_records)=1;
 assert (select count(*) from public.evidence)=(select evidence_count from reading_before),'no automatic Evidence';
end$$;
reset role;
-- Personal reading uses its own canonical scope. Force output failure after
-- Artifact/Draft creation to prove transaction-wide rollback, then retry.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into reading select 'personalActivity',public.start_activity('00000000-0000-4000-8000-000001226810',project,workspace,team)->'activity' from av_context where label='Personal';
insert into reading select 'personalPatent',public.create_patent_record(jsonb_build_object('projectId',project,'workspaceId',workspace,'publicationNumber','Private source','title','Private bibliography','sourceDatabase','USPTO','sourceUrl','https://www.uspto.gov/patents/search')) from av_context where label='Personal';
reset role;
create function pg_temp.fail_reading_output() returns trigger language plpgsql as $$begin if exists(select 1 from public.artifacts where id=new.artifact_id and artifact_type='PATENT_READING_FRAMEWORK') then raise exception 'Forced reading output failure' using errcode='23514';end if;return new;end$$;
create trigger test_reading_output_failure before insert on public.activity_outputs for each row execute function pg_temp.fail_reading_output();
set local role authenticated;
select pg_temp.reading_bad(format('select public.save_patent_reading_framework(%L,%L,%L,null)',pg_temp.reading_id('personalActivity'),pg_temp.reading_id('personalPatent'),(select data from reading where label='notes')),'23514');
do $$begin assert not exists(select 1 from public.artifacts where activity_instance_id=pg_temp.reading_id('personalActivity'));assert not exists(select 1 from public.activity_research_links where activity_instance_id=pg_temp.reading_id('personalActivity'));end$$;
reset role;drop trigger test_reading_output_failure on public.activity_outputs;
set local role authenticated;
insert into reading select 'personalFramework',public.save_patent_reading_framework(pg_temp.reading_id('personalActivity'),pg_temp.reading_id('personalPatent'),data,null) from reading where label='notes';
select pg_temp.reading_bad(format('select public.save_patent_reading_framework(%L,%L,%L,null)',pg_temp.reading_id('session9'),pg_temp.reading_id('personalPatent'),(select data from reading where label='notes')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not exists(select 1 from public.artifacts where id=(select (data#>>'{artifact,id}')::uuid from reading where label='personalFramework'));assert not exists(select 1 from public.patent_records where id=pg_temp.reading_id('personalPatent'));end$$;
reset role;
-- Role-only authority: this fixture's Master also has an independent Team
-- membership; remove it before testing role-only denial.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006004',null);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006008',null);
select public.remove_team_member((select team from av_context where label='Team'),'00000000-0000-4000-8000-000000006002',null);
do $$declare u integer;begin
 foreach u in array array[6001,6002,6003,6004,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(u::text,12,'0'),true);
  assert not exists(select 1 from public.artifacts where id=(select (data#>>'{artifact,id}')::uuid from reading where label='framework')),'Artifact isolation actor '||u;
  assert not exists(select 1 from public.artifact_versions where artifact_id=(select (data#>>'{artifact,id}')::uuid from reading where label='framework'));
  assert not exists(select 1 from public.patent_records where id=pg_temp.reading_id('patent'));
  assert not exists(select 1 from public.activity_research_links where activity_instance_id=pg_temp.reading_id('session8'));
  perform pg_temp.reading_bad(format('select public.save_patent_reading_framework(%L,%L,%L,null)',pg_temp.reading_id('session8'),pg_temp.reading_id('patent'),(select data from reading where label='notes')));
  perform pg_temp.reading_bad(format('select public.add_activity_artifact_input(%L,%L,null,true)',pg_temp.reading_id('session9'),(select data#>>'{artifact,id}' from reading where label='framework')));
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 assert exists(select 1 from public.patent_records where id=pg_temp.reading_id('patent'));
 assert exists(select 1 from public.artifact_versions where id=(select (data->>'id')::uuid from reading where label='v1'));
end$$;
reset role;
do $$begin
 assert not has_function_privilege('anon','public.save_patent_reading_framework(uuid,uuid,jsonb,integer,uuid)','EXECUTE');
 assert not has_function_privilege('authenticated','private.valid_patent_reading_snapshot(jsonb)','EXECUTE');
 assert (select proconfig=array['search_path=""'] from pg_proc where oid='public.save_patent_reading_framework(uuid,uuid,jsonb,integer,uuid)'::regprocedure);
end$$;
select 'M12.26 Session8 canonical PATENT_READING_FRAMEWORK six notes/source separation/M8 history/output/Session9 exact handoff/no duplicates/no Evidence/privacy PASS';
rollback;
