-- M12.20: direct PostgreSQL privacy matrix on accepted M12.18 canonical fixtures.
reset role;
create temporary table er_targets(label text primary key,kind text,id uuid);
create temporary table er_results(label text primary key,payload jsonb);
grant select,insert on er_targets,er_results to authenticated;
create function pg_temp.er_bad(statement text,expected text default '42501') returns void language plpgsql as $$begin execute statement;raise exception 'Evidence RLS attack succeeded';exception when others then if sqlstate<>expected then raise;end if;end$$;
create function pg_temp.er_link(source0 text,target0 text,relation0 text default 'SUPPORTS') returns jsonb language sql as $$select jsonb_build_object('evidenceId',pg_temp.de_source(source0),'entityType',kind,'entityId',id,'relationshipType',relation0) from er_targets where label=target0$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into er_targets values('Decision','DECISION',pg_temp.de_id('Main')),('Team B Decision','DECISION',pg_temp.de_id('Team B')),('Personal Decision','DECISION',pg_temp.de_id('Personal'));
insert into er_targets select 'Artifact','ARTIFACT',(payload->>'artifactId')::uuid from submitted_fixtures where label='Team';
insert into er_targets select kind,kind,(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,kind::public.development_object_type,'RLS target '||kind,'Canonical target','User')->>'id')::uuid from logged_projects cross join unnest(array['GAP','REQUIREMENT']) kind where label='Team';
insert into er_targets select 'Other Project Decision','DECISION',(public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','Other Project Decision','question','Other question','method','OTHER','options','[{"label":"Human option"}]'::jsonb))#>>'{decision,id}')::uuid from logged_projects where label='Other Project';
insert into er_results select label,public.link_evidence(pg_temp.er_link('UNVERIFIED',label)) from er_targets where label in ('Decision','Artifact','GAP','REQUIREMENT');
insert into er_results values('Finalized',public.finalize_decision(pg_temp.de_args('Main',array[pg_temp.de_source('UNVERIFIED'),pg_temp.de_source('VERIFIED'),pg_temp.de_source('NEEDS_REVIEW')])));
insert into er_results select 'Patent',public.create_patent_record(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','publicationNumber',' RLS source patent ','title','RLS source','sourceDatabase','PATENTSCOPE','sourceUrl','https://example.test/source','relevanceStatus','RELEVANT')) from logged_projects where label='Team';
insert into er_results values('Patent Evidence',public.link_patent_to_evidence(jsonb_build_object('patentRecordId',(select payload->>'id' from er_results where label='Patent'),'evidenceType','PATENT','title','Human reading','description','Source reading')));
insert into er_results values('Activity Evidence',public.add_activity_evidence_output((select id from instances where label='Team'),pg_temp.de_source('UNVERIFIED')));
insert into er_results values('Activity Patent',public.add_activity_research_reference((select id from instances where label='Team'),'PATENT_RECORD',(select (payload->>'id')::uuid from er_results where label='Patent')));
-- Accepted self-verification policy is intentionally preserved: current Team Lead and Personal owner.
select public.verify_evidence(pg_temp.de_source('Extra'),'PARTIALLY_VERIFIED','Current Team Lead explicit review');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.verify_evidence(pg_temp.de_source('Personal'),'VERIFIED','Canonical Personal owner explicit review');
select pg_temp.er_bad(format('select public.verify_evidence(%L,%L)',pg_temp.de_source('UNVERIFIED'),'VERIFIED'));
select pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',pg_temp.er_link('Personal','Decision')));
select pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',pg_temp.er_link('UNVERIFIED','Personal Decision')));
do $$begin
 assert exists(select 1 from public.evidence where id=pg_temp.de_source('UNVERIFIED'));
 assert not exists(select 1 from public.evidence where id=pg_temp.de_source('Other Project')),'same Workspace does not authorize another Project';
 assert exists(select 1 from public.evidence where id=pg_temp.de_source('Personal') and verification_status='VERIFIED' and verified_by=auth.uid());
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',pg_temp.er_link('UNVERIFIED','Other Project Decision')));
select pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',pg_temp.er_link('Other Project','Decision')));
select pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',pg_temp.er_link('Team B','Decision')));
select pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',pg_temp.er_link('UNVERIFIED','Team B Decision')));
-- Both source and target endpoints are independently read-authorized and exact-scope compatible.
do $$begin
 assert not exists(select 1 from public.evidence where id=pg_temp.de_source('Personal')),'Team authority does not expose Personal Evidence';
 assert (select count(*) from public.evidence_links l join public.evidence e on e.id=l.evidence_id where linked_entity_type='DECISION' and linked_entity_id=pg_temp.de_id('Main'))=3;
 assert exists(select 1 from public.evidence where id=pg_temp.de_source('UNVERIFIED') and verification_status='UNVERIFIED' and verified_by is null and verified_at is null);
 assert exists(select 1 from public.evidence where id=pg_temp.de_source('Extra') and verification_status='PARTIALLY_VERIFIED' and verified_by=auth.uid());
end$$;
reset role;
create temporary table er_before as select
 (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,
 (select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l) links,
 (select jsonb_agg(to_jsonb(v) order by id) from public.evidence_verification_history v) verification,
 (select jsonb_agg(to_jsonb(o) order by id) from public.activity_outputs o) outputs,
 (select jsonb_agg(to_jsonb(r) order by id) from public.activity_research_links r) research;
grant select on er_before to authenticated;
set local role authenticated;
do $$declare n integer;k text;bad jsonb;begin
 foreach n in array array[6001,6002,6003,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  assert not exists(select 1 from public.evidence where id=pg_temp.de_source('UNVERIFIED')),'exact Evidence ID is not authority';
  assert not exists(select 1 from public.evidence_links where evidence_id=pg_temp.de_source('UNVERIFIED'));
  assert not exists(select 1 from public.evidence_verification_history where evidence_id=pg_temp.de_source('Extra'));
  assert not exists(select 1 from public.evidence e join public.evidence_links l on l.evidence_id=e.id where e.id=pg_temp.de_source('UNVERIFIED')),'joins do not bypass source ACL';
  assert not exists(select 1 from public.activity_outputs where evidence_id=pg_temp.de_source('UNVERIFIED'));
  assert not exists(select 1 from public.activity_research_links where entity_id=(select (payload->>'id')::uuid from er_results where label='Patent'));
  perform pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',pg_temp.er_link('UNVERIFIED','GAP')));
  perform pg_temp.er_bad(format('select public.verify_evidence(%L,%L)',pg_temp.de_source('UNVERIFIED'),'VERIFIED'));
  perform pg_temp.er_bad(format('select public.add_activity_evidence_output(%L,%L)',(select id from instances where label='Team'),pg_temp.de_source('UNVERIFIED')));
  perform pg_temp.er_bad(format('select public.create_evidence(%L,%L,%L,%L,%L,%L)',(select payload->>'id' from logged_projects where label='Team'),(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'OTHER','Spoofed source','Spoofed description','Spoofed source'));
  foreach k in array array['created_by','verified_by','source_name','project_id','workspace_id','source_url','verification_status','verified_at','captured_at','claim_locator','file_id','description','metadata','archived_at'] loop
   perform pg_temp.er_bad(format('update public.evidence set %I=%I where id=%L',k,k,pg_temp.de_source('UNVERIFIED')));
  end loop;
  perform pg_temp.er_bad(format('delete from public.evidence where id=%L',pg_temp.de_source('UNVERIFIED')));
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 foreach k in array array['createdBy','verifiedBy','verifiedAt','verificationStatus','projectId','workspaceId','actorId'] loop
  bad:=pg_temp.er_link('UNVERIFIED','GAP')||jsonb_build_object(k,'spoof');
  perform pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',bad),'22023');
 end loop;
 perform pg_temp.er_bad(format('select public.verify_evidence(target_evidence=>%L,target_status=>%L,verified_by=>%L)',pg_temp.de_source('UNVERIFIED'),'VERIFIED','00000000-0000-4000-8000-000000006006'),'42883');
 perform pg_temp.er_bad(format('insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name,created_by) values(%L,%L,%L,%L,%L,%L,%L)',(select payload->>'id' from logged_projects where label='Team'),(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'OTHER','Forged','Forged','Forged','00000000-0000-4000-8000-000000006006'));
end$$;
reset role;
-- Compare complete rows, not only counts: linking cannot mutate confidence or provenance.
do $$begin
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e)=(select evidence from er_before);
 assert (select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l)=(select links from er_before);
 assert (select jsonb_agg(to_jsonb(v) order by id) from public.evidence_verification_history v)=(select verification from er_before);
end$$;
-- Demonstrate that table grants alone cannot bypass existing restrictive mutation policies.
grant insert,update,delete on public.evidence,public.evidence_links to authenticated;
set local role authenticated;
do $$declare changed integer;begin
 update public.evidence set source_name='Forged',verified_by=auth.uid(),verified_at=clock_timestamp(),verification_status='VERIFIED' where id=pg_temp.de_source('UNVERIFIED');get diagnostics changed=row_count;assert changed=0;
 update public.evidence_links set notes='Forged' where evidence_id=pg_temp.de_source('UNVERIFIED');get diagnostics changed=row_count;assert changed=0;
 delete from public.evidence where id=pg_temp.de_source('UNVERIFIED');get diagnostics changed=row_count;assert changed=0;
 delete from public.evidence_links where evidence_id=pg_temp.de_source('UNVERIFIED');get diagnostics changed=row_count;assert changed=0;
 perform pg_temp.er_bad(format('insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name) values(%L,%L,%L,%L,%L,%L)',(select payload->>'id' from logged_projects where label='Team'),(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'OTHER','Forged','Forged','Forged'));
 perform pg_temp.er_bad(format('insert into public.evidence_links(evidence_id,linked_entity_type,linked_entity_id,relationship_type) values(%L,%L,%L,%L)',pg_temp.de_source('UNVERIFIED'),'DECISION',pg_temp.de_id('Main'),'RELATED_TO'));
end$$;
reset role;
revoke insert,update,delete on public.evidence,public.evidence_links from authenticated;
-- Archive is a trusted lifecycle fixture, not a new archive operation.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
update public.evidence set archived_at=clock_timestamp() where id=pg_temp.de_source('UNVERIFIED');
select pg_temp.er_bad(format('update public.evidence set source_name=%L where id=%L','Rewritten',pg_temp.de_source('UNVERIFIED')),'55000');
set local role authenticated;
select pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',pg_temp.er_link('UNVERIFIED','GAP','VALIDATES')));
select pg_temp.er_bad(format('select public.verify_evidence(%L,%L)',pg_temp.de_source('UNVERIFIED'),'VERIFIED'));
select public.link_evidence(pg_temp.er_link('UNVERIFIED','GAP'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert not exists(select 1 from public.evidence where id=pg_temp.de_source('UNVERIFIED'));
 assert not exists(select 1 from public.evidence_links where evidence_id=pg_temp.de_source('UNVERIFIED'));
 assert not exists(select 1 from public.evidence_verification_history where evidence_id=pg_temp.de_source('Extra'));
 assert not exists(select 1 from public.activity_outputs where evidence_id=pg_temp.de_source('UNVERIFIED'));
 perform pg_temp.er_bad(format('select public.link_evidence(%L::jsonb)',pg_temp.er_link('UNVERIFIED','GAP')));
 perform pg_temp.er_bad(format('select public.verify_evidence(%L,%L)',pg_temp.de_source('Extra'),'VERIFIED'));
 perform pg_temp.er_bad(format('select public.add_activity_evidence_output(%L,%L)',(select id from instances where label='Team'),pg_temp.de_source('Extra')));
end$$;
-- Remaining authorized member sees historical references and original authorship.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert exists(select 1 from public.evidence where id=pg_temp.de_source('UNVERIFIED') and archived_at is not null and verification_status='UNVERIFIED');
 assert exists(select 1 from public.evidence_links where evidence_id=pg_temp.de_source('UNVERIFIED') and created_by='00000000-0000-4000-8000-000000006005');
 assert exists(select 1 from public.evidence where id=pg_temp.de_source('Personal') and verification_status='VERIFIED');
end$$;
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l)=(select links from er_before),'revocation preserves every link';
 assert (select jsonb_agg(to_jsonb(v) order by id) from public.evidence_verification_history v)=(select verification from er_before),'revocation preserves verifier attribution';
 assert (select jsonb_agg(to_jsonb(o) order by id) from public.activity_outputs o)=(select outputs from er_before);
 assert (select jsonb_agg(to_jsonb(r) order by id) from public.activity_research_links r)=(select research from er_before);
 assert not has_table_privilege('authenticated','public.evidence','INSERT,UPDATE,DELETE,TRUNCATE');
 assert not has_table_privilege('authenticated','public.evidence_links','INSERT,UPDATE,DELETE,TRUNCATE');
 assert not has_function_privilege('anon','public.verify_evidence(uuid,public.evidence_verification_status,text)','execute');
 assert not has_function_privilege('authenticated','private.preserve_evidence_history()','execute');
 assert (select relrowsecurity from pg_class where oid='public.evidence'::regclass);
 assert (select relrowsecurity from pg_class where oid='public.evidence_links'::regclass);
end$$;
set local role anon;
select pg_temp.er_bad('select * from public.evidence');
select pg_temp.er_bad('select * from public.evidence_links');
reset role;
select 'M12.20 Evidence/links exact-ID/joins/Personal/TeamB/role-only/Project/target-ACL/spoof/direct-DML/RPC/verification-policy/archive/history/revocation/Decision/Patent/Activity PASS';
rollback;
