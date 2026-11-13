reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table patent_cases(label text primary key,id uuid,before_row jsonb);
grant select on patent_cases to authenticated,anon;
create function pg_temp.patent_bad(statement text,expected text) returns void language plpgsql as $$begin execute statement;raise exception 'Patent schema attack accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
do $$declare source public.patent_source_database;p record;r public.patent_records;begin
 for p in select label,payload from logged_projects where label in ('Team','Individual') loop
  foreach source in array enum_range(null::public.patent_source_database) loop
   insert into public.patent_records(project_id,workspace_id,publication_number,title,source_database,source_url)
    values((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,' WO 2025/012345 A1 ','Retained source metadata',source,'https://research.example.test/document?q=WO%202025') returning * into r;
   assert r.relevance_status='NOT_REVIEWED';assert r.created_by='00000000-0000-4000-8000-000000006004';assert r.created_at is not null;
   assert r.publication_number=' WO 2025/012345 A1 ','Source formatting retained';
   insert into patent_cases values(p.label||'/'||source,r.id,to_jsonb(r));
  end loop;
 end loop;
end$$;
-- All four research labels are schema-valid human classifications, never inferred.
do $$declare value public.patent_relevance_status;begin
 foreach value in array enum_range(null::public.patent_relevance_status) loop
  update public.patent_records set relevance_status=value where id=(select id from patent_cases where label='Team/PATENTSCOPE');
 end loop;
end$$;
update public.patent_records set relevance_status='NOT_REVIEWED',application_number='PCT/Original-2024',applicant='Source applicant',inventor='Source inventor',priority_date='2020-02-29',filing_date='2021-01-02',publication_date='2022-03-04',ipc_cpc='A01B 1/00',abstract_text='Original abstract',why_retained='Human research note' where id=(select id from patent_cases where label='Team/PATENTSCOPE');
create temporary table patent_before as select jsonb_agg(to_jsonb(p) order by id) payload from public.patent_records p;
do $$declare base text;url text;begin
 select format('insert into public.patent_records(project_id,workspace_id,publication_number,title,source_database,source_url) values(%L,%L,''Source #1'',''Metadata'',''PATENTSCOPE'',%%L)',payload->>'id',payload->>'primary_workspace_id') into base from logged_projects where label='Team';
 foreach url in array array['http://example.test','ftp://example.test','javascript:alert(1)','https://','https://example.test:bad','https://example.test:65536','https://bad host.test','https://[bad-ipv6]/source'] loop
  perform pg_temp.patent_bad(format(base,url),'23514');
 end loop;
 -- Domain is not an allowlist; validate and preserve custom hosts and IPv6.
 assert private.valid_patent_source_url('https://custom-research.example.test/source');
 assert private.valid_patent_source_url('https://[::1]:443/source?q=x');
 perform pg_temp.patent_bad(replace(format(base,'https://example.test'),'PATENTSCOPE','OTHER'),'22P02');
 perform pg_temp.patent_bad('update public.patent_records set relevance_status=''PATENTABLE''','22P02');
 perform pg_temp.patent_bad('update public.patent_records set publication_number=''''','23514');
 perform pg_temp.patent_bad('update public.patent_records set title=''''','23514');
 perform pg_temp.patent_bad('update public.patent_records set priority_date=''2025-02-30''','22008');
 perform pg_temp.patent_bad(format('insert into public.patent_records(project_id,workspace_id,publication_number,title,source_database,source_url) values(%L,%L,''N'',''T'',''USPTO'',''https://example.test'')',(select payload->>'id' from logged_projects where label='Team'),(select payload->>'primary_workspace_id' from logged_projects where label='Individual')),'23503');
 perform pg_temp.patent_bad(format('insert into public.patent_records(project_id,workspace_id,publication_number,title,source_database,source_url,created_by) select project_id,workspace_id,publication_number,title,source_database,source_url,%L from public.patent_records limit 1','00000000-0000-4000-8000-000000006005'),'42501');
end$$;
set local role authenticated;
do $$declare n int;begin
 assert (select count(*) from public.patent_records)=6,'Canonical Personal and Team scope reads';
 assert (select count(*) from public.patent_records where publication_number=' WO 2025/012345 A1 ')=6,'No global or scope duplicate policy';
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  assert not exists(select 1 from public.patent_records);
  assert not exists(select 1 from public.patent_records where id=(select id from patent_cases where label='Team/PATENTSCOPE'));
  assert not exists(select 1 from public.patent_records p join public.workspaces w on w.id=p.workspace_id);
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 assert not exists(select 1 from public.patent_records where id in(select id from patent_cases where label like 'Individual/%')),'Same Team does not expose Personal research';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 perform pg_temp.patent_bad('insert into public.patent_records default values','42501');
 perform pg_temp.patent_bad('update public.patent_records set relevance_status=''RELEVANT''','42501');
 perform pg_temp.patent_bad('delete from public.patent_records','42501');
end$$;
select 'PATENT_SCHEMA_ROW='||to_jsonb(p)::text from public.patent_records p where id=(select id from patent_cases where label='Team/PATENTSCOPE');
select 'PATENT_VOCABULARY='||jsonb_build_object('relevance',enum_range(null::public.patent_relevance_status),'sources',enum_range(null::public.patent_source_database))::text;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.patent_records where id in(select id from patent_cases where label like 'Team/%'));
 assert (select count(*) from public.patent_records)=3,'Personal scope remains intact';
end$$;
set local role anon;
select pg_temp.patent_bad('select * from public.patent_records','42501');
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p)=(select payload from patent_before),'Removal and attacks preserve source history';
 assert not exists(select 1 from pg_attribute where attrelid='public.patent_records'::regclass and attnum>0 and not attisdropped and attname in ('novelty_score','patentability_status','infringement_risk','legal_status_conclusion','fto_conclusion'));
 assert (select count(*) from pg_trigger where tgrelid='public.patent_records'::regclass and not tgisinternal)=1,'Only provenance/history guard; no conclusion automation';
 assert has_function_privilege('authenticated','public.create_patent_record(jsonb)','execute');
 assert not has_function_privilege('anon','public.create_patent_record(jsonb)','execute');
 assert not exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname in ('compare_patent_with_project'));
 assert not exists(select 1 from pg_constraint where conrelid='public.patent_records'::regclass and contype='u'),'No publication uniqueness constraint';
 assert not exists(select 1 from pg_index where indrelid='public.patent_records'::regclass and indisunique and not indisprimary),'No publication unique index';
 assert (select relrowsecurity from pg_class where oid='public.patent_records'::regclass);
 assert has_table_privilege('authenticated','public.patent_records','select');
 assert not has_table_privilege('authenticated','public.patent_records','insert,update,delete');
 assert not has_function_privilege('authenticated','private.preserve_patent_record_history()','execute');
end$$;
select 'M12.11 patent source vocab/default/HTTPS/date/provenance/compatible-scopes/Personal/TeamB/removal/role-only/exact-ID/join/direct-DML/duplicate-preservation/no-legal-conclusions PASS';
rollback;
