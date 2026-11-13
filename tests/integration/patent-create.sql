reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table pc_inputs(label text primary key,payload jsonb);
insert into pc_inputs select label,jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','publicationNumber',' WO 2025/012345 A1 ','title',' Original source title ','sourceDatabase','PATENTSCOPE','sourceUrl','https://research.example.test/source?q=WO%202025') from logged_projects where label in ('Team','Individual');
create temporary table pc_created(label text,payload jsonb);
grant select on pc_inputs to authenticated,anon;
grant select,insert on pc_created to authenticated;
create temporary table pc_history as select
 (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,
 (select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l) links;
create function pg_temp.pc_bad(statement text,expected text) returns void language plpgsql as $$begin execute statement;raise exception 'Patent create attack accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
set local role authenticated;
do $$declare p record;s public.patent_source_database;r jsonb;begin
 for p in select * from pc_inputs loop
  foreach s in array enum_range(null::public.patent_source_database) loop
   r:=public.create_patent_record(p.payload||jsonb_build_object('sourceDatabase',s));
   assert r->>'publication_number'=p.payload->>'publicationNumber' and r->>'title'=p.payload->>'title';
   assert r->>'source_database'=s::text and r->>'source_url'=p.payload->>'sourceUrl';
   assert r->>'relevance_status'='NOT_REVIEWED' and r->>'created_by'='00000000-0000-4000-8000-000000006004';
   assert r->>'created_at' is not null;
   insert into pc_created values(p.label,r);
  end loop;
 end loop;
end$$;
do $$declare status public.patent_relevance_status;r jsonb;v jsonb;begin
 foreach status in array enum_range(null::public.patent_relevance_status) loop
  select payload||jsonb_build_object('applicationNumber','PCT/Exact 2024','applicant','Original applicant','inventor','Original inventor','priorityDate','2024-02-29','filingDate','2025-01-02','publicationDate','2025-06-03','ipcCpc','A01B 1/00','abstractText','Source abstract','whyRetained',' Human research notes ','relevanceStatus',status) into v from pc_inputs where label='Team';
  r:=public.create_patent_record(v);
  assert r->>'why_retained'=' Human research notes ' and r->>'relevance_status'=status::text;
  assert r->>'application_number'='PCT/Exact 2024' and r->>'applicant'='Original applicant' and r->>'inventor'='Original inventor';
  assert r->>'priority_date'='2024-02-29' and r->>'filing_date'='2025-01-02' and r->>'publication_date'='2025-06-03';
  assert r->>'ipc_cpc'='A01B 1/00' and r->>'abstract_text'='Source abstract';
  insert into pc_created values('Explicit',r);
 end loop;
end$$;
do $$declare v jsonb;extra jsonb;n int;begin
 select payload into v from pc_inputs where label='Team';
 foreach extra in array array[
  '{"createdBy":"00000000-0000-4000-8000-000000006005"}'::jsonb,'{"created_by":"00000000-0000-4000-8000-000000006005"}','{"unknown":true}',
  '{"relevanceStatus":null}','{"relevanceStatus":1}','{"sourceDatabase":1}','{"applicant":false}',
  '{"sourceUrl":"http://example.test"}','{"priorityDate":"2025-02-29"}','{"filingDate":"2025-04-31"}','{"publicationDate":"01/02/2025"}'
 ] loop perform pg_temp.pc_bad(format('select public.create_patent_record(%L::jsonb)',v||extra),'22023');end loop;
 perform pg_temp.pc_bad(format('select public.create_patent_record(%L::jsonb)',v||'{"relevanceStatus":"NOVEL"}'),'22P02');
 perform pg_temp.pc_bad(format('select public.create_patent_record(%L::jsonb)',v||'{"sourceDatabase":"OTHER"}'),'22P02');
 perform pg_temp.pc_bad(format('select public.create_patent_record(%L::jsonb)',v||jsonb_build_object('workspaceId',(select payload->>'workspaceId' from pc_inputs where label='Individual'))),'42501');
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  perform pg_temp.pc_bad(format('select public.create_patent_record(%L::jsonb)',v),'42501');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 perform pg_temp.pc_bad(format('select public.create_patent_record(%L::jsonb)',(select payload from pc_inputs where label='Individual')),'42501');
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 assert (select count(*) from public.patent_records)=10,'Exactly one row per successful create; failures add none';
 assert (select count(distinct id) from public.patent_records)=10,'Duplicate publication creates distinct canonical records';
 perform pg_temp.pc_bad('insert into public.patent_records default values','42501');
 perform pg_temp.pc_bad('update public.patent_records set relevance_status=''RELEVANT''','42501');
 perform pg_temp.pc_bad('delete from public.patent_records','42501');
end$$;
savepoint patent_create_rollback;
select public.create_patent_record(payload) from pc_inputs;
rollback to patent_create_rollback;
do $$begin assert (select count(*) from public.patent_records)=10,'Rollback leaves no extra records';end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.pc_bad(format('select public.create_patent_record(%L::jsonb)',payload),'42501') from pc_inputs where label='Team';
do $$begin assert (select count(*) from public.patent_records)=3,'Personal rows remain private and available after Team removal';end$$;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.pc_bad(format('select public.create_patent_record(%L::jsonb)',payload),'28000') from pc_inputs where label='Team';
set local role anon;
select pg_temp.pc_bad(format('select public.create_patent_record(%L::jsonb)',payload),'42501') from pc_inputs where label='Team';
reset role;
do $$begin
 assert (select count(*) from public.patent_records)=10,'History preserved after revocation';
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) is not distinct from (select evidence from pc_history),'No Evidence auto-creation or mutation';
 assert (select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l) is not distinct from (select links from pc_history),'No Evidence auto-link';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.create_patent_record(jsonb)'::regprocedure);
 assert has_function_privilege('authenticated','public.create_patent_record(jsonb)','execute');
 assert not has_function_privilege('anon','public.create_patent_record(jsonb)','execute');
 assert not has_function_privilege('service_role','public.create_patent_record(jsonb)','execute');
 assert not has_table_privilege('authenticated','public.patent_records','insert');
 assert not exists(select 1 from pg_attribute where attrelid='public.patent_records'::regclass and attname in ('novelty_score','patentability_status','infringement_risk','legal_status_conclusion','fto_conclusion'));
end$$;
select 'AT-PAT-001 M12.12 canonical source/notes/relevance/default/all-sources/dates/strict-input/scope/Personal/TeamB/removal/role-only/duplicate-rows/rollback/no-Evidence/no-legal-inference/grants PASS';
rollback;
