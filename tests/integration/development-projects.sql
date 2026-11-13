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
-- No invented one-Project-per-user or Team rule.
insert into public.development_projects(name,project_type,owner_user_id,primary_workspace_id)
 select 'Second Individual fixture','individual',owner_user_id,primary_workspace_id from public.development_projects where id='00000000-0000-4000-8000-000000007201';
do $$ declare a uuid;b uuid;personal uuid;i integer;begin
 select (payload->>'workspaceId')::uuid into a from acceptance_teams where label='A';
 select (payload->>'workspaceId')::uuid into b from acceptance_teams where label='B';
 select primary_workspace_id into personal from public.development_projects where id='00000000-0000-4000-8000-000000007201';
 assert enum_range(null::public.development_project_type)::text[]=array['individual','team','instructor_case_study'],'project type vocabulary';
 assert enum_range(null::public.development_project_status)::text[]=array['active','paused','completed','archived'],'status vocabulary';
 for i in 1..8 loop
  begin
   if i=1 then update public.development_projects set owner_team_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A') where project_type='individual';
   elsif i=2 then update public.development_projects set owner_user_id=null where project_type='individual';
   elsif i=3 then update public.development_projects set primary_workspace_id=a where project_type='individual';
   elsif i=4 then update public.development_projects set primary_workspace_id=personal where project_type='team';
   elsif i=5 then update public.development_projects set primary_workspace_id=b where project_type='team';
   elsif i=6 then update public.development_projects set owner_user_id='00000000-0000-4000-8000-000000009999' where project_type='individual';
   elsif i=7 then update public.development_projects set current_stage='   ' where project_type='individual';
   else update public.development_projects set confidentiality_level='' where project_type='individual';end if;
   raise exception 'invalid binding accepted: %',i;
  exception when check_violation or foreign_key_violation then null;end;
 end loop;
 begin update public.workspaces set cohort_id=(select id from acceptance_cohorts where label='Unrelated') where id='00000000-0000-4000-8000-000000007101';raise exception 'scope rebinding accepted';exception when check_violation then null;end;
 update public.workspaces set status='archived' where id=personal;
 begin insert into public.development_projects(name,project_type,owner_user_id,primary_workspace_id) values('Invalid archived','individual','00000000-0000-4000-8000-000000006004',personal);raise exception 'archived scope accepted';exception when check_violation then null;end;
 update public.workspaces set status='active' where id=personal;
 update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000006004';
 begin insert into public.development_projects(name,project_type,owner_user_id,primary_workspace_id) values('Invalid owner','individual','00000000-0000-4000-8000-000000006004',personal);raise exception 'inactive owner accepted';exception when check_violation then null;end;
 update public.users set account_status='active' where id='00000000-0000-4000-8000-000000006004';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert exists(select 1 from public.development_projects where id='00000000-0000-4000-8000-000000007201'),'Individual owner access';
 assert exists(select 1 from public.development_projects where id='00000000-0000-4000-8000-000000007202'),'Team member access';
 assert not exists(select 1 from public.development_projects where project_type='instructor_case_study'),'Student Case Study denied';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert exists(select 1 from public.development_projects where id='00000000-0000-4000-8000-000000007203'),'scoped case owner access';end $$;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not public.can_read_development_project('00000000-0000-4000-8000-000000007202'),'removed Team member denied';assert exists(select 1 from public.development_projects where id='00000000-0000-4000-8000-000000007201'),'Personal unaffected';end $$;
do $$ declare who text; begin
 foreach who in array array['6001','6003','6006','6007'] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
  assert (select count(*) from public.development_projects)=0,'Admin/unrelated Master/Team B privacy';
  assert not public.can_read_development_project('00000000-0000-4000-8000-000000007201') and not public.can_read_development_project('00000000-0000-4000-8000-000000009999'),'known and nonexistent IDs both denied';
  begin insert into public.development_projects(name,project_type,owner_user_id,primary_workspace_id) values('Forged','individual','00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000007101');raise exception 'client insert';exception when insufficient_privilege then null;end;
  begin update public.development_projects set owner_user_id=auth.uid();raise exception 'client update';exception when insufficient_privilege then null;end;
  begin delete from public.development_projects;raise exception 'client delete';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
-- Parent eligibility may change historically; current access must fail closed.
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert not public.can_read_development_project('00000000-0000-4000-8000-000000007203'),'ownership alone not Master authorization';end $$;
reset role;
update public.workspaces set status='archived' where id=(select primary_workspace_id from public.development_projects where id='00000000-0000-4000-8000-000000007201');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not public.can_read_development_project('00000000-0000-4000-8000-000000007201'),'archived Workspace read denied';end $$;
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform * from public.development_projects;raise exception 'anonymous read';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert (select relrowsecurity from pg_class where oid='public.development_projects'::regclass),'Project RLS';
 assert (select proconfig=array['search_path=""'] from pg_proc where oid='public.can_read_development_project(uuid)'::regprocedure),'safe definer path';
 assert not has_function_privilege('anon','public.can_read_development_project(uuid)','EXECUTE'),'anonymous helper';
 assert not has_function_privilege('authenticated','public.validate_development_project_binding()','EXECUTE'),'private validator';
 assert to_regclass('public.project_baselines') is null,'no later Development Objects';
 assert (select count(*) from public.development_projects)=4,'history preserved';
end $$;
-- Revalidate trusted creation against invalid current scopes, not only client RLS.
do $$ declare w uuid;t uuid;begin
 begin insert into public.development_projects(name,project_type,owner_user_id,primary_workspace_id) values('Invalid Master scope','instructor_case_study','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000007101');raise exception 'inactive Master scope accepted';exception when check_violation then null;end;
 insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values('CASE_STUDY','Unscoped case','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006001') returning id into w;
 begin insert into public.development_projects(name,project_type,owner_user_id,primary_workspace_id) values('Invalid unscoped case','instructor_case_study','00000000-0000-4000-8000-000000006002',w);raise exception 'unscoped Case Study accepted';exception when check_violation then null;end;
 select (payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid into t,w from acceptance_teams where label='A';
 update public.teams set status='completed' where id=t;
 begin insert into public.development_projects(name,project_type,owner_team_id,primary_workspace_id) values('Invalid completed Team','team',t,w);raise exception 'completed Team accepted';exception when check_violation then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not public.can_read_development_project('00000000-0000-4000-8000-000000007202'),'completed Team denies existing Project access';end $$;
reset role;
rollback;
\echo M6.1 Project schema/ownership/Workspace/RLS security PASS
