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

insert into public.project_memberships(project_id,user_id) values('00000000-0000-4000-8000-000000007202','00000000-0000-4000-8000-000000006008');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006004','participant','active' from acceptance_cohorts where label='Unrelated';
create temporary table relationship_objects(label text primary key,payload jsonb);grant select,insert on relationship_objects to authenticated;
create temporary table relationship_results(label text primary key,payload jsonb);grant select,insert,update on relationship_results to authenticated;
create temporary table additional_project(id uuid);grant select,insert on additional_project to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into additional_project values((public.create_development_project('Other private Project','individual',(select id from public.workspaces where workspace_type='PERSONAL'))->>'id')::uuid);
insert into relationship_objects values
 ('Problem',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from public.workspaces where workspace_type='PERSONAL'),'PROBLEM','Problem','Content','User')),
 ('Solution',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from public.workspaces where workspace_type='PERSONAL'),'SOLUTION','Solution','Content','User')),
 ('Component',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from public.workspaces where workspace_type='PERSONAL'),'COMPONENT','Component','Content','User')),
 ('System',public.create_development_object('00000000-0000-4000-8000-000000007201',(select id from public.workspaces where workspace_type='PERSONAL'),'SYSTEM','System','Content','User')),
 ('Other Project',public.create_development_object((select id from additional_project),(select id from public.workspaces where workspace_type='PERSONAL'),'PROBLEM','Other','Content','User')),
 ('Team Problem',public.create_development_object('00000000-0000-4000-8000-000000007202',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),'PROBLEM','Problem','Content','User')),
 ('Team Solution',public.create_development_object('00000000-0000-4000-8000-000000007202',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),'SOLUTION','Solution','Content','User'));
insert into relationship_results select kind::text,public.relate_development_objects((select (payload->>'id')::uuid from relationship_objects where label='Solution'),(select (payload->>'id')::uuid from relationship_objects where label='Problem'),kind,'Description') from unnest(enum_range(null::public.development_relationship_type)) kind;
insert into relationship_results values('Component System',public.relate_development_objects((select (payload->>'id')::uuid from relationship_objects where label='Component'),(select (payload->>'id')::uuid from relationship_objects where label='System'),'BELONGS_TO')),
 ('Team',public.relate_development_objects((select (payload->>'id')::uuid from relationship_objects where label='Team Solution'),(select (payload->>'id')::uuid from relationship_objects where label='Team Problem'),'SOLVES'));
do $$declare s uuid;t uuid;begin
 select (payload->>'id')::uuid into s from relationship_objects where label='Solution';select (payload->>'id')::uuid into t from relationship_objects where label='Problem';
 assert exists(select 1 from public.development_object_relationships where source_object_id=s and target_object_id=t and relationship_type='SOLVES' and created_by=auth.uid()),'Solution SOLVES Problem direction/creator';
 assert not exists(select 1 from public.development_object_relationships where source_object_id=t and target_object_id=s),'no inverse edge even CONNECTED_TO';
 assert (select count(distinct relationship_type) from public.development_object_relationships)=15,'all exact types';
 begin perform public.relate_development_objects(s,t,'SOLVES','Different description');raise exception 'duplicate active edge';exception when unique_violation then null;end;
 begin perform public.relate_development_objects(s,s,'SOLVES');raise exception 'self edge';exception when invalid_parameter_value then null;end;
 begin perform public.relate_development_objects(s,(select (payload->>'id')::uuid from relationship_objects where label='Other Project'),'SOLVES');raise exception 'cross Project';exception when invalid_parameter_value then null;end;
 begin perform public.relate_development_objects(s,t,'INVALID');raise exception 'invalid kind';exception when invalid_text_representation then null;end;
 begin perform public.relate_development_objects(s,'00000000-0000-4000-8000-000000009999','SOLVES');raise exception 'missing endpoint';exception when insufficient_privilege then null;end;
end $$;
select public.link_project_to_program('00000000-0000-4000-8000-000000007201','00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test'));
reset role;
create temporary table continuity_objects as select id,to_jsonb(o) data from public.development_objects o;
create temporary table continuity_edges as select id,to_jsonb(e) data from public.development_object_relationships e;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.link_project_to_program('00000000-0000-4000-8000-000000007201','00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Unrelated'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into relationship_objects values('Case Problem',public.create_development_object('00000000-0000-4000-8000-000000007203','00000000-0000-4000-8000-000000007101','PROBLEM','Problem','Content',null)),('Case Solution',public.create_development_object('00000000-0000-4000-8000-000000007203','00000000-0000-4000-8000-000000007101','SOLUTION','Solution','Content',null));
insert into relationship_results values('Case',public.relate_development_objects((select (payload->>'id')::uuid from relationship_objects where label='Case Solution'),(select (payload->>'id')::uuid from relationship_objects where label='Case Problem'),'SOLVES'));
do $$declare who text;s uuid;t uuid;edge uuid;begin
 foreach who in array array['6001','6003','6006','6007','6008'] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who,12,'0'),true);
 if who<>'6008' then assert not exists(select 1 from public.development_object_relationships),'unrelated/Admin/Team B edges denied';else assert (select count(*) from public.development_object_relationships)=1,'scoped Mentor may read only Team edge';end if;
 select (payload->>'id')::uuid into s from relationship_objects where label='Team Solution';select (payload->>'id')::uuid into t from relationship_objects where label='Team Problem';select (payload->>'id')::uuid into edge from relationship_results where label='Team';
 if who<>'6008' then assert not exists(select 1 from public.development_object_relationships where id=edge),'exact Team edge ID denied';end if;
 begin perform public.relate_development_objects(s,t,'IMPLEMENTS');raise exception 'unauthorized relationship';exception when insufficient_privilege then null;end;
 begin perform public.unlink_development_objects(edge);raise exception 'unauthorized unlink';exception when insufficient_privilege then null;end;
 begin perform public.relate_development_objects((select (payload->>'id')::uuid from relationship_objects where label='Solution'),(select (payload->>'id')::uuid from relationship_objects where label='Problem'),'IMPLEMENTS');raise exception 'private Individual relate';exception when insufficient_privilege then null;end;
 begin insert into public.development_object_relationships(project_id,source_object_id,target_object_id,relationship_type,created_by) values('00000000-0000-4000-8000-000000007202',s,t,'IMPLEMENTS',auth.uid());raise exception 'direct insert';exception when insufficient_privilege then null;end;
 begin update public.development_object_relationships set status='active',created_by=auth.uid();raise exception 'direct update';exception when insufficient_privilege then null;end;
 begin delete from public.development_object_relationships;raise exception 'direct delete';exception when insufficient_privilege then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.development_object_relationships where id=(select (payload->>'id')::uuid from relationship_results where label='Team')),'removed member exact ID';
 begin perform public.unlink_development_objects((select (payload->>'id')::uuid from relationship_results where label='Team'));raise exception 'stale Project membership';exception when insufficient_privilege then null;end;
 begin perform public.relate_development_objects((select (payload->>'id')::uuid from relationship_objects where label='Team Solution'),(select (payload->>'id')::uuid from relationship_objects where label='Team Problem'),'IMPLEMENTS');raise exception 'removed relate';exception when insufficient_privilege then null;end;
end $$;
insert into relationship_results values('Unlinked',public.unlink_development_objects((select (payload->>'id')::uuid from relationship_results where label='SOLVES')));
do $$declare first jsonb;retry jsonb;begin
 select payload into first from relationship_results where label='Unlinked';retry:=public.unlink_development_objects((first->>'id')::uuid);
 assert first=retry,'unlink idempotency';assert first->>'status'='inactive','historical inactive';
 assert first-'status'-'updated_at'=(select payload-'status'-'updated_at' from relationship_results where label='SOLVES'),'unlink identity preserved';
 assert exists(select 1 from public.development_object_relationships where id=(first->>'id')::uuid and status='inactive'),'historical row retained';
end $$;
insert into relationship_results values('Relink',public.relate_development_objects((select (payload->>'id')::uuid from relationship_objects where label='Solution'),(select (payload->>'id')::uuid from relationship_objects where label='Problem'),'SOLVES'));
select public.archive_development_object((select (payload->>'id')::uuid from relationship_objects where label='Solution'));
do $$begin
 assert exists(select 1 from public.development_object_relationships where id=(select (payload->>'id')::uuid from relationship_results where label='Relink')),'existing edge preserved after archive';
 begin perform public.relate_development_objects((select (payload->>'id')::uuid from relationship_objects where label='Solution'),(select (payload->>'id')::uuid from relationship_objects where label='Problem'),'SOLVES');raise exception 'new archived endpoint relationship';exception when invalid_parameter_value then null;end;
 perform public.unlink_development_objects((select (payload->>'id')::uuid from relationship_results where label='Relink'));
end $$;
reset role;
do $$declare edge_fixture public.development_object_relationships;i integer;begin
 select * into edge_fixture from public.development_object_relationships where id=(select (payload->>'id')::uuid from relationship_results where label='Component System');
 for i in 1..7 loop begin
 if i=1 then update public.development_object_relationships set source_object_id=target_object_id where id=edge_fixture.id;
 elsif i=2 then update public.development_object_relationships set target_object_id=source_object_id where id=edge_fixture.id;
 elsif i=3 then update public.development_object_relationships set project_id=(select id from additional_project) where id=edge_fixture.id;
 elsif i=4 then update public.development_object_relationships set created_by='00000000-0000-4000-8000-000000006005' where id=edge_fixture.id;
 elsif i=5 then update public.development_object_relationships set relationship_type='SOLVES' where id=edge_fixture.id;
 elsif i=6 then update public.development_object_relationships set status='active' where id=(select (payload->>'id')::uuid from relationship_results where label='Unlinked');
 else delete from public.development_object_relationships where id=edge_fixture.id;end if;
 raise exception 'history rewrite %',i;exception when check_violation then null;end;end loop;
 begin insert into public.development_object_relationships(project_id,source_object_id,target_object_id,relationship_type,created_by) values((select id from additional_project),edge_fixture.source_object_id,edge_fixture.target_object_id,'SOLVES',edge_fixture.created_by);raise exception 'raw cross Project';exception when foreign_key_violation then null;end;
 assert (select count(*) from public.development_objects)=9,'no Object clones';
 assert not exists(select 1 from continuity_objects b join public.development_objects o using(id) where b.data-'archived_at'<>to_jsonb(o)-'archived_at'),'same IDs/scope/content across later contexts';
 assert not exists(select 1 from continuity_edges b join public.development_object_relationships e using(id) where b.data-'status'-'updated_at'<>to_jsonb(e)-'status'-'updated_at'),'same semantic edges across later contexts';
 assert (select count(*) from public.development_object_relationships)=19,'history plus separate re-link';
end $$;
-- Forced failures prove atomic relate/unlink with no partial edge state.
create function public.fixture_relationship_failure() returns trigger language plpgsql set search_path='' as $$begin raise exception 'Fixture failure' using errcode='23514';end $$;
create trigger fixture_relationship_update_failure after update on public.development_object_relationships for each row execute function public.fixture_relationship_failure();
create trigger fixture_relationship_insert_failure after insert on public.development_object_relationships for each row execute function public.fixture_relationship_failure();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare before jsonb;begin
 select payload into before from relationship_results where label='Case';
 begin perform public.unlink_development_objects((before->>'id')::uuid);raise exception 'no failure';exception when check_violation then null;end;
 assert (select to_jsonb(e) from public.development_object_relationships e where id=(before->>'id')::uuid)=before,'atomic unlink rollback';
 begin perform public.relate_development_objects((before->>'source_object_id')::uuid,(before->>'target_object_id')::uuid,'IMPLEMENTS');raise exception 'no insert failure';exception when check_violation then null;end;
end $$;
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform * from public.development_object_relationships;raise exception 'anon read';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$declare f record;begin
 assert (select count(*) from public.development_object_relationships)=19,'no partial relationship';
 assert (select relrowsecurity from pg_class where oid='public.development_object_relationships'::regclass),'edge RLS enabled';
 assert not has_table_privilege('authenticated','public.development_object_relationships','INSERT,UPDATE,DELETE'),'no raw client mutation grants';
 for f in select oid,proconfig from pg_proc where pronamespace='public'::regnamespace and proname in ('relate_development_objects','unlink_development_objects') loop assert f.proconfig=array['search_path=""'],'safe fixed path';assert not has_function_privilege('anon',f.oid,'EXECUTE'),'no anonymous RPC';end loop;
end $$;
rollback;
\echo M6.8 semantic direction/types/same-Project integrity/history/continuity/RLS/atomicity PASS
