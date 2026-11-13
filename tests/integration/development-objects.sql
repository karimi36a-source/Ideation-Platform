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

insert into public.development_objects(project_id,workspace_id,object_type,title,content,created_by)
 select p.id,p.primary_workspace_id,t,'Fixture '||t,'Generic content',coalesce(p.owner_user_id,'00000000-0000-4000-8000-000000006004'::uuid)
 from public.development_projects p cross join unnest(enum_range(null::public.development_object_type)) t;
-- Multiple same-type objects are valid; metadata cannot supply core columns.
insert into public.development_objects(project_id,workspace_id,object_type,title,created_by,metadata)
 select id,primary_workspace_id,'PROBLEM','Second problem','00000000-0000-4000-8000-000000006004','{"owner_user_id":"fake","object_type":"ADMIN"}' from public.development_projects where project_type='individual';
create temporary table object_history as select id,to_jsonb(o) data from public.development_objects o;
grant select on acceptance_personal,object_history to authenticated;
do $$declare p uuid;w uuid;i integer;begin
 assert (select count(*) from public.development_objects)=37,'12 types per three Project kinds plus repeated type';
 assert (select count(distinct object_type) from public.development_objects)=12,'all twelve kinds';
 select id,primary_workspace_id into p,w from public.development_projects where project_type='individual';
 for i in 1..8 loop
 begin
 if i=1 then insert into public.development_objects(project_id,workspace_id,object_type,title,created_by) values(p,w,'INVALID','Bad','00000000-0000-4000-8000-000000006004');
 elsif i=2 then insert into public.development_objects(project_id,workspace_id,object_type,title,created_by) values(p,(select id from acceptance_personal where data->>'owner_user_id'='00000000-0000-4000-8000-000000006005'),'IDEA','Wrong owner','00000000-0000-4000-8000-000000006004');
 elsif i=3 then insert into public.development_objects(project_id,workspace_id,object_type,title,created_by) values('00000000-0000-4000-8000-000000007202',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='B'),'IDEA','Cross Team','00000000-0000-4000-8000-000000006004');
 elsif i=4 then insert into public.development_objects(project_id,workspace_id,object_type,title,created_by) values(p,'00000000-0000-4000-8000-000000007101','IDEA','Cross Project','00000000-0000-4000-8000-000000006004');
 elsif i=5 then insert into public.development_objects(project_id,workspace_id,object_type,title,created_by) values('00000000-0000-4000-8000-000000009999',w,'IDEA','Missing Project','00000000-0000-4000-8000-000000006004');
 elsif i=6 then insert into public.development_objects(project_id,workspace_id,object_type,title,created_by) values(p,'00000000-0000-4000-8000-000000009999','IDEA','Missing Workspace','00000000-0000-4000-8000-000000006004');
 elsif i=7 then insert into public.development_objects(metadata) values('{"project_id":"fake","title":"fake","object_type":"IDEA"}');
 else update public.development_objects set current_version_number=0;end if;
 raise exception 'invalid object accepted %',i;
 exception when check_violation or foreign_key_violation or invalid_text_representation or not_null_violation then null;end;
 end loop;
 update public.development_objects set archived_at=clock_timestamp() where project_id=p;
 assert (select count(*) from public.development_objects where project_id=p)=13,'archive preserves rows';
 begin delete from public.development_objects;raise exception 'destructive history';exception when check_violation then null;end;
 begin update public.development_objects set created_by='00000000-0000-4000-8000-000000006005';raise exception 'creator rewritten';exception when check_violation then null;end;
 assert not exists(select 1 from public.development_objects where current_version_number<>1),'initial version one';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert (select count(*) from public.development_objects)=25,'Individual owner and explicitly participating Team member';
 assert not exists(select 1 from public.development_objects where project_id='00000000-0000-4000-8000-000000007203'),'Student Case Study denied';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert (select count(*) from public.development_objects)=12,'Case owner scoped Master only';end $$;
do $$declare who text;begin
 foreach who in array array['6001','6003','6006','6007','6008'] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
 assert not exists(select 1 from public.development_objects),'Admin/unrelated Master/Team B/Mentor without Project membership denied';
 assert not exists(select 1 from public.development_objects where id=(select id from object_history where data->>'project_id'='00000000-0000-4000-8000-000000007202' limit 1)),'exact Team A object ID denied';
 assert not exists(select 1 from public.development_objects where id='00000000-0000-4000-8000-000000009999'),'nonexistent object also returns no row';
 begin update public.development_objects set project_id='00000000-0000-4000-8000-000000007203',workspace_id='00000000-0000-4000-8000-000000007101';raise exception 'client binding rewrite';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.development_objects where project_id='00000000-0000-4000-8000-000000007201'),'private Individual exact scope';
 begin insert into public.development_objects(project_id,workspace_id,object_type,title,created_by) values('00000000-0000-4000-8000-000000007201','00000000-0000-4000-8000-000000007101','IDEA','Spoof','00000000-0000-4000-8000-000000006004');raise exception 'client creator insert';exception when insufficient_privilege then null;end;
 begin update public.development_objects set created_by=auth.uid(),metadata='{"role":"ADMIN"}';raise exception 'client update';exception when insufficient_privilege then null;end;
 begin delete from public.development_objects;raise exception 'client delete';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert (select count(*) from public.development_objects)=13,'removed Team membership denies stale Project membership; Personal preserved';end $$;
reset role;
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert not exists(select 1 from public.development_objects),'Case ownership alone denied';end $$;
reset role;
update public.workspaces set status='inactive' where workspace_type='PERSONAL';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.development_objects),'Workspace access required';end $$;
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform * from public.development_objects;raise exception 'anonymous read';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert (select relrowsecurity from pg_class where oid='public.development_objects'::regclass),'Object RLS enabled';
 assert not has_table_privilege('authenticated','public.development_objects','INSERT,UPDATE,DELETE'),'no direct mutation grants';
 assert (select count(*) from public.development_objects)=37,'history retained after role/Team changes';
 assert not exists(select 1 from object_history h join public.development_objects o using(id) where h.data-'archived_at'<>to_jsonb(o)-'archived_at'),'history unchanged';
end $$;
rollback;
\echo M6.5 Object types/bindings/Project AND Workspace RLS/history PASS
