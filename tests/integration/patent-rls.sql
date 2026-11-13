reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table pr_inputs(label text primary key,record_input jsonb,search_input jsonb);
insert into pr_inputs select p.label,
 jsonb_build_object('projectId',p.payload->>'id','workspaceId',p.payload->>'primary_workspace_id','publicationNumber',' WO PUBLIC 123 A1 ','title','Private retained research','sourceDatabase','PATENTSCOPE','sourceUrl','https://example.test/public-patent','whyRetained','Private human retention rationale'),
 jsonb_build_object('projectId',p.payload->>'id','workspaceId',p.payload->>'primary_workspace_id','activityInstanceId',case p.label when 'Team' then pg_temp.research_context('Session9') when 'Individual' then (select id from instances where label='Individual') else pg_temp.research_context('ForeignActivity') end,'databaseName','PATENTSCOPE','queryText','M12.22 private strategy','searchMethod','Human query refinement','reason','Private research question','notes','Private search history','termsLearned',jsonb_build_array('human learned term'),'classificationsLearned',jsonb_build_array('A01B 1/00'))
 from logged_projects p where p.label in ('Team','Individual','OtherResearch');
grant select on pr_inputs to authenticated,anon;
create function pg_temp.pr_bad(statement text,expected text default '42501') returns void language plpgsql as $$begin execute statement;raise exception 'Patent RLS attack accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
set local role authenticated;
-- Exact repeats remain distinct, server-attributed immutable rows.
insert into research_sources select 'PersonalSearch',(public.create_patent_search_log(search_input)->>'id')::uuid from pr_inputs where label='Individual';
insert into research_sources select 'Repeat1',(public.create_patent_search_log(search_input)->>'id')::uuid from pr_inputs where label='Team';
insert into research_sources select 'Repeat2',(public.create_patent_search_log(search_input)->>'id')::uuid from pr_inputs where label='Team';
do $$declare value public.patent_relevance_status;evidence_count bigint;begin
 select count(*) into evidence_count from public.evidence;
 foreach value in array enum_range(null::public.patent_relevance_status) loop
  insert into research_sources select 'Status/'||value,(public.create_patent_record(record_input||jsonb_build_object('relevanceStatus',value))->>'id')::uuid from pr_inputs where label='Team';
 end loop;
 assert (select count(*) from public.evidence)=evidence_count,'Record creation does not fabricate Evidence';
 assert pg_temp.research_source('Repeat1')<>pg_temp.research_source('Repeat2');
 assert (select count(*) from public.patent_search_logs where project_id=(select (record_input->>'projectId')::uuid from pr_inputs where label='Team') and query_text='M12.22 private strategy')=2;
 assert exists(select 1 from public.patent_search_logs where id=pg_temp.research_source('Repeat1') and searched_by='00000000-0000-4000-8000-000000006004' and notes='Private search history' and terms_learned=array['human learned term'] and classifications_learned=array['A01B 1/00']);
 assert exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent') and relevance_status='POSSIBLY_RELEVANT');
 assert exists(select 1 from public.evidence where id=pg_temp.research_source('Evidence') and verification_status='UNVERIFIED' and verified_by is null and verified_at is null);
end$$;
reset role;
create temporary table pr_history as select
 (select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p) patents,
 (select jsonb_agg(to_jsonb(s) order by id) from public.patent_search_logs s) searches,
 (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,
 (select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l) evidence_links,
 (select jsonb_agg(to_jsonb(l) order by id) from public.activity_research_links l) research_links;
set local role authenticated;
do $$declare n integer;v jsonb;k text;begin
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent')),'Exact Record ID denied';
  assert not exists(select 1 from public.patent_search_logs where id=pg_temp.research_source('Search')),'Exact Search ID denied';
  assert not exists(select 1 from public.patent_records where publication_number=' WO PUBLIC 123 A1 ' or source_url='https://example.test/public-patent'),'Public source metadata is not an ACL';
  assert not exists(select 1 from public.patent_search_logs where query_text='M12.22 private strategy' or notes='Private search history' or 'human learned term'=any(terms_learned)),'Strategy and learned metadata remain private';
  assert not exists(select 1 from public.patent_records p join public.evidence_links l on l.linked_entity_type='PATENT_RECORD' and l.linked_entity_id=p.id join public.evidence e on e.id=l.evidence_id where p.id=pg_temp.research_source('Patent')),'Evidence join grants no source visibility';
  assert not exists(select 1 from public.activity_research_links where entity_id in (pg_temp.research_source('Patent'),pg_temp.research_source('Search'))),'Activity reference grants no source visibility';
  assert not exists(select 1 from public.patent_search_logs s join public.activity_research_links l on l.entity_type='PATENT_SEARCH_LOG' and l.entity_id=s.id where s.id=pg_temp.research_source('Search'));
  perform pg_temp.pr_bad(format('select public.create_patent_record(%L::jsonb)',(select record_input from pr_inputs where label='Team')));
  perform pg_temp.pr_bad(format('select public.create_patent_search_log(%L::jsonb)',(select search_input from pr_inputs where label='Team')));
  perform pg_temp.pr_bad(format('select public.link_patent_to_evidence(%L::jsonb)',jsonb_build_object('patentRecordId',pg_temp.research_source('Patent'),'evidenceType','PATENT','title','Spoof','description','Spoof')));
  perform pg_temp.pr_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('Patent')));
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 assert exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent')),'Current Team Lead positive control';
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('PersonalPatent'));
 assert not exists(select 1 from public.patent_search_logs where id=pg_temp.research_source('PersonalSearch'));
 assert public.get_team_workspace_access((select (record_input->>'workspaceId')::uuid from pr_inputs where label='OtherResearch')) is not null;
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('ForeignPatent')),'Same Workspace is insufficient without Project membership';
 assert not exists(select 1 from public.patent_search_logs where id=pg_temp.research_source('ForeignSearch'));
 perform pg_temp.pr_bad(format('select public.create_patent_record(%L::jsonb)',(select record_input from pr_inputs where label='OtherResearch')));
 perform pg_temp.pr_bad(format('select public.create_patent_search_log(%L::jsonb)',(select search_input from pr_inputs where label='OtherResearch')));
 perform pg_temp.pr_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('ForeignPatent')));
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 select record_input into v from pr_inputs where label='Team';
 foreach k in array array['createdBy','created_by','actorId','noveltyScore','patentabilityStatus'] loop
  perform pg_temp.pr_bad(format('select public.create_patent_record(%L::jsonb)',v||jsonb_build_object(k,'00000000-0000-4000-8000-000000006005')),'22023');
 end loop;
 select search_input into v from pr_inputs where label='Team';
 foreach k in array array['searchedBy','searched_by','searchedAt','actorId','force'] loop
  perform pg_temp.pr_bad(format('select public.create_patent_search_log(%L::jsonb)',v||jsonb_build_object(k,'00000000-0000-4000-8000-000000006005')),'22023');
 end loop;
 perform pg_temp.pr_bad('insert into public.patent_records default values');
 perform pg_temp.pr_bad('insert into public.patent_search_logs default values');
 perform pg_temp.pr_bad('update public.patent_records set why_retained=''spoof''');
 perform pg_temp.pr_bad('delete from public.patent_records');
 perform pg_temp.pr_bad('update public.patent_search_logs set notes=''spoof''');
 perform pg_temp.pr_bad('delete from public.patent_search_logs');
end$$;
reset role;
-- Reads of existing links must independently honor source RLS, even while the
-- caller still has access to the Evidence and Activity endpoints.
savepoint patent_source_boundary;
create policy pr_test_source_denial on public.patent_records as restrictive for select to authenticated using(false);
set local role authenticated;
do $$begin
 assert exists(select 1 from public.evidence where id=pg_temp.research_source('Evidence'));
 assert public.can_read_activity_instance(pg_temp.research_context('Session9'));
 assert not exists(select 1 from public.evidence_links where linked_entity_type='PATENT_RECORD');
 assert not exists(select 1 from public.activity_research_links where entity_type='PATENT_RECORD');
 assert exists(select 1 from public.activity_research_links where entity_type='PATENT_SEARCH_LOG');
end$$;
rollback to patent_source_boundary;
savepoint search_source_boundary;
create policy pr_test_search_denial on public.patent_search_logs as restrictive for select to authenticated using(false);
set local role authenticated;
do $$begin
 assert public.can_read_activity_instance(pg_temp.research_context('Session9'));
 assert not exists(select 1 from public.activity_research_links where entity_type='PATENT_SEARCH_LOG');
 assert exists(select 1 from public.activity_research_links where entity_type='PATENT_RECORD');
end$$;
rollback to search_source_boundary;
-- Prove RLS itself denies mutation even if table grants are accidentally added.
grant insert,update,delete on public.patent_records,public.patent_search_logs to authenticated;
set local role authenticated;
do $$begin
 update public.patent_records set why_retained='spoof';assert not found;
 delete from public.patent_records;assert not found;
 update public.patent_search_logs set notes='spoof';assert not found;
 delete from public.patent_search_logs;assert not found;
 perform pg_temp.pr_bad(format('insert into public.patent_records(project_id,workspace_id,publication_number,title,source_database,source_url) values(%L,%L,''Public known number'',''Spoof'',''USPTO'',''https://example.test/public-patent'')',(select record_input->>'projectId' from pr_inputs where label='Team'),(select record_input->>'workspaceId' from pr_inputs where label='Team')));
 perform pg_temp.pr_bad(format('insert into public.patent_search_logs(project_id,workspace_id,activity_instance_id,database_name,query_text,search_method,reason) values(%L,%L,%L,''USPTO'',''q'',''m'',''r'')',(select record_input->>'projectId' from pr_inputs where label='Team'),(select record_input->>'workspaceId' from pr_inputs where label='Team'),pg_temp.research_context('Session9')));
end$$;
reset role;
revoke insert,update,delete on public.patent_records,public.patent_search_logs from authenticated;
-- Trusted attempts also cannot overwrite/delete Search history or spoof origin.
select pg_temp.pr_bad('update public.patent_search_logs set notes=''overwrite''','55000');
select pg_temp.pr_bad('delete from public.patent_search_logs','55000');
select pg_temp.pr_bad(format('insert into public.patent_records(project_id,workspace_id,publication_number,title,source_database,source_url,created_by) select project_id,workspace_id,''N'',''T'',''USPTO'',''https://example.test'',%L from public.patent_records limit 1','00000000-0000-4000-8000-000000006005'));
select pg_temp.pr_bad(format('insert into public.patent_search_logs(project_id,workspace_id,activity_instance_id,database_name,query_text,search_method,reason,searched_by) select project_id,workspace_id,activity_instance_id,''USPTO'',''q'',''m'',''r'',%L from public.patent_search_logs limit 1','00000000-0000-4000-8000-000000006005'));
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent'));
 assert not exists(select 1 from public.patent_search_logs where id=pg_temp.research_source('Search'));
 assert not exists(select 1 from public.activity_research_links where entity_id in (pg_temp.research_source('Patent'),pg_temp.research_source('Search')));
 assert not exists(select 1 from public.evidence_links where linked_entity_id=pg_temp.research_source('Patent'));
 assert exists(select 1 from public.patent_records where id=pg_temp.research_source('PersonalPatent'));
 assert exists(select 1 from public.patent_search_logs where id=pg_temp.research_source('PersonalSearch'));
 perform pg_temp.pr_bad(format('select public.create_patent_record(%L::jsonb)',(select record_input from pr_inputs where label='Team')));
 perform pg_temp.pr_bad(format('select public.create_patent_search_log(%L::jsonb)',(select search_input from pr_inputs where label='Team')));
 perform pg_temp.pr_bad(format('select public.link_patent_to_evidence(%L::jsonb)',jsonb_build_object('patentRecordId',pg_temp.research_source('Patent'),'evidenceType','PATENT','title','Stale','description','Stale')));
 perform pg_temp.pr_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_SEARCH_LOG',pg_temp.research_source('Search')));
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent'));
 assert exists(select 1 from public.patent_search_logs where id=pg_temp.research_source('Search'));
 assert exists(select 1 from public.evidence_links where linked_entity_id=pg_temp.research_source('Patent'));
 assert exists(select 1 from public.activity_research_links where entity_id=pg_temp.research_source('Search'));
end$$;
set local role anon;
select pg_temp.pr_bad('select * from public.patent_records');
select pg_temp.pr_bad('select * from public.patent_search_logs');
reset role;
do $$declare fn regprocedure;t regclass;begin
 assert (select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p)=(select patents from pr_history);
 assert (select jsonb_agg(to_jsonb(s) order by id) from public.patent_search_logs s)=(select searches from pr_history);
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e)=(select evidence from pr_history);
 assert (select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l)=(select evidence_links from pr_history);
 assert (select jsonb_agg(to_jsonb(l) order by id) from public.activity_research_links l)=(select research_links from pr_history);
 foreach t in array array['public.patent_records'::regclass,'public.patent_search_logs'::regclass] loop
  assert (select relrowsecurity from pg_class where oid=t);
  assert not has_table_privilege('authenticated',t,'INSERT') and not has_table_privilege('authenticated',t,'UPDATE') and not has_table_privilege('authenticated',t,'DELETE');
 end loop;
 foreach fn in array array['public.create_patent_record(jsonb)'::regprocedure,'public.create_patent_search_log(jsonb)'::regprocedure,'public.link_patent_to_evidence(jsonb)'::regprocedure,'public.add_activity_research_reference(uuid,text,uuid)'::regprocedure] loop
  assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid=fn);
  assert has_function_privilege('authenticated',fn,'EXECUTE') and not has_function_privilege('anon',fn,'EXECUTE') and not has_function_privilege('service_role',fn,'EXECUTE');
 end loop;
 assert to_regclass('public.patent_comparisons') is null,'M12.17 remains deferred';
 assert not exists(select 1 from information_schema.columns where table_schema='public' and table_name in ('patent_records','patent_search_logs') and column_name ~ '(novelty|patentability|infringement|legal_conclusion|fto)');
end$$;
select 'M12.22 Patent/Search exact-ID/public-source-filters/Personal/TeamB/role-only/Project/source-link-ACL/spoof/RPC/direct-DML/append-only/repeat/history/removal/Evidence/Activity/no-comparison PASS';
rollback;
