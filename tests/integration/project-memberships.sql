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
-- Team membership alone no longer authorizes Project participation.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not public.can_read_development_project('00000000-0000-4000-8000-000000007202'),'Team membership alone denied';assert public.can_read_development_project('00000000-0000-4000-8000-000000007201'),'Individual owner without participant';end $$;
reset role;
insert into public.project_memberships(id,project_id,user_id,starts_at)
 values('00000000-0000-4000-8000-000000007301','00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006004',now()-interval '1 day');
-- Trusted fixtures deliberately include an ineligible Team B participant. Their
-- Project record alone must not weaken the current Team authorization boundary.
insert into public.project_memberships(project_id,user_id) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006006'),('00000000-0000-4000-8000-000000007201','00000000-0000-4000-8000-000000006006'),('00000000-0000-4000-8000-000000007203','00000000-0000-4000-8000-000000006006');
do $$begin
 assert enum_range(null::public.project_membership_role)::text[]=array['participant'],'single participation role';
 assert enum_range(null::public.project_membership_status)::text[]=array['active','inactive'],'exact statuses';
 begin insert into public.project_memberships(project_id,user_id) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006004');raise exception 'overlapping active accepted';exception when exclusion_violation then null;end;
 begin insert into public.project_memberships(project_id,user_id,starts_at,ends_at) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006005',now(),now()-interval '1 day');raise exception 'invalid interval';exception when check_violation then null;end;
 begin insert into public.project_memberships(project_id,user_id,status) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006005','inactive');raise exception 'inactive missing end';exception when check_violation then null;end;
 begin insert into public.project_memberships(project_id,user_id) values('00000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000006005');raise exception 'bad Project FK';exception when foreign_key_violation then null;end;
 begin insert into public.project_memberships(project_id,user_id) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000009999');raise exception 'bad user FK';exception when foreign_key_violation then null;end;
 begin insert into public.project_memberships(project_id,user_id,project_role) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006005','admin');raise exception 'authority role';exception when invalid_text_representation then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert public.has_active_project_membership('00000000-0000-4000-8000-000000007202') and public.can_read_development_project('00000000-0000-4000-8000-000000007202'),'both memberships allow intended Project';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin assert public.has_active_project_membership('00000000-0000-4000-8000-000000007202'),'fixture explicit membership';assert (select count(*) from public.development_projects)=0,'forged/stale Project scope cannot bypass Team/Individual/Case Study';end $$;
reset role;
-- Exercise scheduled, expired, inactive, and re-entry periods for a valid A2 Team member.
insert into public.project_memberships(id,project_id,user_id,starts_at) values('00000000-0000-4000-8000-000000007302','00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006005',now()+interval '1 day');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not public.can_read_development_project('00000000-0000-4000-8000-000000007202'),'future denies';end $$;
reset role;
-- End the scheduled interval without changing its immutable start.
update public.project_memberships set status='inactive',ends_at=starts_at where id='00000000-0000-4000-8000-000000007302';
insert into public.project_memberships(id,project_id,user_id,starts_at,ends_at) values('00000000-0000-4000-8000-000000007303','00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006005',now()-interval '2 days',now()-interval '1 day');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not public.has_active_project_membership('00000000-0000-4000-8000-000000007202') and not public.can_read_development_project('00000000-0000-4000-8000-000000007202'),'expired/inactive deny';end $$;
reset role;
insert into public.project_memberships(id,project_id,user_id) values('00000000-0000-4000-8000-000000007304','00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006005');
create temporary table membership_history_before as select id,to_jsonb(m) data from public.project_memberships m;
do $$declare x uuid;begin
 foreach x in array array['00000000-0000-4000-8000-000000007302'::uuid,'00000000-0000-4000-8000-000000007303'::uuid] loop
  begin update public.project_memberships set ends_at=null,status='active' where id=x;raise exception 'reactivated history';exception when check_violation then null;end;
 end loop;
 begin delete from public.project_memberships;raise exception 'deleted history';exception when check_violation then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert public.can_read_development_project('00000000-0000-4000-8000-000000007202'),'new re-entry record authorizes';end $$;
do $$declare operation text;begin
 foreach operation in array array[
 'insert into public.project_memberships(project_id,user_id) values(''00000000-0000-4000-8000-000000007202'',''00000000-0000-4000-8000-000000006007'')',
 'update public.project_memberships set project_role=''participant''',
 'update public.project_memberships set status=''active'',ends_at=null,starts_at=now()-interval ''1 day''',
 'delete from public.project_memberships'] loop
  begin execute operation;raise exception 'direct client membership mutation';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert public.can_read_development_project('00000000-0000-4000-8000-000000007203'),'authorized Case Study owner needs no membership';end $$;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert public.has_active_project_membership('00000000-0000-4000-8000-000000007202'),'stale row preserved';assert not public.can_read_development_project('00000000-0000-4000-8000-000000007202'),'Team removal overrides stale Project membership';assert public.can_read_development_project('00000000-0000-4000-8000-000000007201'),'Individual privacy/access unchanged';end $$;
reset role;
do $$begin
 assert not exists(select 1 from membership_history_before b join public.project_memberships m using(id) where b.data<>to_jsonb(m)),'Project membership history untouched by Team removal';
 assert (select relrowsecurity from pg_class where oid='public.project_memberships'::regclass),'membership RLS enabled';
 assert not has_table_privilege('authenticated','public.project_memberships','SELECT,INSERT,UPDATE,DELETE'),'no client roster or mutation grant';
 assert not has_function_privilege('anon','public.has_active_project_membership(uuid)','EXECUTE'),'anonymous helper denied';
 assert (select proconfig=array['search_path=""'] from pg_proc where oid='public.has_active_project_membership(uuid)'::regprocedure),'fixed definer search_path';
 assert to_regclass('public.project_baselines') is null,'no later M6 resources';
end $$;
rollback;
\echo M6.2 Project participation/lifecycle/Team removal/RLS PASS
