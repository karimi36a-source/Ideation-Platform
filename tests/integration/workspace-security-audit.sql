\set ON_ERROR_STOP on
begin;
do $$ declare signature text; f record; begin
 assert (select relrowsecurity from pg_class where oid='public.workspaces'::regclass),'Workspace RLS remains enabled';
 assert (select count(*) from pg_policy where polrelid='public.workspaces'::regclass)=8,'only approved M4/M5 Workspace policies and M5.11 restrictive guards exist';
 assert not exists(select 1 from pg_policy where polrelid='public.workspaces'::regclass and polname not in ('workspaces_personal_owner_read','workspaces_master_owner_read','workspaces_client_insert_denied','workspaces_client_update_denied','workspaces_client_delete_denied','workspaces_active_team_member_read','workspaces_team_read_scope_guard','workspaces_team_anonymous_deny')),'approved Workspace policy allowlist';
 assert not exists(select 1 from pg_policy where polrelid='public.workspaces'::regclass and polpermissive and polroles<>array['authenticated'::regrole::oid]),'no anonymous/public permissive policy exposure';
 assert not has_table_privilege('anon','public.workspaces','SELECT,INSERT,UPDATE,DELETE,TRUNCATE'),'anonymous table grants denied';
 assert not has_table_privilege('authenticated','public.workspaces','INSERT,UPDATE,DELETE,TRUNCATE'),'client mutation grants denied';
 assert not (select rolbypassrls or rolsuper from pg_roles where rolname='authenticated'),'browser role cannot bypass RLS';
 foreach signature in array array['public.create_personal_workspace()','public.create_master_workspace(uuid)'] loop
  select * into f from pg_proc where oid=signature::regprocedure;
  assert f.prosecdef and f.proconfig=array['search_path=""'],'provisioning uses fixed empty search_path';
  assert not pg_has_role('authenticated',f.proowner,'USAGE') and not pg_has_role('anon',f.proowner,'USAGE'),'clients cannot become RPC owner';
  assert f.proowner not in ('anon'::regrole,'authenticated'::regrole,'service_role'::regrole),'RPC owned by trusted migration role';
  assert has_function_privilege('authenticated',signature,'EXECUTE'),'narrow verified-user provisioning retained';
  assert not has_function_privilege('anon',signature,'EXECUTE') and not has_function_privilege('service_role',signature,'EXECUTE'),'no anonymous or generic privileged provisioning';
  assert not exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) where grantee=0 and privilege_type='EXECUTE'),'PUBLIC cannot execute provisioning';
 end loop;
 assert (select pronargs=0 from pg_proc where oid='public.create_personal_workspace()'::regprocedure),'Personal has no caller owner/type arguments';
 assert (select pronargs=1 and proargnames=array['target_cohort'] from pg_proc where oid='public.create_master_workspace(uuid)'::regprocedure),'Master accepts only validated cohort input';
end $$;
rollback;
\echo M4.10 security audit PASS - RLS, RPC ownership/search_path, least-privilege grants and identity-safe signatures
