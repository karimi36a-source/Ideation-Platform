reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table pe_patents(label text primary key,payload jsonb);
create temporary table pe_created(label text,payload jsonb);
grant select on pe_patents to authenticated,anon;
grant select,insert on pe_created to authenticated;
insert into pe_patents select label,public.create_patent_record(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','publicationNumber',' WO 2025/012345 A1 ','title','Source patent','sourceDatabase','PATENTSCOPE','sourceUrl','HTTPS://research.example.test/patent?q=source','relevanceStatus','RELEVANT')) from logged_projects where label in ('Team','Individual');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('Patent Evidence B',public.create_development_project('Patent Evidence B','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='B'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='B')));
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006006' from logged_projects where label='Patent Evidence B';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
insert into pe_patents select 'Team B',public.create_patent_record(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','publicationNumber','B source','title','B private source','sourceDatabase','USPTO','sourceUrl','https://research.example.test/b')) from logged_projects where label='Patent Evidence B';
create function pg_temp.pe_input(scope text,kind text default 'PATENT') returns jsonb language sql as $$select jsonb_build_object('patentRecordId',payload->>'id','evidenceType',kind,'title',' Human source observation ','description',' Source-backed description ')||case when kind='PATENT_CLAIM' then jsonb_build_object('claimLocator',' Claims 1–3 ') else '{}'::jsonb end from pe_patents where label=scope$$;
create function pg_temp.pe_bad(input jsonb,expected text) returns void language plpgsql as $$begin perform public.link_patent_to_evidence(input);raise exception 'Patent Evidence attack accepted';exception when others then if sqlstate<>expected then raise;end if;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$declare scope text;kind text;e jsonb;p jsonb;begin
 foreach scope in array array['Team','Individual'] loop
  foreach kind in array array['PATENT','PATENT_CLAIM'] loop
   e:=public.link_patent_to_evidence(pg_temp.pe_input(scope,kind));
   select payload into p from pe_patents where label=scope;
   assert e->>'project_id'=p->>'project_id' and e->>'workspace_id'=p->>'workspace_id';
   assert e->>'source_name'=(p->>'source_database')||': '||(p->>'publication_number') and e->>'source_url'=p->>'source_url';
   assert e->>'title'=' Human source observation ' and e->>'description'=' Source-backed description ';
   assert e->>'verification_status'='UNVERIFIED' and e->>'verified_by' is null and e->>'verified_at' is null,'Relevance never verifies Evidence';
   assert e->>'file_id' is null and e->'metadata'='{}'::jsonb and e->>'created_by'=public.current_platform_user_id()::text;
   assert (e->>'captured_at')::timestamptz between transaction_timestamp() and clock_timestamp();
   assert e->>'claim_locator' is not distinct from case when kind='PATENT_CLAIM' then ' Claims 1–3 ' else null end;
   assert (select count(*) from public.evidence_links where evidence_id=(e->>'id')::uuid and linked_entity_type='PATENT_RECORD' and linked_entity_id=(p->>'id')::uuid and relationship_type='RELATED_TO' and created_by=public.current_platform_user_id())=1;
   insert into pe_created values(scope,e);
  end loop;
 end loop;
 insert into pe_created values('Repeat',public.link_patent_to_evidence(pg_temp.pe_input('Team')));
 assert (select count(distinct payload->>'id') from pe_created)=5,'No Evidence auto-merge';
end$$;
savepoint pe_verification_regression;
do $$declare e jsonb;begin
 e:=public.verify_evidence((select (payload->>'id')::uuid from pe_created where label='Individual' and payload->>'evidence_type'='PATENT_CLAIM'),'VERIFIED','Human source review');
 assert e->>'claim_locator'=' Claims 1–3 ' and e->>'verification_status'='VERIFIED';
 assert e->>'verified_by'=public.current_platform_user_id()::text and e->>'verified_at' is not null;
 begin perform public.verify_evidence((select (payload->>'id')::uuid from pe_created where label='Team' and payload->>'evidence_type'='PATENT_CLAIM'),'VERIFIED','Not a Team Lead');raise exception 'Member verification escalation';exception when insufficient_privilege then null;end;
end$$;
rollback to pe_verification_regression;
do $$declare v jsonb;patch jsonb;n int;begin
 v:=pg_temp.pe_input('Team');
 foreach patch in array array['{"sourceUrl":"https://spoof.example.test"}'::jsonb,'{"sourceName":"Spoof"}','{"createdBy":"00000000-0000-4000-8000-000000006005"}','{"workspaceId":"00000000-0000-4000-8000-000000006005"}','{"projectId":"00000000-0000-4000-8000-000000006005"}','{"verificationStatus":"VERIFIED"}','{"verifiedBy":"00000000-0000-4000-8000-000000006005"}','{"metadata":{}}','{"unknown":true}','{"evidenceType":"PAPER"}','{"claimLocator":"Claim 1"}','{"claimLocator":null}','{"evidenceType":"PATENT_CLAIM"}','{"evidenceType":"PATENT_CLAIM","claimLocator":" \t\n "}','{"evidenceType":"PATENT_CLAIM","claimLocator":1}','{"title":" "}','{"description":" "}'] loop perform pg_temp.pe_bad(v||patch,'22023');end loop;
 perform pg_temp.pe_bad(v||jsonb_build_object('patentRecordId','ffffffff-ffff-4fff-8fff-ffffffffffff'),'42501');
 perform pg_temp.pe_bad(pg_temp.pe_input('Team B'),'42501');
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  perform pg_temp.pe_bad(v,'42501');
  assert not exists(select 1 from public.evidence where id in(select (payload->>'id')::uuid from pe_created));
  assert not exists(select 1 from public.evidence_links where linked_entity_type='PATENT_RECORD');
  assert not exists(select 1 from public.evidence_links l join public.evidence e on e.id=l.evidence_id join public.patent_records p on p.id=l.linked_entity_id where l.linked_entity_type='PATENT_RECORD');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 perform pg_temp.pe_bad(pg_temp.pe_input('Individual'),'42501');
 assert not exists(select 1 from public.evidence where id in(select (payload->>'id')::uuid from pe_created where label='Individual'));
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
end$$;
reset role;
create temporary table pe_before as select (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,(select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l) links,(select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p) patents;
-- Force failures at both transaction steps; committed fixtures must remain exact.
create function pg_temp.pe_fail() returns trigger language plpgsql as $$begin raise exception 'Forced Patent Evidence failure' using errcode='23514';end$$;
create trigger pe_fail before insert on public.evidence_links for each row execute function pg_temp.pe_fail();
set local role authenticated;
select pg_temp.pe_bad(pg_temp.pe_input('Team'),'23514');
reset role;
drop trigger pe_fail on public.evidence_links;
create trigger pe_fail before insert on public.evidence for each row execute function pg_temp.pe_fail();
set local role authenticated;
select pg_temp.pe_bad(pg_temp.pe_input('Team'),'23514');
reset role;
drop trigger pe_fail on public.evidence;
do $$begin
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) is not distinct from (select evidence from pe_before),'Evidence failure/link failure leave no orphan';
 assert (select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l) is not distinct from (select links from pe_before);
 assert (select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p) is not distinct from (select patents from pe_before),'Patent source unmodified';
 begin update public.evidence set claim_locator=null where id=(select (payload->>'id')::uuid from pe_created where payload->>'evidence_type'='PATENT_CLAIM' limit 1);raise exception 'Missing claim accepted';exception when check_violation then null;end;
 begin update public.evidence set claim_locator='Claim 1' where id=(select (payload->>'id')::uuid from pe_created where payload->>'evidence_type'='PATENT' limit 1);raise exception 'Patent locator accepted';exception when check_violation then null;end;
end$$;
set local role authenticated;
do $$begin
 begin insert into public.evidence default values;raise exception 'Direct Evidence INSERT';exception when insufficient_privilege then null;end;
 begin insert into public.evidence_links default values;raise exception 'Direct Link INSERT';exception when insufficient_privilege then null;end;
 begin delete from public.evidence;raise exception 'Direct DELETE';exception when insufficient_privilege then null;end;
end$$;
select 'PATENT_EVIDENCE_ROW='||payload::text from pe_created where label='Team' and payload->>'evidence_type'='PATENT_CLAIM';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.pe_bad(pg_temp.pe_input('Team'),'42501');
do $$begin
 assert not exists(select 1 from public.evidence where id in(select (payload->>'id')::uuid from pe_created where label in ('Team','Repeat')));
 assert not exists(select 1 from public.evidence_links where linked_entity_id=(select (payload->>'id')::uuid from pe_patents where label='Team'));
 assert (select count(*) from public.evidence_links where linked_entity_id=(select (payload->>'id')::uuid from pe_patents where label='Individual'))=2,'Personal evidence unaffected';
end$$;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.pe_bad(pg_temp.pe_input('Team'),'28000');
set local role anon;
select pg_temp.pe_bad(pg_temp.pe_input('Team'),'42501');
reset role;
do $$begin
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.link_patent_to_evidence(jsonb)'::regprocedure);
 assert not has_function_privilege('anon','public.link_patent_to_evidence(jsonb)','execute');
 assert not has_function_privilege('service_role','public.link_patent_to_evidence(jsonb)','execute');
 assert not has_table_privilege('authenticated','public.evidence','insert,update,delete');
 assert not has_table_privilege('authenticated','public.evidence_links','insert,update,delete');
 assert (select count(*) from public.evidence_links where linked_entity_type='PATENT_RECORD')=5;
 assert not exists(select 1 from public.evidence where id in(select (payload->>'id')::uuid from pe_created) and (verification_status<>'UNVERIFIED' or verified_by is not null or verified_at is not null));
end$$;
select 'M12.14 Patent/PATENT_CLAIM/locator/source-provenance/UNVERIFIED/relevance-boundary/exact-link/atomic-rollback/no-merge/Personal/TeamB/removal/role-only/direct-ID/join/grants/no-legal-inference PASS';
rollback;
