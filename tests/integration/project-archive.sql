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

-- Keep real currently supported typed details, links and edges for snapshot comparison.
select public.write_problem_details((select (payload->>'id')::uuid from logged_objects where label='Problem'),'{}',true);
insert into logged_objects values('Idea',public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select id from public.workspaces where workspace_type='PERSONAL'),'IDEA','Idea','Content','User'));
select public.write_idea_details((select (payload->>'id')::uuid from logged_objects where label='Idea'),'{"acceptance_state":"private"}',true);
insert into logged_edges values('Active',public.relate_development_objects((select (payload->>'id')::uuid from logged_objects where label='Solution'),(select (payload->>'id')::uuid from logged_objects where label='Problem'),'SOLVES'));
select public.link_project_to_program((select (payload->>'id')::uuid from logged_projects where label='Individual'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));
reset role;
create temporary table preserved(table_name text primary key,rows jsonb);
do $$declare n text;v jsonb;begin
 foreach n in array array['project_memberships','project_program_links','development_objects','problem_details','idea_details','development_object_relationships','teams','workspaces'] loop
 execute format('select jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text) from public.%I x',n) into v;
 insert into preserved values(n,v);
 end loop;
end $$;
create temporary table prior_logs as select * from public.change_log;
create temporary table archived(label text primary key,payload jsonb);grant select,insert on archived to authenticated;
-- Archival handles completed/paused Projects without reopening them.
insert into public.development_projects(id,name,project_type,owner_user_id,primary_workspace_id,status)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Lifecycle archive fixture','individual','00000000-0000-4000-8000-000000006004',
 (select id from public.workspaces where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000006004'),
 (case when n=7301 then 'paused' else 'completed' end)::public.development_project_status from generate_series(7301,7302) n;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.archive_development_project(('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid) from generate_series(7301,7302) n;
do $$begin
 begin perform public.archive_development_project('00000000-0000-4000-8000-000000009999');raise exception 'unknown Project archive';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.change_log where project_id='00000000-0000-4000-8000-000000009999'),'failed archive no orphan';
end $$;
reset role;
-- Exact forbidden actor matrix before archive; even legitimate members/Team Leads cannot archive.
set local role authenticated;
do $$declare n integer;label0 text;begin
 foreach n in array array[6003,6004,6005,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
 foreach label0 in array array['Team','Case'] loop
 begin perform public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label=label0));raise exception 'unauthorized archive';exception when insufficient_privilege then null;end;
 end loop;
 if n<>6004 then begin perform public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Individual'));raise exception 'private owner archive';exception when insufficient_privilege then null;end;end if;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
do $$begin begin perform public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Individual'));raise exception 'Admin private archive';exception when insufficient_privilege then null;end;end $$;
-- Rollback injected log failure, verified before a successful archive.
reset role;
create function pg_temp.fail_archive_log() returns trigger language plpgsql as $$begin if new.change_type='PROJECT_ARCHIVED' then raise exception 'forced archive log failure' using errcode='23514';end if;return new;end $$;
create trigger force_archive_failure after insert on public.change_log for each row execute function pg_temp.fail_archive_log();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Individual'));raise exception 'expected rollback';exception when check_violation then null;end;end $$;
reset role;
do $$begin assert (select status='active' and archived_at is null from public.development_projects where id=(select (payload->>'id')::uuid from logged_projects where label='Individual')),'archive rolled back';assert not exists(select 1 from public.change_log where change_type='PROJECT_ARCHIVED' and project_id in(select (payload->>'id')::uuid from logged_projects)),'no orphan history';end $$;
drop trigger force_archive_failure on public.change_log;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into archived values('Individual',public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Individual')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into archived values('Case',public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Case'))),('Team',public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Team')));
-- Revoked/expired/future assignment cannot authorize retries or new archives.
reset role;
savepoint master_validity;
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002';
set local role authenticated;
do $$begin begin perform public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Case'));raise exception 'inactive role archive';exception when insufficient_privilege then null;end;end $$;
reset role;rollback to master_validity;
savepoint master_expired;
update public.role_assignments set ends_at=statement_timestamp() where user_id='00000000-0000-4000-8000-000000006002';
set local role authenticated;
do $$begin begin perform public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Team'));raise exception 'expired role archive';exception when insufficient_privilege then null;end;end $$;
reset role;rollback to master_expired;
savepoint master_future;
update public.role_assignments set starts_at=statement_timestamp()+interval '1 day' where user_id='00000000-0000-4000-8000-000000006002';
set local role authenticated;
do $$begin begin perform public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Team'));raise exception 'future role archive';exception when insufficient_privilege then null;end;end $$;
reset role;rollback to master_future;
set local role authenticated;
-- Master retries reauthorize and preserve canonical timestamp.
do $$begin assert public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Team'))=(select payload from archived where label='Team'),'Master retry';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
do $$begin assert public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Team'))=(select payload from archived where label='Team'),'exact organization Admin archive retry';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare p uuid;w uuid;a uuid;b uuid;begin
 select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid into p,w from logged_projects where label='Individual';
 select (payload->>'id')::uuid into a from logged_objects where label='Problem';select (payload->>'id')::uuid into b from logged_objects where label='Solution';
 assert public.archive_development_project(p)=(select payload from archived where label='Individual'),'owner idempotency';
 begin perform public.update_project_metadata(p,'{"name":"No"}');raise exception 'metadata archive bypass';exception when insufficient_privilege then null;end;
 begin perform public.create_development_object(p,w,'PROBLEM','No','No','User');raise exception 'object create bypass';exception when insufficient_privilege then null;end;
 begin perform public.update_development_object(a,'{"title":"No"}');raise exception 'object update bypass';exception when insufficient_privilege then null;end;
 begin perform public.archive_development_object(a);raise exception 'object archive bypass';exception when insufficient_privilege then null;end;
 begin perform public.relate_development_objects(a,b,'SUPPORTS');raise exception 'relation bypass';exception when insufficient_privilege then null;end;
 begin perform public.unlink_development_objects((select (payload->>'id')::uuid from logged_edges where label='Active'));raise exception 'unlink bypass';exception when insufficient_privilege then null;end;
 begin perform public.write_problem_details(a,'{}',false);raise exception 'typed write bypass';exception when insufficient_privilege then null;end;
 begin perform public.link_project_to_program(p,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));raise exception 'program link bypass';exception when insufficient_privilege then null;end;
end $$;
-- Real-ID enumeration, direct lifecycle forgery/restore/delete and forged log.
do $$declare n integer;begin
 foreach n in array array[6001,6002,6003,6004,6005,6006,6008] loop
 perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
 assert not exists(select 1 from public.development_projects where id in(select (payload->>'id')::uuid from logged_projects)),'archived project RLS denied';
 assert not exists(select 1 from public.development_objects where id in(select (payload->>'id')::uuid from logged_objects)),'known Object RLS denied';
 assert not exists(select 1 from public.change_log where project_id in(select (payload->>'id')::uuid from logged_projects)),'archived log privacy';
 begin update public.development_projects set status='active',archived_at=null;raise exception 'restore bypass';exception when insufficient_privilege then null;end;
 begin update public.development_projects set status='archived',archived_at=now();raise exception 'direct archive';exception when insufficient_privilege then null;end;
 begin delete from public.development_projects;raise exception 'delete bypass';exception when insufficient_privilege then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) select (payload->>'id')::uuid,'PROJECT',(payload->>'id')::uuid,'PROJECT_ARCHIVED','Fake',auth.uid() from logged_projects;raise exception 'forged history';exception when insufficient_privilege then null;end;
 end loop;
end $$;
-- Removed user with stale Project Membership cannot archive or recover access.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.archive_development_project((select (payload->>'id')::uuid from logged_projects where label='Team'));raise exception 'stale membership';exception when insufficient_privilege then null;end;end $$;
reset role;
-- Removal closes only Team/Chat memberships; archived Project dependencies stay identical.
do $$declare n text;v jsonb;begin
 foreach n in array array['project_memberships','project_program_links','development_objects','problem_details','idea_details','development_object_relationships','teams','workspaces'] loop
 execute format('select jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text) from public.%I x',n) into v;
 assert v is not distinct from (select rows from preserved where table_name=n),'preserved '||n;
 end loop;
 assert not exists(select 1 from prior_logs l where not exists(select 1 from public.change_log x where to_jsonb(x)=to_jsonb(l))),'prior Change Log unchanged';
 assert (select count(*) from public.change_log where change_type='PROJECT_ARCHIVED' and project_id in(select (payload->>'id')::uuid from logged_projects))=3,'one archive per Project';
 assert exists(select 1 from public.change_log where project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual') and changed_by='00000000-0000-4000-8000-000000006004' and change_type='PROJECT_ARCHIVED'),'verified owner actor';
 assert not exists(select 1 from archived a join logged_projects b using(label) where a.payload->>'id'<>b.payload->>'id' or a.payload->>'owner_user_id' is distinct from b.payload->>'owner_user_id' or a.payload->>'primary_workspace_id'<>b.payload->>'primary_workspace_id' or a.payload->>'status'<>'archived' or a.payload->>'archived_at' is null),'canonical stable binding';
end $$;
set local role anon;select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform public.archive_development_project('00000000-0000-4000-8000-000000007201');raise exception 'anon archive';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert (select proconfig=array['search_path=""'] and prosecdef from pg_proc where oid='public.archive_development_project(uuid)'::regprocedure),'fixed definer path';
 assert not has_function_privilege('anon','public.archive_development_project(uuid)','EXECUTE'),'anonymous denied';
 assert not has_function_privilege('service_role','public.archive_development_project(uuid)','EXECUTE'),'no unbound service invocation';
 assert not has_function_privilege('authenticated','public.append_project_change(uuid,public.project_change_entity_type,uuid,public.project_change_type,text)','EXECUTE'),'private internals unavailable';
end $$;
rollback;
\echo M6.11 archive authorization/history/privacy/idempotency/rollback PASS
