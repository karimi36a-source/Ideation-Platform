\set ON_ERROR_STOP on
begin;
-- Identities/initial grants are fixtures; every pilot operation below uses its
-- authenticated canonical command, never a service-role administration shortcut.
create function pg_temp.pa_id(n integer) returns uuid language sql immutable as $$select ('00000000-0000-4000-8000-'||lpad((152800+n)::text,12,'0'))::uuid$$;
insert into auth.users(id,email) select pg_temp.pa_id(n),'m1528-'||n||'@example.test' from generate_series(1,12) n;
select public.provision_user_profile(pg_temp.pa_id(n),'active') from generate_series(1,12) n;
insert into public.organizations(id,name,slug) values(pg_temp.pa_id(100),'Other organization','m1528-other');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by)
select pg_temp.pa_id(n),'00000000-0000-4000-8000-000000000101',case when n=5 then pg_temp.pa_id(100) else '00000000-0000-4000-8000-000000000501'::uuid end,pg_temp.pa_id(1) from unnest(array[1,5,7,8]) n;
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values(pg_temp.pa_id(6),'00000000-0000-4000-8000-000000000104',pg_temp.pa_id(100),pg_temp.pa_id(5));
update public.users set account_status='suspended',first_name='PRIVATE_PROFILE',timezone='PRIVATE_TIMEZONE' where id=pg_temp.pa_id(8);
update public.role_assignments set status='inactive' where user_id=pg_temp.pa_id(7);
create temporary table pa(label text primary key,payload jsonb);grant select,insert on pa to authenticated;
create function pg_temp.pa(k text,f text default 'id') returns uuid language sql as $$select (payload->>f)::uuid from pa where label=k$$;
create function pg_temp.pa_denied(command text) returns void language plpgsql as $$begin
 begin execute command;raise exception 'Unauthorized command succeeded';exception when insufficient_privilege then null;end;
end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.pa_id(1)::text,true);
insert into pa select 'cohort',public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','M15.28 pilot','2026-10-01',null,pg_temp.pa_id(9),'active','{}');
select public.assign_master_to_cohort(pg_temp.pa('cohort'),pg_temp.pa_id(2));
insert into pa select 'A1 enrollment',public.enroll_user(pg_temp.pa('cohort'),pg_temp.pa_id(3),'participant','active');
insert into pa select 'A2 enrollment',public.enroll_user(pg_temp.pa('cohort'),pg_temp.pa_id(4),'participant','invited');
select public.transition_enrollment(pg_temp.pa('A2 enrollment'),'active');
insert into pa select 'inactive enrollment',public.enroll_user(pg_temp.pa('cohort'),pg_temp.pa_id(10),'participant','invited');
insert into pa select 'Team A',public.create_team(pg_temp.pa('cohort'),'M15.28 Team A');
insert into pa select 'Team B',public.create_team(pg_temp.pa('cohort'),'M15.28 Team B');
insert into pa select 'A1 membership',public.add_team_member(pg_temp.pa('Team A','teamId'),pg_temp.pa_id(3),'team_lead');
insert into pa select 'A2 membership',public.add_team_member(pg_temp.pa('Team A','teamId'),pg_temp.pa_id(4),'member');
do $$begin
 assert exists(select 1 from public.cohorts where id=pg_temp.pa('cohort') and primary_master_id=pg_temp.pa_id(2) and program_id='00000000-0000-4000-8000-000000000601' and curriculum_version_id='00000000-0000-4000-8000-000000000602');
 begin perform public.enroll_user(pg_temp.pa('cohort'),pg_temp.pa_id(3),'participant','active');raise exception 'Duplicate enrollment accepted';exception when unique_violation then null;end;
 begin perform public.add_team_member(pg_temp.pa('Team A','teamId'),pg_temp.pa_id(4),'member');raise exception 'Duplicate membership accepted';exception when unique_violation then null;end;
 assert public.get_team_workspace_access(pg_temp.pa('Team A','workspaceId')) is null,'Admin management does not grant private Workspace';
 assert not public.can_access_team_chat(pg_temp.pa('Team A','chatChannelId')),'Admin management does not grant Chat';
end$$;
-- Resolve duplicate membership with the supported remove/re-add workflow.
select public.remove_team_member(pg_temp.pa('Team A','teamId'),pg_temp.pa_id(4),'Pilot conflict correction');
select public.add_team_member(pg_temp.pa('Team A','teamId'),pg_temp.pa_id(4),'member');
select set_config('request.jwt.claim.sub',pg_temp.pa_id(4)::text,true);
do $$begin assert public.get_team_workspace_access(pg_temp.pa('Team A','workspaceId'))='member';end$$;
select set_config('request.jwt.claim.sub',pg_temp.pa_id(1)::text,true);
insert into pa select 'move',public.move_team_member(pg_temp.pa_id(4),pg_temp.pa('Team A','teamId'),pg_temp.pa('Team B','teamId'),'Pilot move');
select set_config('request.jwt.claim.sub',pg_temp.pa_id(4)::text,true);
do $$begin
 assert public.get_team_workspace_access(pg_temp.pa('Team A','workspaceId')) is null;
 assert not public.can_access_team_chat(pg_temp.pa('Team A','chatChannelId'));
 assert public.get_team_workspace_access(pg_temp.pa('Team B','workspaceId'))='member';
 assert exists(select 1 from public.notifications where notification_type='MEMBER_MOVED' and recipient_user_id=auth.uid());
end$$;
select set_config('request.jwt.claim.sub',pg_temp.pa_id(1)::text,true);
insert into pa select 'roster',jsonb_build_object('users',public.list_pilot_active_users('00000000-0000-4000-8000-000000000501'));
do $$declare row jsonb;n integer;begin
 for row in select value from jsonb_array_elements((select payload->'users' from pa where label='roster')) loop
  assert (select array_agg(k order by k) from jsonb_object_keys(row) k)=array['account_status','display_name','email','id'];
  assert row->>'account_status'='active';
 end loop;
 foreach n in array array[1,2,3,4] loop assert exists(select 1 from jsonb_array_elements((select payload->'users' from pa where label='roster')) x where x->>'id'=pg_temp.pa_id(n)::text);end loop;
 foreach n in array array[5,6,7,8,9,10,11,12] loop assert not exists(select 1 from jsonb_array_elements((select payload->'users' from pa where label='roster')) x where x->>'id'=pg_temp.pa_id(n)::text),'inactive, revoked, unrelated and unassociated users excluded';end loop;
 assert not exists(select 1 from public.users where id=pg_temp.pa_id(3)),'profile RLS remains self-only even for Admin';
end$$;
-- Other canonical scoped role associations resolve through their actual parents.
reset role;
insert into public.role_assignments(user_id,role_id,program_id,assigned_by,starts_at)
 values(pg_temp.pa_id(11),'00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000601',pg_temp.pa_id(1),now()-interval '1 day');
insert into public.role_assignments(user_id,role_id,team_id,assigned_by)
 values(pg_temp.pa_id(12),'00000000-0000-4000-8000-000000000103',pg_temp.pa('Team A','teamId'),pg_temp.pa_id(1));
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.pa_id(1)::text,true);
do $$begin
 assert exists(select 1 from jsonb_array_elements(public.list_pilot_active_users('00000000-0000-4000-8000-000000000501')) x where x->>'id'=pg_temp.pa_id(11)::text);
 assert exists(select 1 from jsonb_array_elements(public.list_pilot_active_users('00000000-0000-4000-8000-000000000501')) x where x->>'id'=pg_temp.pa_id(12)::text);
end$$;
reset role;
update public.role_assignments set ends_at=now()-interval '1 second' where user_id=pg_temp.pa_id(11);
update public.role_assignments set status='inactive' where user_id=pg_temp.pa_id(12);
set local role authenticated;
do $$begin
 assert not exists(select 1 from jsonb_array_elements(public.list_pilot_active_users('00000000-0000-4000-8000-000000000501')) x where x->>'id' in(pg_temp.pa_id(11)::text,pg_temp.pa_id(12)::text));
end$$;
-- Exact valid IDs never replace Admin authority. Assigned Master may manage
-- participant enrollment/Teams canonically, but cannot create/assign Cohorts.
do $$declare n integer;begin
 foreach n in array array[2,3,4,5,7,8,9] loop
  perform set_config('request.jwt.claim.sub',pg_temp.pa_id(n)::text,true);
  perform pg_temp.pa_denied('select public.list_pilot_active_users(''00000000-0000-4000-8000-000000000501'')');
  perform pg_temp.pa_denied(format('select public.assign_master_to_cohort(%L,%L)',pg_temp.pa('cohort'),pg_temp.pa_id(n)));
  perform pg_temp.pa_denied(format('select public.create_cohort(''00000000-0000-4000-8000-000000000601'',''00000000-0000-4000-8000-000000000602'',''Attack'',''2026-10-01'',null,%L,''active'',''{}'')',pg_temp.pa_id(2)));
 end loop;
 perform set_config('request.jwt.claim.sub',pg_temp.pa_id(3)::text,true);
 perform pg_temp.pa_denied(format('select public.enroll_user(%L,%L,''participant'',''active'')',pg_temp.pa('cohort'),pg_temp.pa_id(11)));
 perform pg_temp.pa_denied(format('select public.move_team_member(%L,%L,%L,null)',pg_temp.pa_id(4),pg_temp.pa('Team B','teamId'),pg_temp.pa('Team A','teamId')));
 perform set_config('request.jwt.claim.sub',pg_temp.pa_id(1)::text,true);
 perform pg_temp.pa_denied(format('select public.list_pilot_active_users(%L)',pg_temp.pa_id(100)));
 perform pg_temp.pa_denied(format('select public.list_pilot_active_users(%L)',pg_temp.pa_id(6)));
end$$;
reset role;
do $$begin
 assert (select count(*) from public.team_memberships where team_id=pg_temp.pa('Team A','teamId') and user_id=pg_temp.pa_id(4) and status='removed')=2,'stored history preserved';
 assert exists(select 1 from public.audit_events where actor_user_id=pg_temp.pa_id(1) and event_type='TEAM_CREATED' and entity_id=pg_temp.pa('Team A','teamId'));
 assert exists(select 1 from public.audit_events where actor_user_id=pg_temp.pa_id(1) and event_type='MEMBER_ADDED' and metadata->>'userId'=pg_temp.pa_id(4)::text);
 assert exists(select 1 from public.audit_events where actor_user_id=pg_temp.pa_id(1) and event_type='MEMBER_REMOVED' and metadata->>'userId'=pg_temp.pa_id(4)::text);
 assert exists(select 1 from public.audit_events where actor_user_id=pg_temp.pa_id(1) and event_type='MEMBER_MOVED' and metadata->>'userId'=pg_temp.pa_id(4)::text);
 assert not has_function_privilege('anon','public.list_pilot_active_users(uuid)','execute');
 assert not has_function_privilege('service_role','public.list_pilot_active_users(uuid)','execute');
 assert (select prosecdef and provolatile='s' and proconfig @> array['search_path=""'] from pg_proc where oid='public.list_pilot_active_users(uuid)'::regprocedure);
end$$;
-- Inactive organization and revoked Admin immediately deny future roster reads.
update public.organizations set status='inactive' where id='00000000-0000-4000-8000-000000000501';
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.pa_id(1)::text,true);
select pg_temp.pa_denied('select public.list_pilot_active_users(''00000000-0000-4000-8000-000000000501'')');
reset role;
update public.organizations set status='active' where id='00000000-0000-4000-8000-000000000501';
update public.role_assignments set status='inactive' where user_id=pg_temp.pa_id(1);
set local role authenticated;
select pg_temp.pa_denied('select public.list_pilot_active_users(''00000000-0000-4000-8000-000000000501'')');
reset role;
rollback;
\echo M15.28 canonical Admin setup/enrollment/Team/conflict/roster/privacy/audit PASS
