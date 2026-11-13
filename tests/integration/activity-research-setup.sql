reset role;
-- Isolated session-context fixtures use real canonical records; no curriculum or AI product is added.
create temporary table research_context(label text primary key,id uuid);
create temporary table research_sources(label text primary key,id uuid);
grant select,insert on research_context,research_sources to authenticated;
insert into research_context select 'Session8',id from instances where label='Team';
create function pg_temp.research_bad(statement text,expected text default '42501') returns void language plpgsql as $$begin execute statement;raise exception 'Research attack succeeded';exception when others then if sqlstate<>expected then raise;end if;end$$;
create function pg_temp.research_context(label0 text) returns uuid language sql as $$select id from research_context where label=$1$$;
create function pg_temp.research_source(label0 text) returns uuid language sql as $$select id from research_sources where label=$1$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into research_sources select 'Patent',(public.create_patent_record(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','publicationNumber',' WO Original 123 A1 ','title','Original source','sourceDatabase','PATENTSCOPE','sourceUrl','https://example.test/patent','whyRetained','Human source reason','relevanceStatus','POSSIBLY_RELEVANT'))->>'id')::uuid from logged_projects where label='Team';
insert into research_sources select 'PersonalPatent',(public.create_patent_record(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','publicationNumber',' WO Original 123 A1 ','title','Private source','sourceDatabase','USPTO','sourceUrl','https://example.test/private'))->>'id')::uuid from logged_projects where label='Individual';
insert into research_sources select 'Evidence',(public.link_patent_to_evidence(jsonb_build_object('patentRecordId',pg_temp.research_source('Patent'),'evidenceType','PATENT','title','Human reading','description','Original source reading'))->>'id')::uuid;
insert into research_sources select 'PersonalEvidence',(public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'MEASUREMENT','Private source','Private observations','Private notebook')->>'id')::uuid from logged_projects where label='Individual';
select public.add_activity_research_reference((select id from instances where label='Individual'),'PATENT_RECORD',pg_temp.research_source('PersonalPatent'));
select public.add_activity_evidence_output((select id from instances where label='Individual'),pg_temp.research_source('PersonalEvidence'));
select public.add_activity_research_reference(pg_temp.research_context('Session8'),'PATENT_RECORD',pg_temp.research_source('Patent'));
select public.add_activity_evidence_output(pg_temp.research_context('Session8'),pg_temp.research_source('Evidence'));
select public.add_activity_artifact_output(pg_temp.research_context('Session8'),(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'));
reset role;
-- A later isolated context shares the Project/Workspace, not the execution identity.
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=pg_temp.research_context('Session8');
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
 select activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,clock_timestamp(),'active',configuration_snapshot from public.activity_instances where id=pg_temp.research_context('Session8');
insert into research_context select 'Session9',id from public.activity_instances where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') and status='active';
set local role authenticated;
insert into research_sources select 'Search',(public.create_patent_search_log(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','activityInstanceId',pg_temp.research_context('Session9'),'databaseName','GOOGLE_PATENTS','queryText','Human query','searchMethod','Keyword refinement','reason','Human investigation','notes','Original search notes'))->>'id')::uuid from logged_projects where label='Team';
insert into research_sources select 'Gap',(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'GAP','Research gap','Human identified gap','User')->>'id')::uuid from logged_projects where label='Team';
insert into research_sources select 'Landscape',(public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PATENT_LANDSCAPE','Research landscape',pg_temp.research_context('Session9'),false,false)->>'artifactId')::uuid from logged_projects where label='Team';
select public.add_activity_evidence_input(pg_temp.research_context('Session9'),pg_temp.research_source('Evidence'),true);
select public.add_activity_artifact_input(pg_temp.research_context('Session9'),(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),null,true);
select public.add_activity_research_reference(pg_temp.research_context('Session9'),'PATENT_RECORD',pg_temp.research_source('Patent'));
select public.add_activity_research_reference(pg_temp.research_context('Session9'),'PATENT_SEARCH_LOG',pg_temp.research_source('Search'));
select public.add_activity_evidence_output(pg_temp.research_context('Session9'),pg_temp.research_source('Evidence'));
select public.add_activity_output(pg_temp.research_context('Session9'),pg_temp.research_source('Gap'));
select public.add_activity_artifact_output(pg_temp.research_context('Session9'),pg_temp.research_source('Landscape'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('OtherResearch',public.create_development_project('Other research Project','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006004' from logged_projects where label='OtherResearch';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into research_sources select 'ForeignPatent',(public.create_patent_record(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','publicationNumber','Other context','title','Other source','sourceDatabase','USPTO','sourceUrl','https://example.test/other'))->>'id')::uuid from logged_projects where label='OtherResearch';
insert into research_sources select 'ForeignEvidence',(public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'MEASUREMENT','Other source','Other observations','Other notebook')->>'id')::uuid from logged_projects where label='OtherResearch';
reset role;
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test') from logged_projects where label='OtherResearch';
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
 select a.activity_definition_id,a.cohort_id,(p.payload->>'id')::uuid,a.workspace_id,a.team_id,a.started_by,clock_timestamp(),'active',a.configuration_snapshot from public.activity_instances a cross join logged_projects p where a.id=pg_temp.research_context('Session9') and p.label='OtherResearch';
insert into research_context select 'ForeignActivity',a.id from public.activity_instances a join logged_projects p on a.project_id=(p.payload->>'id')::uuid where p.label='OtherResearch';
set local role authenticated;
insert into research_sources select 'ForeignSearch',(public.create_patent_search_log(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','activityInstanceId',pg_temp.research_context('ForeignActivity'),'databaseName','USPTO','queryText','Other query','searchMethod','Human research','reason','Different Project'))->>'id')::uuid from logged_projects where label='OtherResearch';
reset role;
create temporary table research_before as select
 (select jsonb_agg(to_jsonb(p) order by id) from public.patent_records p) patents,
 (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,
 (select jsonb_agg(to_jsonb(s) order by id) from public.patent_search_logs s) searches,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v) versions;
grant select on research_before to authenticated;

