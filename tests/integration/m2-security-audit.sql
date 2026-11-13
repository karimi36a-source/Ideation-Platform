\set ON_ERROR_STOP on
begin;
do $$ declare t text; c text; begin
 foreach t in array array['users','roles','role_assignments'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass), 'sensitive RLS disabled';
  assert not has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'), 'anonymous table access';
  assert not has_table_privilege('authenticated','public.'||t,'INSERT,DELETE,TRUNCATE'), 'browser mutation grant';
  assert not has_table_privilege('service_role','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'), 'broad service grant';
 end loop;
 assert not has_table_privilege('authenticated','public.roles','SELECT,UPDATE'), 'catalog exposure';
 assert not has_table_privilege('authenticated','public.role_assignments','UPDATE'), 'assignment update grant';
 assert (select count(*) from pg_policies where schemaname='public' and tablename='users')=4, 'unexpected profile policy';
 assert (select count(*) from pg_policies where schemaname='public' and tablename='roles')=1, 'unexpected role policy';
 assert (select count(*) from pg_policies where schemaname='public' and tablename='role_assignments')=4, 'unexpected assignment policy';
 assert (select count(*) from pg_policies where schemaname='public' and tablename in ('users','roles','role_assignments') and permissive='PERMISSIVE')=3, 'unexpected permissive policy';
 assert not exists(select 1 from pg_policies where schemaname='public' and tablename in ('users','roles','role_assignments') and permissive='PERMISSIVE' and (qual='true' or with_check='true')), 'broad permissive policy';
 foreach c in array array['id','email','first_name','last_name','account_status','created_at','updated_at'] loop
  assert not has_column_privilege('authenticated','public.users',c,'UPDATE'), 'protected profile column writable';
 end loop;
 foreach c in array array['display_name','profile_image','timezone','locale'] loop
  assert has_column_privilege('authenticated','public.users',c,'UPDATE'), 'approved update field unavailable';
 end loop;
 assert not has_function_privilege('authenticated','public.provision_user_profile(uuid,public.account_status)','EXECUTE'), 'browser provisioner';
 assert has_function_privilege('service_role','public.provision_user_profile(uuid,public.account_status)','EXECUTE'), 'trusted provisioner unavailable';
end $$;
rollback;
\echo M2 security policy/grant inventory PASS
