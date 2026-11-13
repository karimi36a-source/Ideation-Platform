reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table ps_inputs(label text primary key,payload jsonb);
insert into ps_inputs select p.label,jsonb_build_object('projectId',p.payload->>'id','workspaceId',p.payload->>'primary_workspace_id','activityInstanceId',i.id,'databaseName','PATENTSCOPE','queryText',' Original query ','searchMethod','Keyword family refinement','reason','Human research reason','notes',' Private strategy ','termsLearned',jsonb_build_array('hinge','pivot'),'classificationsLearned',jsonb_build_array('A01B 1/00'),'resultsReviewedCount',5,'relevantResultsCount',2) from logged_projects p join instances i on i.label=p.label where p.label in ('Team','Individual');
create temporary table ps_created(label text,payload jsonb);
grant select on ps_inputs to authenticated,anon;
grant select,insert on ps_created to authenticated;
create function pg_temp.ps_bad(statement text,expected text) returns void language plpgsql as $$begin execute statement;raise exception 'Search attack accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
set local role authenticated;
do $$declare p record;s public.patent_source_database;r jsonb;begin
 for p in select * from ps_inputs loop
  foreach s in array enum_range(null::public.patent_source_database) loop
   r:=public.create_patent_search_log(p.payload||jsonb_build_object('databaseName',s));
   assert r->>'database_name'=s::text and r->>'query_text'=' Original query ' and r->>'notes'=' Private strategy ';
   assert r->>'searched_by'='00000000-0000-4000-8000-000000006004' and (r->>'searched_at')::timestamptz=statement_timestamp();
   assert r->'terms_learned'='["hinge","pivot"]'::jsonb and r->'classifications_learned'='["A01B 1/00"]'::jsonb;
   assert r->>'results_reviewed_count'='5' and r->>'relevant_results_count'='2';
   insert into ps_created values(p.label,r);
  end loop;
 end loop;
end$$;
reset role;
create temporary table ps_before as select jsonb_agg(to_jsonb(p) order by id) payload from public.patent_search_logs p;
set local role authenticated;
do $$declare v jsonb;extra jsonb;k text;n integer;begin
 select payload into v from ps_inputs where label='Team';
 foreach extra in array array['{"searchedBy":"00000000-0000-4000-8000-000000006005"}'::jsonb,'{"searched_at":"2000-01-01"}','{"unknown":true}','{"resultsReviewedCount":-1}','{"relevantResultsCount":6}','{"resultsReviewedCount":1.5}','{"resultsReviewedCount":2147483648}','{"resultsReviewedCount":null}','{"termsLearned":[null]}','{"classificationsLearned":{}}','{"notes":true}','{"queryText":"\t\n"}'] loop
  perform pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',v||extra),'22023');
 end loop;
 foreach k in array array['queryText','searchMethod','reason'] loop perform pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',v||jsonb_build_object(k,'   ')),'22023');end loop;
 perform pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',v||'{"databaseName":"OTHER"}'),'22P02');
 perform pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',v||jsonb_build_object('workspaceId',(select payload->>'workspaceId' from ps_inputs where label='Individual'))),'42501');
 perform pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',v||jsonb_build_object('projectId',(select payload->>'projectId' from ps_inputs where label='Individual'))),'42501');
 perform pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',v||jsonb_build_object('activityInstanceId',(select payload->>'activityInstanceId' from ps_inputs where label='Individual'))),'42501');
 perform pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',v||'{"activityInstanceId":"ffffffff-ffff-4fff-8fff-ffffffffffff"}'),'42501');
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  perform pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',v),'42501');
  assert not exists(select 1 from public.patent_search_logs);
  assert not exists(select 1 from public.patent_search_logs where id=(select (payload->>'id')::uuid from ps_created limit 1));
  assert not exists(select 1 from public.patent_search_logs s join public.activity_instances a on a.id=s.activity_instance_id),'No join leakage';
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 assert not exists(select 1 from public.patent_search_logs where workspace_id=(select (payload->>'workspaceId')::uuid from ps_inputs where label='Individual'));
 perform pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',(select payload from ps_inputs where label='Individual')),'42501');
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 perform pg_temp.ps_bad('insert into public.patent_search_logs default values','42501');
 perform pg_temp.ps_bad('update public.patent_search_logs set notes=''overwrite''','42501');
 perform pg_temp.ps_bad('delete from public.patent_search_logs','42501');
end$$;
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(p) order by id) from public.patent_search_logs p)=(select payload from ps_before),'All attacks preserve earlier rows';
 perform pg_temp.ps_bad('update public.patent_search_logs set notes=''overwrite''','55000');
 perform pg_temp.ps_bad('delete from public.patent_search_logs','55000');
 perform pg_temp.ps_bad(format('insert into public.patent_search_logs(project_id,workspace_id,activity_instance_id,database_name,query_text,search_method,reason) select project_id,workspace_id,%L,''USPTO'',''q'',''m'',''r'' from public.patent_search_logs where project_id=(select (payload->>''projectId'')::uuid from ps_inputs where label=''Team'') limit 1',(select payload->>'activityInstanceId' from ps_inputs where label='Individual')),'23514');
 perform pg_temp.ps_bad('insert into public.patent_search_logs(project_id,workspace_id,activity_instance_id,database_name,query_text,search_method,reason,searched_by) select project_id,workspace_id,activity_instance_id,''USPTO'',''q'',''m'',''r'',''00000000-0000-4000-8000-000000006005'' from public.patent_search_logs limit 1','42501');
end$$;
-- Refinement and exact repeat are new rows, never overwrite.
set local role authenticated;
insert into ps_created select 'Repeat',public.create_patent_search_log(payload) from ps_inputs where label='Team';
insert into ps_created select 'Refined',public.create_patent_search_log(payload||'{"queryText":"Refined query"}') from ps_inputs where label='Team';
insert into ps_created select 'Minimal',public.create_patent_search_log(payload-'resultsReviewedCount'-'relevantResultsCount'-'termsLearned'-'classificationsLearned'-'notes') from ps_inputs where label='Team';
do $$begin assert (select count(*) from public.patent_search_logs)=9;assert (select count(distinct id) from public.patent_search_logs)=9;end$$;
select 'PATENT_SEARCH_ROW='||payload::text from ps_created where label='Minimal';
savepoint search_rollback;
select public.create_patent_search_log(payload) from ps_inputs;
rollback to search_rollback;
reset role;
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select (payload->>'activityInstanceId')::uuid from ps_inputs where label='Team');
set local role authenticated;
select pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',payload),'55000') from ps_inputs where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',payload),'42501') from ps_inputs where label='Team';
do $$begin
 assert not exists(select 1 from public.patent_search_logs where id in(select (payload->>'id')::uuid from ps_created where label<>'Individual'));
 assert (select count(*) from public.patent_search_logs)=3,'Personal remains accessible';
end$$;
set local role anon;
select pg_temp.ps_bad('select * from public.patent_search_logs','42501');
select pg_temp.ps_bad(format('select public.create_patent_search_log(%L::jsonb)',payload),'42501') from ps_inputs limit 1;
reset role;
do $$begin
 assert (select count(*) from public.patent_search_logs)=9,'Removal and failed operations preserve history';
 assert not exists(select 1 from public.patent_search_logs p join ps_created c on p.id=(c.payload->>'id')::uuid where to_jsonb(p)<>c.payload),'Exact historical content remains';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.create_patent_search_log(jsonb)'::regprocedure);
 assert not has_function_privilege('anon','public.create_patent_search_log(jsonb)','execute');
 assert not has_function_privilege('service_role','public.create_patent_search_log(jsonb)','execute');
 assert not has_function_privilege('authenticated','private.preserve_patent_search_log()','execute');
 assert not has_table_privilege('authenticated','public.patent_search_logs','insert,update,delete');
end$$;
select 'AT-PAT-003 M12.13 sources/query/method/reason/date/actor/notes/arrays/counts/append-only/refinement/scope/Personal/TeamB/removal/role-only/exact-ID/join/grants PASS';
rollback;
