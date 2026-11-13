\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'create-team-'||n||'@example.test' from generate_series(3801,3815) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'create-team-%@example.test';
insert into public.organizations(id,name,slug,status) values('00000000-0000-4000-8000-000000003820','Other test organization','create-team-other','active');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
 ('00000000-0000-4000-8000-000000003801','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000003801'),
 ('00000000-0000-4000-8000-000000003808','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000003820','00000000-0000-4000-8000-000000003801'),
 ('00000000-0000-4000-8000-000000003804','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000003801'),
 ('00000000-0000-4000-8000-000000003805','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000003801');
create temporary table creation_cohorts(label text,id uuid);grant select,insert on creation_cohorts to authenticated;
create temporary table creation_results(label text,payload jsonb);grant select,insert on creation_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000003801',true);
insert into creation_cohorts values('A',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Creation A','2026-10-01',null,'00000000-0000-4000-8000-000000003802','planned','{}')->>'id')::uuid);
insert into creation_cohorts values('B',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Creation B','2026-10-01',null,'00000000-0000-4000-8000-000000003803','planned','{}')->>'id')::uuid);
insert into creation_results values('Admin',public.create_team((select id from creation_cohorts where label='A'),'Admin Team'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000003802',true);
insert into creation_results values('Master',public.create_team((select id from creation_cohorts where label='A'),'Team C'));
reset role;
do $$ declare r record; begin
 for r in select * from creation_results loop
  assert (select count(*) from jsonb_object_keys(r.payload))=3,'only required resource IDs returned';
  assert exists(select 1 from public.teams t join public.workspaces w on w.id=t.workspace_id join public.chat_channels ch on ch.team_id=t.id
   where t.id=(r.payload->>'teamId')::uuid and w.id=(r.payload->>'workspaceId')::uuid and ch.id=(r.payload->>'chatChannelId')::uuid
    and w.team_id=t.id and w.workspace_type='TEAM' and w.status='active' and w.visibility='private'
    and ch.channel_type='TEAM' and ch.workspace_id=w.id and ch.cohort_id=t.cohort_id and w.cohort_id=t.cohort_id
    and t.master_user_id='00000000-0000-4000-8000-000000003802' and t.status='created'),'atomic Team/Workspace/Chat consistent';
  assert not exists(select 1 from public.chat_memberships where chat_channel_id=(r.payload->>'chatChannelId')::uuid),'Master Chat membership deferred';
  assert not exists(select 1 from public.team_memberships where team_id=(r.payload->>'teamId')::uuid),'no unsolicited Team membership';
 end loop;
 assert to_regclass('public.audit_events') is not null,'audit foundation implemented in M5.12';
end $$;
set local role authenticated;
do $$ declare n integer; c uuid; begin
 select id into c from creation_cohorts where label='A';
 foreach n in array array[3803,3804,3805,3808] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  begin perform public.create_team(c,'Unauthorized Team');raise exception 'unauthorized creation';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000003802',true);
 begin perform public.create_team(c,'Project Team',null,null,'00000000-0000-4000-8000-000000009999');raise exception 'Project created before M6';exception when feature_not_supported then null;end;
 begin perform public.create_team('00000000-0000-4000-8000-000000009999','Missing cohort');raise exception 'missing cohort leaked';exception when insufficient_privilege then null;end;
 begin perform public.create_team((select id from creation_cohorts where label='B'),'Unrelated cohort');raise exception 'cohort spoofing accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Auth identity without a platform profile is not an eligible Team Lead.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000003816','missing-profile@example.test');
-- Approved Team Lead eligibility, contextual authority and cross-Team policy.
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
 select c.id,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 case when n=3814 then 'instructor'::public.enrollment_role else 'participant'::public.enrollment_role end,
 case when n=3810 then 'invited'::public.enrollment_status else 'active'::public.enrollment_status end
 from creation_cohorts c cross join generate_series(3806,3814) n where c.label='A' and n<>3808;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000003815','participant','active' from creation_cohorts where label='B';
update public.enrollments set status=case right(user_id::text,4) when '3811' then 'completed'::public.enrollment_status when '3812' then 'withdrawn'::public.enrollment_status else 'removed'::public.enrollment_status end
 where right(user_id::text,4) in ('3811','3812','3813');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
 ('00000000-0000-4000-8000-000000003806','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000003801');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000003802',true);
insert into creation_results values('Lead',public.create_team((select id from creation_cohorts where label='A'),'Lead Team',null,'00000000-0000-4000-8000-000000003806'));
insert into creation_results values('Lead second Team',public.create_team((select id from creation_cohorts where label='A'),'Lead Second Team',null,'00000000-0000-4000-8000-000000003806'));
do $$ declare n integer; begin
 foreach n in array array[3810,3811,3812,3813,3814,3815,3816,9999] loop
  begin perform public.create_team((select id from creation_cohorts where label='A'),'Invalid Lead',null,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid);
   raise exception 'ineligible Lead accepted';exception when invalid_parameter_value then null;end;
 end loop;
end $$;
reset role;
do $$ declare state public.account_status; begin
 foreach state in array array['invited','suspended','archived']::public.account_status[] loop
  update public.users set account_status=state where id='00000000-0000-4000-8000-000000003807';
  begin perform public.create_team((select id from creation_cohorts where label='A'),'Inactive Lead',null,'00000000-0000-4000-8000-000000003807');
   raise exception 'inactive Lead accepted';exception when invalid_parameter_value then null;end;
 end loop;
 update public.users set account_status='active' where id='00000000-0000-4000-8000-000000003807';
 assert not exists(select 1 from public.teams where name in ('Invalid Lead','Inactive Lead')),'invalid Lead leaves no Team';
 assert not exists(select 1 from public.teams t join creation_results r on t.id=(r.payload->>'teamId')::uuid where r.label in ('Admin','Master') and t.team_lead_user_id is not null),'omitted Lead remains null';
 assert (select count(*) from public.team_memberships m join creation_results r on m.team_id=(r.payload->>'teamId')::uuid where r.label like 'Lead%' and m.user_id='00000000-0000-4000-8000-000000003806' and m.membership_role='team_lead' and m.status='active' and m.joined_at is not null and m.left_at is null and m.removed_by is null and m.added_by='00000000-0000-4000-8000-000000003802')=2,'Lead lifecycle and cross-Team eligibility';
 assert (select count(*) from public.teams t join creation_results r on t.id=(r.payload->>'teamId')::uuid where r.label like 'Lead%' and t.team_lead_user_id='00000000-0000-4000-8000-000000003806')=2,'Lead references synchronized';
 assert not exists(select 1 from public.chat_memberships m join creation_results r on m.chat_channel_id=(r.payload->>'chatChannelId')::uuid where r.label like 'Lead%'),'no implicit Chat membership';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000003806',true);
do $$ begin
 begin perform public.create_team((select id from creation_cohorts where label='A'),'Lead escalation');raise exception 'Lead grants platform authority';exception when insufficient_privilege then null;end;
 begin update public.team_memberships set membership_role='mentor' where user_id=auth.uid();raise exception 'Lead grants membership management';exception when insufficient_privilege then null;end;
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values((select (payload->>'teamId')::uuid from creation_results where label='Lead'),auth.uid(),'member',now(),auth.uid());raise exception 'Lead can add members';exception when insufficient_privilege then null;end;
 begin update public.teams set master_user_id=auth.uid();raise exception 'Lead can change Master';exception when insufficient_privilege then null;end;
 assert (select count(*) from public.workspaces where workspace_type='TEAM')=2,'M5.5 grants only eligible active Lead memberships Workspace access';
 assert not exists(select 1 from public.chat_channels),'M5.4 Lead provisioning grants no implicit Chat membership';
 assert not exists(select 1 from public.workspaces where workspace_type='PERSONAL' and owner_user_id<>auth.uid()),'Lead cannot expose private content';
end $$;
reset role;
-- Only this disposable test transaction installs failure triggers; no production hooks.
create function pg_temp.fail_team_creation() returns trigger language plpgsql as $$ begin
 if current_setting('fici_test.failure_table',true)=tg_table_name or (tg_op='UPDATE' and current_setting('fici_test.failure_table',true)='lead_assignment') then raise exception 'Injected creation failure';end if;
 return new;
end $$;
create trigger creation_failure_workspace before insert on public.workspaces for each row execute function pg_temp.fail_team_creation();
create trigger creation_failure_team before insert on public.teams for each row execute function pg_temp.fail_team_creation();
create trigger creation_failure_chat before insert on public.chat_channels for each row execute function pg_temp.fail_team_creation();
create trigger creation_failure_membership before insert on public.team_memberships for each row execute function pg_temp.fail_team_creation();
create trigger creation_failure_lead before update on public.teams for each row execute function pg_temp.fail_team_creation();
create temporary table creation_counts as select (select count(*) from public.team_memberships) memberships,(select count(*) from public.teams) teams,(select count(*) from public.workspaces) workspaces,(select count(*) from public.chat_channels) channels;
grant select on creation_counts to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000003802',true);
do $$ declare table_name text; begin
 foreach table_name in array array['workspaces','teams','chat_channels','team_memberships','lead_assignment'] loop
  perform set_config('fici_test.failure_table',table_name,true);
  begin perform public.create_team((select id from creation_cohorts where label='A'),'Forced Failure',null,'00000000-0000-4000-8000-000000003806');raise exception 'failure not injected';
   exception when raise_exception then if sqlerrm<>'Injected creation failure' then raise;end if;end;
 end loop;
 perform set_config('fici_test.failure_table','',true);
end $$;
reset role;
do $$ begin
 assert (select count(*) from public.team_memberships)=(select memberships from creation_counts),'failed creation leaves no membership';
 assert (select count(*) from public.teams)=(select teams from creation_counts),'failed creation leaves no Team';
 assert (select count(*) from public.workspaces)=(select workspaces from creation_counts),'failed creation leaves no orphan Workspace';
 assert (select count(*) from public.chat_channels)=(select channels from creation_counts),'failed creation leaves no orphan Chat';
 assert not exists(select 1 from public.teams where name in ('Unauthorized Team','Project Team','Forced Failure')),'negative calls persist no resource';
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.create_team(uuid,text,text,uuid,uuid)'::regprocedure),'narrow fixed-path definer';
 assert not has_function_privilege('anon','public.create_team(uuid,text,text,uuid,uuid)','EXECUTE'),'anonymous RPC denied';
 assert not has_function_privilege('service_role','public.create_team(uuid,text,text,uuid,uuid)','EXECUTE'),'no generic service bypass';
end $$;
set constraints all immediate;
rollback;
\echo AT-TEAM-001 M5.4 core PASS - Admin/Master scope, atomic Team/Workspace/Chat, Project rejection and failure rollback

