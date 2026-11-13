-- Prepended canonical M8 Project/Workspace fixture. No createEvidence API.
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into public.project_memberships(project_id,user_id)
 select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects p where label='Team'
 and not exists(select 1 from public.project_memberships m where m.project_id=(p.payload->>'id')::uuid and m.user_id='00000000-0000-4000-8000-000000006005' and status='active');
create temporary table el_scope as select label,(payload->>'id')::uuid project_id,(payload->>'primary_workspace_id')::uuid workspace_id from logged_projects where label in ('Team','Individual');
create temporary table el_targets(label text primary key,kind text,id uuid);
create temporary table el_sources(label text primary key,id uuid);
create temporary table el_results(label text,payload jsonb);
grant select on el_scope,el_targets,el_sources to authenticated;
grant select,insert on el_results to authenticated;
with made as(insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name)
 select project_id,workspace_id,'MEASUREMENT','Measured source','Recorded observations','Offline measurement' from el_scope returning id,project_id)
 insert into el_sources select s.label,m.id from made m join el_scope s using(project_id);
-- Real Team B Project and target through existing canonical operations.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('Evidence Team B',public.create_development_project('Evidence Team B','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='B'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='B')));
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006006' from logged_projects where label='Evidence Team B';
insert into el_scope select 'Team B',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid from logged_projects where label='Evidence Team B';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
with made as(insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name)
 select project_id,workspace_id,'OTHER','B source','Private B observations','B named source' from el_scope where label='Team B' returning id)
 insert into el_sources select 'Team B',id from made;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006');
-- Canonical Objects and Artifacts in three independently authorized scopes.
do $$declare s record;actor text;begin
 for s in select * from el_scope loop
  actor:=case when s.label='Team B' then '00000000-0000-4000-8000-000000006006' else '00000000-0000-4000-8000-000000006004' end;
  perform set_config('request.jwt.claim.sub',actor,true);
  insert into el_targets select s.label||' GAP','GAP',(public.create_development_object(s.project_id,s.workspace_id,'GAP','Canonical Gap','Unchanged gap content','User')->>'id')::uuid;
  insert into el_targets select s.label||' REQUIREMENT','REQUIREMENT',(public.create_development_object(s.project_id,s.workspace_id,'REQUIREMENT','Canonical Requirement','Unchanged requirement','User')->>'id')::uuid;
  insert into el_targets select s.label||' ARTIFACT','ARTIFACT',(public.create_artifact(s.project_id,s.workspace_id,'PITCH_DECK_RECORD','Canonical artifact',null,false,false)->>'artifactId')::uuid;
  if s.label='Team' then perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);end if;
  insert into el_targets select s.label||' DECISION','DECISION',(public.create_decision(jsonb_build_object('projectId',s.project_id,'workspaceId',s.workspace_id,'title','Canonical Decision','question','Which approach?','method','OTHER','options','[{"label":"Option"}]'::jsonb))#>>'{decision,id}')::uuid;
 end loop;
end $$;
create function pg_temp.el_args(scope text,kind text,relation text default 'SUPPORTS') returns jsonb language sql as $$
 select jsonb_build_object('evidenceId',s.id,'entityType',$2,'entityId',t.id,'relationshipType',$3,'notes','Supplemental source context') from el_sources s cross join el_targets t where s.label=$1 and t.label=$1||' '||$2
$$;
create function pg_temp.el_bad(input jsonb,expected text default '42501') returns void language plpgsql as $$
begin perform public.link_evidence(input);raise exception 'Unauthorized link succeeded';exception when others then if sqlstate<>expected then raise;end if;end $$;
grant execute on function pg_temp.el_args(text,text,text),pg_temp.el_bad(jsonb,text) to authenticated;
create temporary table el_before as select
 (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e) evidence,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(d) order by id) from public.decisions d) decisions,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v) versions;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into el_results select kind,public.link_evidence(pg_temp.el_args('Team',kind)) from unnest(array['DECISION','REQUIREMENT','GAP','ARTIFACT']) kind;
insert into el_results select 'retry',public.link_evidence(pg_temp.el_args('Team','GAP')||'{"notes":"Retry must not replace notes"}');
insert into el_results select 'distinct relationship',public.link_evidence(pg_temp.el_args('Team','GAP','CONTRADICTS'));
insert into el_results select relation,public.link_evidence(pg_temp.el_args('Team','REQUIREMENT',relation)) from unnest(array['VALIDATES','SOURCE_FOR','RELATED_TO']) relation;
do $$declare t record;begin
 assert (select payload->>'id' from el_results where label='retry')=(select payload->>'id' from el_results where label='GAP');
 assert (select payload->>'notes' from el_results where label='retry')='Supplemental source context';
 assert (select count(*) from public.evidence_links)=8,format('Visible link counts: %s',(select jsonb_object_agg(kind,n) from (select linked_entity_type::text kind,count(*) n from public.evidence_links group by 1) c));
 for t in select * from el_targets where label like 'Individual %' or label like 'Team B %' loop
  perform pg_temp.el_bad(pg_temp.el_args('Team',t.kind)||jsonb_build_object('entityId',t.id));
 end loop;
 perform pg_temp.el_bad(pg_temp.el_args('Team','GAP')||jsonb_build_object('evidenceId',(select id from el_sources where label='Team B')));
 perform pg_temp.el_bad(pg_temp.el_args('Team','GAP')||'{"entityId":"00000000-0000-4000-8000-000000009999"}');
 perform pg_temp.el_bad(pg_temp.el_args('Team','GAP')||'{"entityType":"PATENT_RECORD"}','0A000');
 perform pg_temp.el_bad(pg_temp.el_args('Team','GAP')||'{"entityType":"AI_OUTPUT"}','22P02');
 perform pg_temp.el_bad(pg_temp.el_args('Team','GAP')||'{"relationshipType":"APPROVES"}','22P02');
 perform pg_temp.el_bad(pg_temp.el_args('Team','GAP')||'{"createdBy":"00000000-0000-4000-8000-000000006005"}','22023');
 perform pg_temp.el_bad(pg_temp.el_args('Team','GAP')||'{"notes":null}','22023');
 perform pg_temp.el_bad(pg_temp.el_args('Team','GAP')||jsonb_build_object('entityId',(select (payload->>'id')::uuid from logged_objects where label='Team')));
end $$;
-- Exact IDs, source and target joins, and normal client mutation attacks.
do $$declare n int;begin
 foreach n in array array[6007,6002,6003,6001,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  assert not exists(select 1 from public.evidence_links);
  assert not exists(select 1 from public.evidence_links l join public.evidence e on e.id=l.evidence_id);
  assert not exists(select 1 from public.evidence_links l join public.decisions d on d.id=l.linked_entity_id);
  assert not exists(select 1 from public.evidence_links l join public.development_objects o on o.id=l.linked_entity_id);
  assert not exists(select 1 from public.evidence_links l join public.artifacts a on a.id=l.linked_entity_id);
  assert not exists(select 1 from public.evidence_links where id=(select (payload->>'id')::uuid from el_results where label='GAP'));
  perform pg_temp.el_bad(pg_temp.el_args('Team','GAP'));
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin insert into public.evidence_links(evidence_id,linked_entity_type,linked_entity_id,relationship_type) select s.id,'GAP',t.id,'SUPPORTS' from el_sources s,el_targets t where s.label='Team' and t.label='Team GAP';raise exception 'Client INSERT';exception when insufficient_privilege then null;end;
 begin update public.evidence_links set linked_entity_id='00000000-0000-4000-8000-000000009999';raise exception 'Client UPDATE';exception when insufficient_privilege then null;end;
 begin update public.evidence_links set archived_at=now();raise exception 'Client archive';exception when insufficient_privilege then null;end;
 begin delete from public.evidence_links;raise exception 'Client DELETE';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Targets, verification fields, authorship, Version bodies and history unchanged.
create function pg_temp.el_forced_failure() returns trigger language plpgsql as $$begin raise exception 'Forced link failure' using errcode='23514';end $$;
create trigger el_forced_failure before insert on public.evidence_links for each row execute function pg_temp.el_forced_failure();
set local role authenticated;
select pg_temp.el_bad(pg_temp.el_args('Team','GAP','RELATED_TO'),'23514');
reset role;
drop trigger el_forced_failure on public.evidence_links;
do $$begin
 assert (select count(*) from public.evidence_links)=8,'failed insertion leaves no link';
 assert (select evidence from el_before)=(select jsonb_agg(to_jsonb(e) order by id) from public.evidence e);
 assert (select objects from el_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
 assert (select decisions from el_before)=(select jsonb_agg(to_jsonb(d) order by id) from public.decisions d);
 assert (select artifacts from el_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select versions from el_before)=(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v);
 begin delete from public.evidence_links;raise exception 'History deleted';exception when object_not_in_prerequisite_state then null;end;
 begin update public.evidence_links set notes='rewritten';raise exception 'History rewritten';exception when check_violation then null;end;
 assert exists(select 1 from pg_class where oid='public.evidence_links'::regclass and relrowsecurity);
 assert not has_table_privilege('authenticated','public.evidence_links','INSERT');
 assert not has_function_privilege('anon','public.link_evidence(jsonb)','EXECUTE');
 assert not has_function_privilege('service_role','public.link_evidence(jsonb)','EXECUTE');
 assert not has_function_privilege('authenticated','private.preserve_evidence_link()','EXECUTE');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.link_evidence(jsonb)'::regprocedure);
 assert to_regclass('public.patent_records') is not null,'M12.11 Patent Record schema now exists';
 assert has_function_privilege('authenticated','public.create_patent_record(jsonb)','execute'),'M12.12 owns narrow Patent creation';
 assert has_function_privilege('authenticated','public.link_patent_to_evidence(jsonb)','execute'),'M12.14 owns the explicit atomic Patent provenance operation';
 assert not has_function_privilege('anon','public.link_patent_to_evidence(jsonb)','execute');
 assert not exists(select 1 from pg_constraint where conrelid='public.evidence_links'::regclass and confrelid='public.patent_records'::regclass),'Polymorphic target uses exact-scope validation, not an invalid universal FK';
end $$;
-- Archived target: no new link, canonical existing retry remains read-only.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
update public.development_objects set archived_at=now() where id=(select id from el_targets where label='Team GAP');
set local role authenticated;
select pg_temp.el_bad(pg_temp.el_args('Team','GAP','VALIDATES'));
select public.link_evidence(pg_temp.el_args('Team','GAP'));
reset role;
select 'EVIDENCE_LINK_ROW='||payload::text from el_results where label='GAP';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.evidence_links);perform pg_temp.el_bad(pg_temp.el_args('Team','GAP'));end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert (select count(*) from public.evidence_links)=8;end $$;
reset role;
do $$begin assert (select count(*) from public.evidence_links)=8;end $$;
set local role anon;
do $$begin begin perform 1 from public.evidence_links;raise exception 'Anonymous read';exception when insufficient_privilege then null;end;end $$;
reset role;
select 'M12.2 Evidence links scope/privacy/history/targets/independence PASS';
rollback;
