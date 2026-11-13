\set ON_ERROR_STOP on
begin;
create temporary table org_snapshot as select * from public.organizations where slug='fici';
select public.seed_initial_organization(); select public.seed_initial_organization();
do $$ begin
 assert (select count(*) from public.organizations where slug='fici' and name='FICI' and status='active')=1, 'FICI seed';
 assert not exists(select * from public.organizations where slug='fici' except select * from org_snapshot), 'seed preserves metadata';
 assert (select relrowsecurity from pg_class where oid='public.organizations'::regclass), 'RLS enabled';
 begin insert into public.organizations(name,slug) values('Duplicate','fici'); raise exception 'duplicate slug'; exception when unique_violation then null; end;
 assert (select prosecdef from pg_proc where oid='public.update_organization(uuid,text,public.organization_status)'::regprocedure), 'explicit definer';
 assert (select proconfig=array['search_path=""'] from pg_proc where oid='public.update_organization(uuid,text,public.organization_status)'::regprocedure), 'fixed empty path';
end $$;
insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000000502','organization-admin@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000000001','active');
select public.provision_user_profile('00000000-0000-4000-8000-000000000502','active');
insert into public.organizations(id,name,slug) values('00000000-0000-4000-8000-000000000503','Other','other');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000502'),
 ('00000000-0000-4000-8000-000000000502','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000502');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$ begin
 assert (select count(*) from public.organizations)=0, 'Student has no Admin read';
 begin perform public.update_organization('00000000-0000-4000-8000-000000000501','Attack','archived'); raise exception 'student command'; exception when insufficient_privilege then null; end;
 begin update public.organizations set name='Attack'; raise exception 'client CRUD'; exception when insufficient_privilege then null; end;
 begin perform public.seed_initial_organization(); raise exception 'client seeded'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000502',true);
do $$ declare o public.organizations; begin
 assert (select count(*) from public.organizations)=1, 'Admin exact read';
 select * into o from pg_catalog.jsonb_populate_record(null::public.organizations,public.update_organization('00000000-0000-4000-8000-000000000501','FICI Renamed','inactive'));
 assert o.name='FICI Renamed' and o.status='inactive' and o.slug='fici' and o.settings='{}'::jsonb, 'Admin rename deactivate';
 select * into o from pg_catalog.jsonb_populate_record(null::public.organizations,public.update_organization(o.id,o.name,'archived')); assert o.status='archived', 'archive retained';
 select * into o from pg_catalog.jsonb_populate_record(null::public.organizations,public.update_organization(o.id,'FICI','active')); assert o.status='active', 'reactivate exact Admin';
 begin perform public.update_organization('00000000-0000-4000-8000-000000000503','Attack','active'); raise exception 'outside scope'; exception when insufficient_privilege then null; end;
 begin perform public.update_organization(o.id,' ','active'); raise exception 'invalid name'; exception when invalid_parameter_value then null; end;
end $$;
reset role;
update public.organizations set status='archived' where slug='fici';
select public.seed_initial_organization();
do $$ begin assert (select status='archived' from public.organizations where slug='fici'), 'seed does not reactivate archived organization';
 begin delete from public.organizations where slug='fici'; raise exception 'destroyed referenced organization'; exception when foreign_key_violation then null; end;
 begin insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000000502','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000599','00000000-0000-4000-8000-000000000502'); raise exception 'unresolved organization'; exception when foreign_key_violation then null; end;
end $$;
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000000502';
set local role authenticated;
do $$ begin begin perform public.update_organization('00000000-0000-4000-8000-000000000501','Attack','active'); raise exception 'inactive Admin'; exception when insufficient_privilege then null; end; end $$;
reset role;
set local role anon;
do $$ begin
 begin perform * from public.organizations; raise exception 'anon read'; exception when insufficient_privilege then null; end;
 begin perform public.update_organization('00000000-0000-4000-8000-000000000501','Attack','active'); raise exception 'anon command'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
\echo Organization seed, lifecycle, exact Admin scope, FK and RLS PASS

