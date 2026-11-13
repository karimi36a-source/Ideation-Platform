-- Shared M12 attack context: known IDs and independently accessible targets.
reset role;
create temporary table leakage_targets(scope text,kind text,id uuid,primary key(scope,kind));
create temporary table leakage_files(scope text primary key,payload jsonb);
grant select,insert on leakage_targets,leakage_files to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects select 'Leakage B',public.create_development_project('Leakage B','team',(payload->>'workspaceId')::uuid,null,null,(payload->>'teamId')::uuid) from acceptance_teams where label='B';
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006006' from logged_projects where label='Leakage B';
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test') from logged_projects where label='Leakage B';
-- Trusted Activity fixture only; all research mutations below use accepted RPCs.
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
 select a.activity_definition_id,a.cohort_id,(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006006',clock_timestamp(),'active',a.configuration_snapshot from public.activity_instances a cross join logged_projects p cross join acceptance_teams t where a.id=pg_temp.research_context('Session9') and p.label='Leakage B' and t.label='B';
insert into leakage_targets select 'B','ACTIVITY_INSTANCE',id from public.activity_instances where project_id=(select (payload->>'id')::uuid from logged_projects where label='Leakage B');
insert into leakage_targets select 'Personal','ACTIVITY_INSTANCE',id from instances where label='Individual';
do $$declare p record;r jsonb;f jsonb;begin
 for p in select label,payload from logged_projects where label in ('Team','Individual','Leakage B') loop
  perform set_config('request.jwt.claim.sub',case p.label when 'Leakage B' then '00000000-0000-4000-8000-000000006006' else '00000000-0000-4000-8000-000000006004' end,true);
  r:=public.request_file_upload((p.payload->>'primary_workspace_id')::uuid,(p.payload->>'id')::uuid,'leakage.txt','text/plain',3);
  insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',r->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
  f:=public.register_uploaded_file((r->>'id')::uuid);
  insert into leakage_files values(case p.label when 'Leakage B' then 'B' when 'Individual' then 'Personal' else 'A' end,f);
 end loop;
end$$;
set local role authenticated;
-- Give B1 authority to create B's Decision; it confers no Team A access.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006');
do $$declare p record;k text;label0 text;begin
 for p in select label,payload from logged_projects where label in ('Individual','Leakage B') loop
  label0:=case p.label when 'Leakage B' then 'B' else 'Personal' end;
  perform set_config('request.jwt.claim.sub',case label0 when 'B' then '00000000-0000-4000-8000-000000006006' else '00000000-0000-4000-8000-000000006004' end,true);
  foreach k in array array['GAP','REQUIREMENT'] loop
   insert into leakage_targets values(label0,k,(public.create_development_object((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,k::public.development_object_type,'Accessible target','Private target','User')->>'id')::uuid);
  end loop;
  insert into leakage_targets values(label0,'ARTIFACT',(public.create_artifact((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','Accessible target',null,false,false)->>'artifactId')::uuid);
  insert into leakage_targets values(label0,'DECISION',(public.create_decision(jsonb_build_object('projectId',p.payload->>'id','workspaceId',p.payload->>'primary_workspace_id','title','Accessible Decision','question','Human question','method','OTHER','options','[{"label":"Human choice"}]'::jsonb))#>>'{decision,id}')::uuid);
  insert into leakage_targets values(label0,'EVIDENCE',(public.create_evidence((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,'MEASUREMENT','Accessible Evidence','Private observations','Notebook')->>'id')::uuid);
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.link_file(jsonb_build_object('fileId',(select payload->>'id' from leakage_files where scope='A'),'entityType','EVIDENCE','entityId',pg_temp.research_source('Evidence'),'relationshipType','REFERENCE'));
reset role;
create temporary table leakage_known_links as
 select 'EVIDENCE'::text kind,id from public.evidence_links where evidence_id=pg_temp.research_source('Evidence')
 union all select 'FILE',id from public.file_links where file_id=(select (payload->>'id')::uuid from leakage_files where scope='A')
 union all select 'RESEARCH',id from public.activity_research_links where activity_instance_id=pg_temp.research_context('Session9');
grant select on leakage_known_links to authenticated;
create temporary table leakage_history as select
 (select jsonb_agg(to_jsonb(x) order by id) from public.evidence x) evidence,
 (select jsonb_agg(to_jsonb(x) order by id) from public.evidence_links x) evidence_links,
 (select jsonb_agg(to_jsonb(x) order by id) from public.files x) files,
 (select jsonb_agg(to_jsonb(x) order by id) from public.file_links x) file_links,
 (select jsonb_agg(to_jsonb(x) order by id) from public.patent_records x) patents,
 (select jsonb_agg(to_jsonb(x) order by id) from public.patent_search_logs x) searches,
 (select jsonb_agg(to_jsonb(x) order by id) from public.activity_research_links x) research,
 (select jsonb_agg(to_jsonb(x) order by id) from storage.objects x) objects;
create function pg_temp.leakage_attack(target_scope text) returns void language plpgsql as $$declare fa uuid;path text;t record;own_e uuid;begin
 select (payload->>'id')::uuid,payload->>'storage_reference' into fa,path from leakage_files where scope='A';
 assert not exists(select 1 from public.evidence where id=pg_temp.research_source('Evidence'));
 assert not exists(select 1 from public.evidence_links where evidence_id=pg_temp.research_source('Evidence') or linked_entity_id=pg_temp.research_source('Patent'));
 assert not exists(select 1 from public.files where id=fa or storage_reference=path);
 assert not exists(select 1 from public.file_links where file_id=fa);
 assert not exists(select 1 from public.evidence_links where id in(select id from leakage_known_links where kind='EVIDENCE'));
 assert not exists(select 1 from public.file_links where id in(select id from leakage_known_links where kind='FILE'));
 assert not exists(select 1 from public.activity_research_links where id in(select id from leakage_known_links where kind='RESEARCH'));
 assert not exists(select 1 from storage.objects where bucket_id='fici-private-files' and name=path);
 -- Publication numbers may legitimately repeat in an independently authorized
 -- Personal Project. Public-source filters must hide A's row, not that own row.
 assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent') or (project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') and (publication_number=' WO Original 123 A1 ' or source_url='https://example.test/patent')));
 assert not exists(select 1 from public.patent_search_logs where id=pg_temp.research_source('Search') or query_text='Human query' or notes='Original search notes');
 assert not exists(select 1 from public.activity_research_links where entity_id in(pg_temp.research_source('Patent'),pg_temp.research_source('Search')) or activity_instance_id=pg_temp.research_context('Session9'));
 assert not exists(select 1 from public.activity_research_links r join public.patent_records p on r.entity_id=p.id where p.id=pg_temp.research_source('Patent'));
 assert not exists(select 1 from public.file_links l join public.files f on f.id=l.file_id join public.evidence e on l.entity_id=e.id where f.id=fa);
 perform pg_temp.research_bad(format('select public.link_patent_to_evidence(%L::jsonb)',jsonb_build_object('patentRecordId',pg_temp.research_source('Patent'),'evidenceType','PATENT','title','Attack','description','Attack')));
 perform pg_temp.research_bad(format('select public.archive_file(%L)',fa));
 perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('Patent')));
 if target_scope is not null then
  select id into own_e from leakage_targets where scope=target_scope and kind='EVIDENCE';
  assert exists(select 1 from public.evidence where id=own_e),'positive accessible target';
  assert exists(select 1 from public.files where id=(select (payload->>'id')::uuid from leakage_files where scope=target_scope));
  for t in select * from leakage_targets where scope=target_scope loop
   if t.kind in ('DECISION','GAP','REQUIREMENT','ARTIFACT') then
    perform pg_temp.research_bad(format('select public.link_evidence(%L::jsonb)',jsonb_build_object('evidenceId',pg_temp.research_source('Evidence'),'entityType',t.kind,'entityId',t.id,'relationshipType','SUPPORTS')));
   end if;
   if t.kind in ('GAP','REQUIREMENT','ARTIFACT','EVIDENCE','ACTIVITY_INSTANCE') then
    perform pg_temp.research_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',fa,'entityType',case when t.kind in ('GAP','REQUIREMENT') then 'DEVELOPMENT_OBJECT' else t.kind end,'entityId',t.id,'relationshipType','REFERENCE')));
   end if;
  end loop;
  -- Generic Patent-target linking is deliberately unsupported; the supported
  -- Patent -> Evidence operation above independently rejects foreign sources.
  perform pg_temp.research_bad(format('select public.link_evidence(%L::jsonb)',jsonb_build_object('evidenceId',own_e,'entityType','PATENT_RECORD','entityId',pg_temp.research_source('Patent'),'relationshipType','RELATED_TO')),'0A000');
  perform pg_temp.research_bad(format('select public.link_file(%L::jsonb)',jsonb_build_object('fileId',(select payload->>'id' from leakage_files where scope=target_scope),'entityType','EVIDENCE','entityId',pg_temp.research_source('Evidence'),'relationshipType','REFERENCE')));
  perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',(select id from leakage_targets where scope=target_scope and kind='ACTIVITY_INSTANCE'),'PATENT_RECORD',pg_temp.research_source('Patent')));
  perform pg_temp.research_bad(format('select public.add_activity_research_reference(%L,%L,%L)',(select id from leakage_targets where scope=target_scope and kind='ACTIVITY_INSTANCE'),'PATENT_SEARCH_LOG',pg_temp.research_source('Search')));
 end if;
end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.leakage_attack('B');
do $$declare n integer;begin
 foreach n in array array[6001,6002,6003,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  perform pg_temp.leakage_attack(null);
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.leakage_attack('Personal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert exists(select 1 from public.evidence where id=pg_temp.research_source('Evidence') and created_by='00000000-0000-4000-8000-000000006004');
 assert exists(select 1 from public.files where id=(select (payload->>'id')::uuid from leakage_files where scope='A'));
 assert exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent'));
 assert exists(select 1 from public.patent_search_logs where id=pg_temp.research_source('Search'));
 assert exists(select 1 from public.activity_research_links where entity_id=pg_temp.research_source('Search'));
end$$;
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.evidence x)=(select evidence from leakage_history);
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.evidence_links x)=(select evidence_links from leakage_history);
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.files x)=(select files from leakage_history);
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.file_links x)=(select file_links from leakage_history);
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.patent_records x)=(select patents from leakage_history);
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.patent_search_logs x)=(select searches from leakage_history);
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.activity_research_links x)=(select research from leakage_history);
 assert (select jsonb_agg(to_jsonb(x) order by id) from storage.objects x)=(select objects from leakage_history);
end$$;
select 'M12.28 combined TeamB/removed/role-only/exact-ID/independent-accessible-target/DB/RPC/storage/public-source/research-link/history leakage PASS';
rollback;
