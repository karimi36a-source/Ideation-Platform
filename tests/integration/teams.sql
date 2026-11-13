\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'team-'||n||'@example.test' from generate_series(2101,2105) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'team-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000002101','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000002101');
create temporary table team_cohorts(label text,id uuid);grant select,insert on team_cohorts to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000002101',true);
insert into team_cohorts values('A',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Team A fixture','2026-10-01',null,'00000000-0000-4000-8000-000000002102','planned','{}')->>'id')::uuid);
insert into team_cohorts values('B',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Team B fixture','2026-10-01',null,'00000000-0000-4000-8000-000000002103','planned','{}')->>'id')::uuid);
reset role;
insert into public.workspaces(id,workspace_type,name,cohort_id,created_by,updated_by)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'TEAM','Team fixture',(select id from team_cohorts where label=case when n=2203 then 'B' else 'A' end),'00000000-0000-4000-8000-000000002101','00000000-0000-4000-8000-000000002101' from (values(2201),(2203),(2205)) v(n);
insert into public.workspaces(id,workspace_type,name,owner_user_id,cohort_id,created_by,updated_by) values('00000000-0000-4000-8000-000000002202','PERSONAL','Private fixture','00000000-0000-4000-8000-000000002101',(select id from team_cohorts where label='A'),'00000000-0000-4000-8000-000000002101','00000000-0000-4000-8000-000000002101');
insert into public.workspaces(id,workspace_type,name,created_by,updated_by) values('00000000-0000-4000-8000-000000002204','TEAM','Unscoped','00000000-0000-4000-8000-000000002101','00000000-0000-4000-8000-000000002101');
insert into public.teams(id,cohort_id,name,master_user_id,workspace_id,created_by) values('00000000-0000-4000-8000-000000002301',(select id from team_cohorts where label='A'),'Official Team','00000000-0000-4000-8000-000000002102','00000000-0000-4000-8000-000000002201','00000000-0000-4000-8000-000000002101');
update public.workspaces set team_id='00000000-0000-4000-8000-000000002301' where id='00000000-0000-4000-8000-000000002201';
do $$ declare w uuid; target uuid; mode integer; c uuid; begin
 select id into c from team_cohorts where label='A';
 assert exists(select 1 from public.teams t join public.workspaces w on w.id=t.workspace_id where t.cohort_id=c and w.cohort_id=c and w.workspace_type='TEAM'),'Team cohort/Workspace linkage';
 assert enum_range(null::public.team_status)::text[]=array['created','active','completed','archived'],'exact approved lifecycle vocabulary';
 begin update public.teams set status='invalid' where id='00000000-0000-4000-8000-000000002301';raise exception 'invalid status';exception when invalid_text_representation then null;end;
 begin update public.teams set team_lead_user_id='00000000-0000-4000-8000-000000009999' where id='00000000-0000-4000-8000-000000002301';raise exception 'invalid Team Lead identity';exception when foreign_key_violation then null;end;
 begin update public.teams set cohort_id='00000000-0000-4000-8000-000000009999' where id='00000000-0000-4000-8000-000000002301';raise exception 'invalid Cohort';exception when check_violation or foreign_key_violation then null;end;
 foreach w in array array['00000000-0000-4000-8000-000000002202','00000000-0000-4000-8000-000000002203','00000000-0000-4000-8000-000000002204','00000000-0000-4000-8000-000000009999']::uuid[] loop
  begin insert into public.teams(cohort_id,name,master_user_id,workspace_id,created_by) values(c,'Bad Workspace','00000000-0000-4000-8000-000000002102',w,'00000000-0000-4000-8000-000000002101');raise exception 'invalid Workspace accepted';exception when foreign_key_violation then null;end;
 end loop;
 foreach target in array array['00000000-0000-4000-8000-000000002103','00000000-0000-4000-8000-000000002104','00000000-0000-4000-8000-000000009999']::uuid[] loop
  begin insert into public.teams(cohort_id,name,master_user_id,workspace_id,created_by) values(c,'Bad Master',target,'00000000-0000-4000-8000-000000002205','00000000-0000-4000-8000-000000002101');raise exception 'invalid Master accepted';exception when check_violation then null;end;
 end loop;
 for mode in 1..3 loop
  update public.role_assignments set status=case when mode=1 then 'inactive'::public.role_assignment_status else 'active'::public.role_assignment_status end, starts_at=case when mode=2 then now()+interval '1 day' else now()-interval '2 days' end,ends_at=case when mode=3 then now()-interval '1 day' else null end where user_id='00000000-0000-4000-8000-000000002102' and cohort_id=c;
  begin insert into public.teams(cohort_id,name,master_user_id,workspace_id,created_by) values(c,'Invalid timing','00000000-0000-4000-8000-000000002102','00000000-0000-4000-8000-000000002205','00000000-0000-4000-8000-000000002101');raise exception 'invalid assignment accepted';exception when check_violation then null;end;
 end loop;
 update public.role_assignments set status='active',starts_at=now()-interval '1 day',ends_at=null where user_id='00000000-0000-4000-8000-000000002102' and cohort_id=c;
 update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000002102';
 begin insert into public.teams(cohort_id,name,master_user_id,workspace_id,created_by) values(c,'Suspended Master','00000000-0000-4000-8000-000000002102','00000000-0000-4000-8000-000000002205','00000000-0000-4000-8000-000000002101');raise exception 'suspended Master accepted';exception when check_violation then null;end;
 update public.users set account_status='active' where id='00000000-0000-4000-8000-000000002102';
 begin update public.workspaces set workspace_type='MASTER' where id='00000000-0000-4000-8000-000000002201';raise exception 'Workspace type drift';exception when foreign_key_violation then null;end;
 begin update public.workspaces set cohort_id=(select id from team_cohorts where label='B') where id='00000000-0000-4000-8000-000000002201';raise exception 'Workspace cohort drift';exception when foreign_key_violation then null;end;
 begin update public.teams set master_user_id='00000000-0000-4000-8000-000000002103' where id='00000000-0000-4000-8000-000000002301';raise exception 'unrelated reassignment';exception when check_violation then null;end;
 begin insert into public.teams(cohort_id,name,master_user_id,workspace_id,created_by) values(c,'Workspace reuse','00000000-0000-4000-8000-000000002102','00000000-0000-4000-8000-000000002201','00000000-0000-4000-8000-000000002101');raise exception 'Workspace shared by two Teams';exception when unique_violation then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000002104',true);
do $$ begin
 begin insert into public.teams(cohort_id,name,master_user_id,workspace_id,created_by) values((select id from team_cohorts where label='A'),'Client attack','00000000-0000-4000-8000-000000002102','00000000-0000-4000-8000-000000002205','00000000-0000-4000-8000-000000002104');raise exception 'client INSERT';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Even an accidental SELECT grant must not expose Teams before membership policy.
grant select on public.teams to authenticated;
set local role authenticated;
do $$ begin assert (select count(*) from public.teams)=0,'RLS default deny';end $$;
reset role;
-- Preserve the M5.5 scoped operational SELECT grant.
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000002102';
update public.teams set status='archived',archived_at=now() where id='00000000-0000-4000-8000-000000002301';
do $$ begin
 assert exists(select 1 from public.teams where id='00000000-0000-4000-8000-000000002301' and status='archived' and archived_at is not null),'archive preserves Team after Master revocation';
 assert (select relrowsecurity from pg_class where oid='public.teams'::regclass),'Team RLS enabled';
 assert not has_table_privilege('authenticated','public.teams','INSERT,UPDATE,DELETE,TRUNCATE'),'no broad client mutation privileges';
 assert not has_table_privilege('anon','public.teams','SELECT,INSERT,UPDATE,DELETE'),'anonymous denied';
 assert (select not prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.validate_team_master_binding()'::regprocedure),'safe invoker binding trigger';
end $$;
set constraints all immediate;
rollback;
\echo M5.1 Team schema, Master validity, Workspace integrity, history and client/RLS denial PASS
