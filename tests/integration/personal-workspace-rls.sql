\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000001701','pwrls-a@example.test'),
 ('00000000-0000-4000-8000-000000001702','pwrls-b@example.test'),
 ('00000000-0000-4000-8000-000000001703','pwrls-master@example.test'),
 ('00000000-0000-4000-8000-000000001704','pwrls-mentor@example.test'),
 ('00000000-0000-4000-8000-000000001705','pwrls-admin@example.test');
select public.provision_user_profile(id,'active') from auth.users where email like 'pwrls-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by)
 select uid::uuid,rid::uuid,'00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000001705' from (values
 ('00000000-0000-4000-8000-000000001701','00000000-0000-4000-8000-000000000104'),
 ('00000000-0000-4000-8000-000000001702','00000000-0000-4000-8000-000000000104'),
 ('00000000-0000-4000-8000-000000001703','00000000-0000-4000-8000-000000000102'),
 ('00000000-0000-4000-8000-000000001704','00000000-0000-4000-8000-000000000103'),
 ('00000000-0000-4000-8000-000000001705','00000000-0000-4000-8000-000000000101')) roles(uid,rid);
create temporary table pwrls_ids(id uuid);grant select,insert on pwrls_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001701',true);
insert into pwrls_ids select (public.create_personal_workspace()->>'id')::uuid;
do $$ begin
 assert exists(select 1 from public.workspaces where id=(select id from pwrls_ids)),'Student A own SELECT allowed';
 assert (public.create_personal_workspace()->>'id')::uuid=(select id from pwrls_ids),'trusted RPC remains idempotent';
end $$;
\echo AT-PW-001 PASS - Student A1 authenticated owner SELECT and idempotent provisioning
reset role;
-- Give clients table privileges and even permissive write policies in this
-- rolled-back attack fixture: restrictive production guards must still deny.
-- Attach a real cohort to the private fixture so cohort filtering is meaningful.
create temporary table pwrls_cohort(id uuid);grant select,insert on pwrls_cohort to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001705',true);
insert into pwrls_cohort select (public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Enumeration fixture','2026-10-01',null,'00000000-0000-4000-8000-000000001703','planned','{}')->>'id')::uuid;
reset role;
update public.workspaces set cohort_id=(select id from pwrls_cohort),name='Confidential owner name',settings='{"private":"do not expose"}' where id=(select id from pwrls_ids);
do $$ begin
 assert exists(select 1 from public.workspaces where id=(select id from pwrls_ids) and cohort_id=(select id from pwrls_cohort)),'private cohort-linked fixture actually exists';
end $$;
grant insert,update,delete on public.workspaces to authenticated;
create policy pwrls_attack_insert on public.workspaces for insert to authenticated with check(true);
create policy pwrls_attack_update on public.workspaces for update to authenticated using(true) with check(true);
create policy pwrls_attack_delete on public.workspaces for delete to authenticated using(true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001701',true);
do $$ declare n integer; kind public.workspace_type; begin
 update public.workspaces set owner_user_id='00000000-0000-4000-8000-000000001702' where id=(select id from pwrls_ids);get diagnostics n=row_count;assert n=0,'ownership transfer blocked';
 foreach kind in array array['MASTER','TEAM','SHARED','CASE_STUDY']::public.workspace_type[] loop
  update public.workspaces set workspace_type=kind where id=(select id from pwrls_ids);get diagnostics n=row_count;assert n=0,'type escalation blocked';
 end loop;
 update public.workspaces set team_id='00000000-0000-4000-8000-000000009999',project_id='00000000-0000-4000-8000-000000009998' where id=(select id from pwrls_ids);get diagnostics n=row_count;assert n=0,'manufactured scopes blocked';
 delete from public.workspaces where id=(select id from pwrls_ids);get diagnostics n=row_count;assert n=0,'direct lifecycle delete blocked';
 begin insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values('PERSONAL','Attack','00000000-0000-4000-8000-000000001702','00000000-0000-4000-8000-000000001701','00000000-0000-4000-8000-000000001701');raise exception 'foreign owner INSERT';exception when insufficient_privilege then null;end;
 begin insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values('PERSONAL','Duplicate','00000000-0000-4000-8000-000000001701','00000000-0000-4000-8000-000000001701','00000000-0000-4000-8000-000000001701');raise exception 'direct duplicate INSERT';exception when insufficient_privilege then null;end;
end $$;
-- Real Student B/Master/Mentor/Admin auth contexts cannot read the direct ID.
do $$ declare n integer; affected integer; begin
 for n in 1702..1705 loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  assert not exists(select 1 from public.workspaces where id=(select id from pwrls_ids)),'non-owner direct ID hides all metadata';
  assert not exists(select name,owner_user_id,cohort_id,settings from public.workspaces where owner_user_id='00000000-0000-4000-8000-000000001701'),'owner filter hides private metadata';
  assert not exists(select 1 from public.workspaces where cohort_id=(select id from pwrls_cohort) and workspace_type='PERSONAL'),'cohort plus type filter does not authorize';
  assert (select count(*) from public.workspaces where id=(select id from pwrls_ids))=(select count(*) from public.workspaces where id='00000000-0000-4000-8000-000000009999'),'real and nonexistent IDs both return no row';
  assert (select count(*) from public.workspaces where workspace_type='PERSONAL')=0,'unfiltered Personal enumeration has no foreign rows';
  update public.workspaces set name='Leaked or changed' where id=(select id from pwrls_ids);get diagnostics affected=row_count;assert affected=0,'non-owner exact-ID update denied';
  update public.workspaces set status='archived',archived_at=now() where id=(select id from pwrls_ids);get diagnostics affected=row_count;assert affected=0,'non-owner exact-ID archive denied';
  delete from public.workspaces where id=(select id from pwrls_ids);get diagnostics affected=row_count;assert affected=0,'non-owner exact-ID delete denied';
 end loop;
end $$;
\echo AT-PW-002 PASS - Student A2 exact-ID database query exposes no row or metadata
\echo AT-PW-003 PASS - Master cannot browse unshared Personal Workspace
set local role anon;
do $$ begin begin perform * from public.workspaces;raise exception 'anonymous SELECT';exception when insufficient_privilege then null;end;end $$;
reset role;
drop policy pwrls_attack_insert on public.workspaces;drop policy pwrls_attack_update on public.workspaces;drop policy pwrls_attack_delete on public.workspaces;
revoke insert,update,delete on public.workspaces from authenticated;
do $$ begin
 assert (select relrowsecurity from pg_class where oid='public.workspaces'::regclass),'RLS enabled';
 assert not exists(select 1 from pg_policies where schemaname='public' and tablename='workspaces' and cmd in ('SELECT','ALL') and qual='true'),'no broad SELECT';
 assert (select count(*) from pg_policy where polrelid='public.workspaces'::regclass and not polpermissive and polname in ('workspaces_client_insert_denied','workspaces_client_update_denied','workspaces_client_delete_denied'))=3,'three original restrictive mutation guards retained';
 assert not has_table_privilege('authenticated','public.workspaces','INSERT,UPDATE,DELETE,TRUNCATE'),'no client write grants';
 assert (select count(*) from public.workspaces where owner_user_id='00000000-0000-4000-8000-000000001701' and workspace_type='PERSONAL' and status='active')=1,'attacks preserve one active owner row';
 assert exists(select 1 from public.workspaces where id=(select id from pwrls_ids) and name='Confidential owner name' and settings='{"private":"do not expose"}'::jsonb and cohort_id=(select id from pwrls_cohort) and archived_at is null),'enumeration and mutation attempts leave private metadata unchanged';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.create_personal_workspace()'::regprocedure),'safe narrow provisioning definer';
 assert not has_function_privilege('anon','public.create_personal_workspace()','EXECUTE'),'anonymous RPC denied';
 assert not has_function_privilege('service_role','public.create_personal_workspace()','EXECUTE'),'no generic service provisioning bypass';
end $$;
rollback;
\echo M4.5 Personal privacy and direct RLS attack matrix PASS
\echo M4.8 mutation attacks PASS - owner transfer, type escalation, forged scope, INSERT and DELETE
\echo M4.9 enumeration and exact-ID mutation PASS - owner/cohort filters, existence comparison, Master/Admin privacy
