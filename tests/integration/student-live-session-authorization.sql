\set ON_ERROR_STOP on
begin;
-- Reuse only the canonical M16.3 Cohorts/Master assignments. Fixture setup is
-- trusted provisioning; all eligibility assertions execute as authenticated.
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'m164-'||n||'@example.test' from generate_series(160401,160410) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'm164-%@example.test';
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
select case when n=160402 then '00000000-0000-4000-8000-000000160321'::uuid else '00000000-0000-4000-8000-000000160320'::uuid end,
 ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 case when n=160409 then 'instructor'::public.enrollment_role else 'participant'::public.enrollment_role end,
 case when n=160403 then 'invited'::public.enrollment_status else 'active'::public.enrollment_status end
from generate_series(160401,160410) n;
create temporary table sj(label text primary key,data jsonb);grant select,insert on sj to authenticated,service_role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000160301',true);
insert into sj select 'context',public.authorize_master_live_room('00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000701');
insert into sj select 'expiredContext',public.authorize_master_live_room('00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000710');
insert into sj select 'Team A',public.create_team('00000000-0000-4000-8000-000000160320','M16.4 Team A');
select public.add_team_member((select (data->>'teamId')::uuid from sj where label='Team A'),'00000000-0000-4000-8000-000000160405','member');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000160304',true);
insert into sj select 'Team B',public.create_team('00000000-0000-4000-8000-000000160321','M16.4 Team B');
select public.add_team_member((select (data->>'teamId')::uuid from sj where label='Team B'),'00000000-0000-4000-8000-000000160402','member');
reset role;
update public.enrollments set status='withdrawn' where user_id='00000000-0000-4000-8000-000000160404';
update public.enrollments set status='removed' where user_id='00000000-0000-4000-8000-000000160405';
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000160406';
update public.users set account_status='invited' where id='00000000-0000-4000-8000-000000160407';
update public.users set account_status='archived' where id='00000000-0000-4000-8000-000000160410';
set local role service_role;
insert into sj select 'room',public.master_live_room_mapping('REUSE_OR_CREATE','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000701',null,(select data->>'roomKey' from sj where label='context'),'00000000-0000-4000-8000-000000160301');
insert into sj select 'expiredRoom',public.master_live_room_mapping('REUSE_OR_CREATE','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000710',null,(select data->>'roomKey' from sj where label='expiredContext'),'00000000-0000-4000-8000-000000160301');
select public.manage_live_room_mapping('EXPIRE','00000000-0000-4000-8000-000000160320','00000000-0000-4000-8000-000000000710','DAILY',null,'00000000-0000-4000-8000-000000160301',(select (data->>'id')::uuid from sj where label='expiredRoom'));
reset role;
create temporary table sj_before as select jsonb_agg(to_jsonb(r) order by id) data from public.live_session_rooms r;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000160401',true);
do $$begin
 assert public.can_join_live_session((select (data->>'id')::uuid from sj where label='room')),'enrolled A1 allowed';
 assert not public.can_join_live_session((select (data->>'id')::uuid from sj where label='expiredRoom')),'expired mapping denied';
 assert not public.can_join_live_session('00000000-0000-4000-8000-999999999999'),'guessed ID denied';
 assert not public.can_join_live_session(null),'null ID denied';
 begin perform * from public.live_session_rooms where id=(select (data->>'id')::uuid from sj where label='room');raise exception 'Eligibility exposed mapping';exception when insufficient_privilege then null;end;
end$$;
do $$declare n integer;begin
 foreach n in array array[160402,160403,160404,160405,160406,160407,160409,160410,160301,160306] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  assert not public.can_join_live_session((select (data->>'id')::uuid from sj where label='room')),'foreign/inactive/removed/instructor/role-only denied: '||n;
 end loop;
end$$;
reset role;
-- Cohort lifecycle is an input to eligibility, never changed by eligibility.
update public.cohorts set status='completed' where id='00000000-0000-4000-8000-000000160320';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000160401',true);
do $$begin assert not public.can_join_live_session((select (data->>'id')::uuid from sj where label='room')),'non-active Cohort denied';end$$;
reset role;
update public.cohorts set status='active' where id='00000000-0000-4000-8000-000000160320';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000160401',true);
do $$begin assert public.can_join_live_session((select (data->>'id')::uuid from sj where label='room')),'no stale denial cached';end$$;
reset role;
set local role anon;
do $$begin begin perform public.can_join_live_session('00000000-0000-4000-8000-999999999999');raise exception 'Anonymous execution allowed';exception when insufficient_privilege then null;end;end$$;
reset role;
do $$begin
 assert (select data from sj_before)=(select jsonb_agg(to_jsonb(r) order by id) from public.live_session_rooms r),'eligibility never mutates mapping/history';
 assert exists(select 1 from public.team_memberships where user_id='00000000-0000-4000-8000-000000160405' and status='active'),'Team membership alone cannot override removed enrollment';
 assert exists(select 1 from public.enrollments where user_id='00000000-0000-4000-8000-000000160405' and status='removed'),'removed enrollment history retained';
 assert not has_function_privilege('anon','public.can_join_live_session(uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.can_join_live_session(uuid)','EXECUTE');
 assert not has_table_privilege('authenticated','public.live_session_rooms','SELECT,INSERT,UPDATE,DELETE');
 assert exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='can_join_live_session' and p.prosecdef and p.provolatile='s' and p.proconfig @> array['search_path=""']);
end$$;
commit;
\echo M16.4 Student/exact-Cohort/active-room/account-enrollment-removal/Team-only-denial/direct-ID-privacy PASS
