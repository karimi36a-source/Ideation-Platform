\set ON_ERROR_STOP on
begin;
-- Deterministic identities: Admin, assigned/unrelated Masters, A1/A2/B1/B2,
-- plus Mentor for negative authority regression. Resources use canonical RPC IDs.
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'team-acceptance-'||n||'@example.test' from generate_series(6001,6008) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'team-acceptance-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('00000000-0000-4000-8000-'||lpad((case when n=6001 then 101 when n=6008 then 103 else 104 end)::text,12,'0'))::uuid,
 '00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000006001'
 from generate_series(6001,6008) n where n not in (6002,6003);
create temporary table acceptance_cohorts(label text primary key,id uuid);grant select,insert on acceptance_cohorts to authenticated;
create temporary table acceptance_teams(label text primary key,payload jsonb);grant select,insert on acceptance_teams to authenticated;
create temporary table acceptance_messages(label text primary key,payload jsonb);grant select,insert on acceptance_messages to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into acceptance_cohorts values('Test',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Professional Course Test Cohort','2026-10-01',null,'00000000-0000-4000-8000-000000006002','active','{}')->>'id')::uuid);
insert into acceptance_cohorts values('Unrelated',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Unrelated acceptance cohort','2026-10-01',null,'00000000-0000-4000-8000-000000006003','active','{}')->>'id')::uuid);
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
 select c.id,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'participant','active' from acceptance_cohorts c cross join generate_series(6004,6008) n where c.label='Test';
-- Canonical Personal provisioning, retained unchanged through all Team operations.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select public.create_personal_workspace();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);select public.create_personal_workspace();
create temporary table acceptance_personal as select id,to_jsonb(w) data from public.workspaces w where workspace_type='PERSONAL' and owner_user_id in ('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into acceptance_teams values('A',public.create_team((select id from acceptance_cohorts where label='Test'),'Team A'));
insert into acceptance_teams values('B',public.create_team((select id from acceptance_cohorts where label='Test'),'Team B'));

select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005','team_lead');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006008','mentor');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007','member');

reset role;
insert into public.workspaces(id,workspace_type,name,owner_user_id,cohort_id,created_by,updated_by)
 values('00000000-0000-4000-8000-000000007101','CASE_STUDY','Case Study fixture','00000000-0000-4000-8000-000000006002',(select id from acceptance_cohorts where label='Test'),'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006001');
insert into public.development_projects(id,name,project_type,owner_user_id,primary_workspace_id)
 values('00000000-0000-4000-8000-000000007201','Individual fixture','individual','00000000-0000-4000-8000-000000006004',(select id from public.workspaces where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000006004')),
 ('00000000-0000-4000-8000-000000007203','Case Study fixture','instructor_case_study','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000007101');
insert into public.development_projects(id,name,project_type,owner_team_id,primary_workspace_id)
 select '00000000-0000-4000-8000-000000007202','Team fixture','team',(payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid from acceptance_teams where label='A';
insert into public.project_memberships(project_id,user_id) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006004'),('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006005');

create temporary table logged_projects(label text primary key,payload jsonb);grant select,insert on logged_projects to authenticated;
create temporary table logged_objects(label text primary key,payload jsonb);grant select,insert on logged_objects to authenticated;
create temporary table logged_edges(label text primary key,payload jsonb);grant select,insert on logged_edges to authenticated;
create temporary table membership_baseline as select count(*) n from public.project_memberships;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into logged_projects values('Individual',public.create_development_project('Logged Individual','individual',(select id from public.workspaces where workspace_type='PERSONAL')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('Team',public.create_development_project('Logged Team','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
-- Admin creation needs no automatic Project Membership to produce trusted history.
reset role;
do $$begin
 assert (select count(*) from public.project_memberships)=(select n from membership_baseline),'no membership merely for logging';
 assert exists(select 1 from public.change_log where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') and changed_by='00000000-0000-4000-8000-000000006001' and change_type='PROJECT_CREATED'),'Admin Project creation verified actor';
end $$;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006004' from logged_projects where label='Team';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into logged_projects values('Case',public.create_development_project('Logged Case','instructor_case_study','00000000-0000-4000-8000-000000007101',null,'00000000-0000-4000-8000-000000006002'));
insert into logged_objects values('Case',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Case'),'00000000-0000-4000-8000-000000007101','PROBLEM','Case','Content',null));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into logged_objects values('Problem',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select id from public.workspaces where workspace_type='PERSONAL'),'PROBLEM','Problem','Private content never copied','User','{"private":"blob"}')),
 ('Solution',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select id from public.workspaces where workspace_type='PERSONAL'),'SOLUTION','Solution','Content','User')),
 ('Team',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),'PROBLEM','Problem','Content','User'));
select public.update_project_metadata((select (payload->>'id')::uuid from logged_projects where label='Individual'),'{"name":"Renamed"}');
select public.update_project_metadata((select (payload->>'id')::uuid from logged_projects where label='Individual'),'{"current_stage":"Prototype validation"}');
select public.update_project_metadata((select (payload->>'id')::uuid from logged_projects where label='Individual'),'{"status":"paused"}');
select public.update_project_metadata((select (payload->>'id')::uuid from logged_projects where label='Individual'),'{"status":"active"}');
do $$declare p uuid;before integer;begin
 select (payload->>'id')::uuid into p from logged_projects where label='Individual';
 assert (select count(*) from public.change_log where project_id=p and change_type='PROJECT_METADATA_UPDATED')=1,'rename event';
 assert (select count(*) from public.change_log where project_id=p and change_type='PROJECT_STAGE_CHANGED')=1,'stage event';
 assert (select count(*) from public.change_log where project_id=p and change_type='PROJECT_STATUS_CHANGED')=2,'status events';
 select count(*) into before from public.change_log;
 perform public.update_project_metadata(p,'{"name":"Renamed","current_stage":"Prototype validation","status":"active"}');assert (select count(*) from public.change_log)=before,'metadata no-op';
 perform public.update_project_metadata(p,'{"description":"Changed","current_stage":"Field validation","status":"paused"}');
 perform public.update_project_metadata(p,'{"status":"active"}');
 assert (select count(*) from public.change_log)=before+4,'three changed categories plus resume';
end $$;
select public.update_development_object((select (payload->>'id')::uuid from logged_objects where label='Problem'),'{"content":"Changed private content","metadata":{"private":"replacement"}}');
insert into logged_edges values('Unlink',public.relate_development_objects((select (payload->>'id')::uuid from logged_objects where label='Solution'),(select (payload->>'id')::uuid from logged_objects where label='Problem'),'SOLVES'));
insert into logged_edges values('Active',public.relate_development_objects((select (payload->>'id')::uuid from logged_objects where label='Problem'),(select (payload->>'id')::uuid from logged_objects where label='Solution'),'SUPPORTS'));

select public.unlink_development_objects((select (payload->>'id')::uuid from logged_edges where label='Unlink'));
select public.archive_development_object((select (payload->>'id')::uuid from logged_objects where label='Solution'));
do $$declare before integer;obj jsonb;begin
 assert exists(select 1 from public.change_log where entity_id=(select (payload->>'id')::uuid from logged_objects where label='Problem') and change_type='OBJECT_CREATED' and changed_by=auth.uid()),'Object creation event/actor';
 assert exists(select 1 from public.change_log where entity_id=(select (payload->>'id')::uuid from logged_edges where label='Unlink') and change_type='RELATIONSHIP_CREATED' and changed_by=auth.uid()),'Relationship creation event/actor';
 assert (select count(distinct change_type) from public.change_log)=9,'all nine implemented event types';
 assert exists(select 1 from public.change_log where entity_id=(select (payload->>'id')::uuid from logged_objects where label='Problem') and change_type='OBJECT_UPDATED' and changed_by=auth.uid()),'Object update event/actor';
 assert exists(select 1 from public.change_log where entity_id=(select (payload->>'id')::uuid from logged_objects where label='Solution') and change_type='OBJECT_ARCHIVED'),'archive event history authorized';
 assert exists(select 1 from public.change_log where entity_id=(select (payload->>'id')::uuid from logged_edges where label='Unlink') and change_type='RELATIONSHIP_ARCHIVED'),'unlink event';
 select count(*) into before from public.change_log;
 select to_jsonb(o) into obj from public.development_objects o where id=(select (payload->>'id')::uuid from logged_objects where label='Problem');
 assert public.update_development_object((obj->>'id')::uuid,'{"content":"Changed private content","metadata":{"private":"replacement"}}')=obj,'Object no-op preserves timestamps';
 perform public.archive_development_object((select (payload->>'id')::uuid from logged_objects where label='Solution'));
 perform public.unlink_development_objects((select (payload->>'id')::uuid from logged_edges where label='Unlink'));
 assert (select count(*) from public.change_log)=before,'Object/archive/unlink no duplicate log';
 begin perform public.update_development_object((obj->>'id')::uuid,'{"created_by":"fake"}');raise exception 'forged Object mutation';exception when invalid_parameter_value then null;end;
 begin perform public.relate_development_objects((select (payload->>'id')::uuid from logged_objects where label='Solution'),(obj->>'id')::uuid,'SOLVES');raise exception 'archived endpoint';exception when invalid_parameter_value then null;end;
 assert (select count(*) from public.change_log)=before,'failed business mutation produces no log';
end $$;
do $$declare who text;begin
 foreach who in array array['6001','6003','6006','6007','6008'] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
 assert not exists(select 1 from public.change_log),'Admin/unrelated Master/Student/Team B denied';
 assert not exists(select 1 from public.change_log where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team')),'known Project log lookup denied';
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) values((select (payload->>'id')::uuid from logged_projects where label='Individual'),'PROJECT',(select (payload->>'id')::uuid from logged_projects where label='Individual'),'PROJECT_CREATED','Forged','00000000-0000-4000-8000-000000006004');raise exception 'client changed_by spoof';exception when insufficient_privilege then null;end;
 begin update public.change_log set changed_by=auth.uid();raise exception 'client history update';exception when insufficient_privilege then null;end;
 begin delete from public.change_log;raise exception 'client history delete';exception when insufficient_privilege then null;end;
 begin perform public.append_project_change((select (payload->>'id')::uuid from logged_projects where label='Individual'),'PROJECT',(select (payload->>'id')::uuid from logged_projects where label='Individual'),'PROJECT_CREATED');raise exception 'generic writer reachable';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.change_log where project_id=(select (payload->>'id')::uuid from logged_projects where label='Team')),'removed member/stale Project Membership log denied';end $$;
reset role;
do $$declare p uuid;obj uuid;begin
 select (payload->>'id')::uuid into p from logged_projects where label='Case';select (payload->>'id')::uuid into obj from logged_objects where label='Problem';
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) values(p,'DEVELOPMENT_OBJECT',obj,'OBJECT_UPDATED','Forged','00000000-0000-4000-8000-000000006004');raise exception 'cross Project entity';exception when check_violation then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) values(p,'PROJECT',(select (payload->>'id')::uuid from logged_projects where label='Individual'),'PROJECT_CREATED','Forged','00000000-0000-4000-8000-000000006004');raise exception 'cross Project identity';exception when check_violation then null;end;
 begin update public.change_log set change_summary='Rewrite';raise exception 'append-only update';exception when check_violation then null;end;
 begin delete from public.change_log;raise exception 'append-only delete';exception when check_violation then null;end;
 assert not exists(select 1 from public.change_log where change_summary like '%private%' or change_summary like '%replacement%' or change_summary like '%blob%'),'fixed non-sensitive summaries';
 assert not exists(select 1 from public.change_log where previous_version_id is not null or new_version_id is not null or related_decision_id is not null or related_evidence_id is not null or related_ai_output_id is not null),'no fake version/related IDs';
 assert not exists(select 1 from public.change_log where change_type='PROJECT_ARCHIVED'),'no M6.11 operation';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into logged_objects values('Rollback target',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select id from public.workspaces where workspace_type='PERSONAL'),'IDEA','Rollback target','Content',null));
reset role;
-- Reject log insert after the business mutation. Every RPC must roll both back.
create function public.fixture_log_failure() returns trigger language plpgsql set search_path='' as $$begin raise exception 'Fixture log failure' using errcode='23514';end $$;
create trigger fixture_log_failure after insert on public.change_log for each row execute function public.fixture_log_failure();
create temporary table rollback_snapshot as select
 (select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p) projects,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(e) order by id) from public.development_object_relationships e) edges,
 (select jsonb_agg(to_jsonb(l) order by id) from public.change_log l) logs;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare p uuid;w uuid;o uuid;edge uuid;i integer;begin
 select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid into p,w from logged_projects where label='Individual';
 select (payload->>'id')::uuid into o from logged_objects where label='Problem';select (payload->>'id')::uuid into edge from logged_edges where label='Active';
 for i in 1..7 loop begin
 if i=1 then perform public.create_development_project('Rollback Project','individual',w);
 elsif i=2 then perform public.update_project_metadata(p,'{"name":"Rollback","current_stage":"Rollback","status":"completed"}');
 elsif i=3 then perform public.create_development_object(p,w,'IDEA','Rollback','Content',null);
 elsif i=4 then perform public.update_development_object(o,'{"content":"Rollback"}');
 elsif i=5 then perform public.archive_development_object(o);
 elsif i=6 then perform public.relate_development_objects(o,(select (payload->>'id')::uuid from logged_objects where label='Rollback target'),'IMPLEMENTS');
 else perform public.unlink_development_objects(edge);end if;
 raise exception 'no log failure %',i;exception when check_violation then null;end;end loop;
end $$;
reset role;
do $$begin
 assert (select projects from rollback_snapshot)=(select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p),'Project creation/metadata rollback';
 assert (select objects from rollback_snapshot)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),'Object create/update/archive rollback';
 assert (select edges from rollback_snapshot)=(select jsonb_agg(to_jsonb(e) order by id) from public.development_object_relationships e),'Relationship create/unlink rollback';
 assert (select logs from rollback_snapshot)=(select jsonb_agg(to_jsonb(l) order by id) from public.change_log l),'no orphan logs';
end $$;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform * from public.change_log;raise exception 'anon logs';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert (select relrowsecurity from pg_class where oid='public.change_log'::regclass),'Change Log RLS';
 assert not has_table_privilege('authenticated','public.change_log','INSERT,UPDATE,DELETE'),'client mutation grants denied';
 assert not has_function_privilege('authenticated','public.append_project_change(uuid,public.project_change_entity_type,uuid,public.project_change_type,text)','EXECUTE'),'private writer';
 assert (select proconfig=array['search_path=""'] from pg_proc where oid='public.append_project_change(uuid,public.project_change_entity_type,uuid,public.project_change_type,text)'::regprocedure),'safe definer path';
 assert not exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey) where c.conrelid='public.change_log'::regclass and c.contype='f' and a.attname in ('previous_version_id','new_version_id','related_decision_id','related_evidence_id','related_ai_output_id')),'future FKs deferred';
end $$;
rollback;
\echo M6.10 append-only Change Log/business integration/privacy/no-op/atomic rollback PASS
