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
grant select on acceptance_personal to authenticated;
create temporary table created_projects(label text,payload jsonb);grant select,insert on created_projects to authenticated;
create temporary table creation_history_counts as select (select count(*) from public.audit_events) audits,(select count(*) from public.notifications) notifications;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into created_projects values('Individual',public.create_development_project('My Project','individual',(select id from acceptance_personal where data->>'owner_user_id'='00000000-0000-4000-8000-000000006004')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into created_projects values('Team Master',public.create_development_project('Team Project','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
insert into created_projects values('Case Study',public.create_development_project('Case Project','instructor_case_study','00000000-0000-4000-8000-000000007101',null,'00000000-0000-4000-8000-000000006002'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into created_projects values('Team Admin',public.create_development_project('Admin Team Project','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
reset role;
do $$declare x record;begin
 for x in select * from created_projects loop
  assert exists(select 1 from public.development_projects p where p.id=(x.payload->>'id')::uuid and to_jsonb(p)=x.payload),'canonical persisted Project response';
 end loop;
 assert not exists(select 1 from public.project_memberships),'no automatic participant rows for any Project type';
 assert (select count(*) from public.audit_events)=(select audits from creation_history_counts),'no misuse of Team audit';
 assert (select count(*) from public.notifications)=(select notifications from creation_history_counts),'no notifications invented';
 assert (select count(*) from public.development_projects)=4,'only four creations';
end $$;
-- Ordinary Team member, Lead, Mentor, unrelated Master and unrelated Student
-- cannot create a Team Project or hijack Individual/Case Study ownership.
set local role authenticated;
do $$declare who text;a uuid;b uuid;t uuid;own_a uuid;own_b uuid;begin
 select (payload->>'workspaceId')::uuid,(payload->>'teamId')::uuid into a,t from acceptance_teams where label='A';
 select (payload->>'workspaceId')::uuid into b from acceptance_teams where label='B';
 select id into own_a from acceptance_personal where data->>'owner_user_id'='00000000-0000-4000-8000-000000006004';
 select id into own_b from acceptance_personal where data->>'owner_user_id'='00000000-0000-4000-8000-000000006005';
 foreach who in array array['6004','6005','6008','6003','6006'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  begin perform public.create_development_project('Forged Team','team',a,null,null,t);raise exception 'unauthorized Team creation';exception when insufficient_privilege then null;end;
  begin perform public.create_development_project('Forged owner','individual',own_a,null,'00000000-0000-4000-8000-000000006005');raise exception 'owner spoofing';exception when insufficient_privilege then null;end;
  if who<>'6005' then begin perform public.create_development_project('Forged Workspace','individual',own_b);raise exception 'Workspace hijack';exception when insufficient_privilege then null;end;end if;
  begin perform public.create_development_project('Forged Case','instructor_case_study','00000000-0000-4000-8000-000000007101',null,'00000000-0000-4000-8000-000000006002');raise exception 'Case owner spoof';exception when insufficient_privilege then null;end;
  begin insert into public.development_projects(name,project_type,owner_team_id,primary_workspace_id) values('Client bypass','team',t,a);raise exception 'direct Project insertion';exception when insufficient_privilege then null;end;
  begin insert into public.project_memberships(project_id,user_id) values((select (payload->>'id')::uuid from created_projects where label='Team Master'),auth.uid());raise exception 'membership escalation';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 begin perform public.create_development_project('Cross-Team Workspace','team',b,null,null,t);raise exception 'cross-Team binding';exception when insufficient_privilege then null;end;
 begin perform public.create_development_project('Fake Team','team',a,null,null,'00000000-0000-4000-8000-000000009999');raise exception 'Team spoofing';exception when insufficient_privilege then null;end;
 begin perform public.create_development_project('Personal hijack','individual',own_a,null,'00000000-0000-4000-8000-000000006004');raise exception 'Master personal bypass';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
 begin perform public.create_development_project('Admin personal hijack','individual',own_a,null,'00000000-0000-4000-8000-000000006004');raise exception 'Admin personal bypass';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Remove A1 canonically, then attempt creation with stale Team IDs.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.create_development_project('Removed member','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'));raise exception 'removed creator';exception when insufficient_privilege then null;end;
 assert public.can_read_development_project((select (payload->>'id')::uuid from created_projects where label='Individual')),'Individual owner access needs no membership';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert public.can_read_development_project((select (payload->>'id')::uuid from created_projects where label='Case Study')),'Case owner access needs no membership';assert not public.can_read_development_project((select (payload->>'id')::uuid from created_projects where label='Team Master')),'Team operational creation grants no implicit content participation';end $$;
reset role;
-- Inject failure AFTER insert. The entire RPC statement must roll back its row.
create function public.fixture_fail_project_insert() returns trigger language plpgsql as $$begin if new.name='Rollback Project' then raise exception 'Forced insert failure' using errcode='23514';end if;return new;end $$;
create trigger fixture_project_insert_failure after insert on public.development_projects for each row execute function public.fixture_fail_project_insert();
create temporary table before_failure as select (select count(*) from public.development_projects) projects,(select count(*) from public.project_memberships) members,(select count(*) from public.workspaces) workspaces;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.create_development_project('Rollback Project','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'));raise exception 'forced failure accepted';exception when check_violation then null;end;end $$;
reset role;
do $$begin
 assert (select count(*) from public.development_projects)=(select projects from before_failure),'no orphan Project';
 assert (select count(*) from public.project_memberships)=(select members from before_failure),'no orphan membership';
 assert (select count(*) from public.workspaces)=(select workspaces from before_failure),'no Workspace creation';
 assert (select proconfig=array['search_path=""'] from pg_proc where oid='public.create_development_project(text,public.development_project_type,uuid,text,uuid,uuid)'::regprocedure),'fixed search_path';
 assert not has_function_privilege('anon','public.create_development_project(text,public.development_project_type,uuid,text,uuid,uuid)','EXECUTE'),'anonymous RPC denied';
 assert not has_table_privilege('authenticated','public.development_projects','INSERT,UPDATE,DELETE'),'direct mutation denied';
end $$;
-- An Admin assigned only to another organization has no authority here.
insert into public.organizations(id,name,slug) values('00000000-0000-4000-8000-000000007401','Unrelated test organization','m63-unrelated');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000007401','00000000-0000-4000-8000-000000006001');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$begin begin perform public.create_development_project('Unrelated Admin','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'));raise exception 'unrelated Admin accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
-- Current lifecycle eligibility is required even for an authorized Admin.
update public.teams set status='completed' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
do $$begin begin perform public.create_development_project('Completed Team','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'));raise exception 'completed Team accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
update public.workspaces set status='archived' where id=(select id from acceptance_personal where data->>'owner_user_id'='00000000-0000-4000-8000-000000006004');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.create_development_project('Archived Workspace','individual',(select id from acceptance_personal where data->>'owner_user_id'='00000000-0000-4000-8000-000000006004'));raise exception 'archived Workspace accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
\echo M6.3 authorized Project creation/ownership/membership separation/rollback PASS
