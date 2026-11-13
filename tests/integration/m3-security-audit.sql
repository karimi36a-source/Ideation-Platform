\set ON_ERROR_STOP on
begin;
do $$ declare t text; f record; begin
 foreach t in array array['organizations','programs','curriculum_versions','session_definitions','activity_definitions','activity_dependencies','cohorts','enrollments'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass),'RLS enabled: '||t;
  assert not has_table_privilege('authenticated','public.'||t,'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'),'no broad authenticated write: '||t;
  assert not has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE'),'anonymous protected data: '||t;
  assert not exists(select 1 from pg_policies where schemaname='public' and tablename=t and (qual='true' or with_check='true')),'no catch-all policy: '||t;
 end loop;
 for f in select p.oid,p.proname,p.proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosecdef loop
  assert f.proconfig @> array['search_path=""'],'safe definer search path: '||f.proname;
  assert not has_function_privilege('anon',f.oid,'EXECUTE'),'anonymous cannot invoke definer: '||f.proname;
 end loop;
 assert not exists(select 1 from pg_tables where schemaname='public' and tablename in ('projects','project_baselines')),'no legacy Project or premature Artifact Version resources';
end $$;
rollback;
\echo M3 security inventory: RLS, least-privilege grants, no permissive catch-all, safe definers and scope boundary PASS
