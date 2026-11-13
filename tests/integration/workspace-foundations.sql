\set ON_ERROR_STOP on
begin;
do $$ declare workspace_column text; begin
 assert enum_range(null::public.workspace_type)::text[]=array['PERSONAL','TEAM','MASTER','SHARED','CASE_STUDY'],'exact five Workspace types';
 foreach workspace_column in array array['team_id','project_id'] loop
  assert exists(select 1 from information_schema.columns c where c.table_schema='public' and c.table_name='workspaces' and c.column_name=workspace_column and c.data_type='uuid' and c.is_nullable='YES'),'deferred UUID retained';
  if workspace_column='project_id' then
   assert not exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey) where c.conrelid='public.workspaces'::regclass and c.contype='f' and a.attname=workspace_column),'Project FK remains deferred';
  else
   assert exists(select 1 from pg_constraint where conrelid='public.workspaces'::regclass and conname='workspaces_team_id_fkey' and confrelid='public.teams'::regclass),'M5.1 Team FK exists';
  end if;
 end loop;
 assert (select col_description('public.workspaces'::regclass,attnum) like '%M5%' from pg_attribute where attrelid='public.workspaces'::regclass and attname='team_id'),'Team FK documented M5';
 assert (select col_description('public.workspaces'::regclass,attnum) like '%M6%' from pg_attribute where attrelid='public.workspaces'::regclass and attname='project_id'),'Project FK documented M6';
 assert not exists(select 1 from pg_tables where schemaname='public' and tablename in ('team_members','projects','project_baselines','sharing_recipients','sharing_permissions','share_recipients','share_permissions','chat_rooms')),'no parallel later-domain models';
 assert not exists(select 1 from public.shares),'Workspace operations do not create Shares';
 assert not exists(select 1 from pg_policies where schemaname='public' and tablename in('shares','share_snapshots') and permissive='PERMISSIVE'),'no permissive raw Share/Snapshot access';
 assert (select count(*) from pg_policy where polrelid in('public.shares'::regclass,'public.share_snapshots'::regclass) and not polpermissive and polcmd='*' and pg_get_expr(polqual,polrelid)='false' and pg_get_expr(polwithcheck,polrelid)='false')=2,'M13.19 explicit raw client deny guards preserve RPC-only sharing';
 assert not exists(select 1 from pg_proc f join pg_namespace n on n.oid=f.pronamespace where n.nspname='public' and f.proname in ('create_team_workspace','create_shared_workspace','publish_case_study','create_case_study_project')),'no premature provisioning/publication operations';
 assert not exists(select 1 from pg_policies where schemaname='public' and tablename='workspaces' and cmd in ('SELECT','ALL') and qual='true'),'no broad authenticated discovery';
end $$;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000001801','foundation-student@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000001801','active');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000001801','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000001801');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001801',true);
do $$ declare w jsonb; kind text; begin
 w:=public.create_personal_workspace();
 assert w->>'workspace_type'='PERSONAL' and w->>'owner_user_id'='00000000-0000-4000-8000-000000001801' and w->>'team_id' is null and w->>'project_id' is null,'Personal RPC does not manufacture other scope';
 foreach kind in array array['MASTER','TEAM','SHARED','CASE_STUDY'] loop
  begin perform public.create_personal_workspace(jsonb_build_object('workspace_type',kind,'owner_user_id','00000000-0000-4000-8000-000000009999','team_id','00000000-0000-4000-8000-000000009998'));raise exception 'Personal type/scope spoofing accepted';exception when undefined_function then null;end;
  begin insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values(kind::public.workspace_type,'Attack','00000000-0000-4000-8000-000000001801','00000000-0000-4000-8000-000000001801','00000000-0000-4000-8000-000000001801');raise exception 'direct privileged type creation';exception when insufficient_privilege then null;end;
 end loop;
 assert (select count(*) from public.workspaces)=1,'only own Personal discovery';
end $$;
reset role;
rollback;
\echo M4.7 five-type foundation, deferred FK inventory, Personal privilege-escalation denial and later-domain boundary PASS



