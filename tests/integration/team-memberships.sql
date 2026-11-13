\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'membership-'||n||'@example.test' from generate_series(2601,2604) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'membership-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000002601','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000002601');
create temporary table membership_cohort(id uuid);grant select,insert on membership_cohort to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000002601',true);
insert into membership_cohort select (public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Membership fixture','2026-10-01',null,'00000000-0000-4000-8000-000000002602','planned','{}')->>'id')::uuid;
reset role;
insert into public.workspaces(id,workspace_type,name,cohort_id,created_by,updated_by)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'TEAM','Membership fixture',(select id from membership_cohort),'00000000-0000-4000-8000-000000002601','00000000-0000-4000-8000-000000002601' from generate_series(2701,2702) n;
insert into public.teams(id,cohort_id,name,master_user_id,workspace_id,created_by)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,(select id from membership_cohort),'Membership Team '||n,'00000000-0000-4000-8000-000000002602',('00000000-0000-4000-8000-'||lpad((n-100)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000002601' from generate_series(2801,2802) n;
insert into public.team_memberships(id,team_id,user_id,membership_role,joined_at,added_by) values
 ('00000000-0000-4000-8000-000000002901','00000000-0000-4000-8000-000000002801','00000000-0000-4000-8000-000000002603','member','2026-01-01','00000000-0000-4000-8000-000000002601'),
 ('00000000-0000-4000-8000-000000002902','00000000-0000-4000-8000-000000002802','00000000-0000-4000-8000-000000002603','member','2026-01-01','00000000-0000-4000-8000-000000002601'),
 ('00000000-0000-4000-8000-000000002903','00000000-0000-4000-8000-000000002801','00000000-0000-4000-8000-000000002604','team_lead','2026-01-01','00000000-0000-4000-8000-000000002601'),
 ('00000000-0000-4000-8000-000000002904','00000000-0000-4000-8000-000000002801','00000000-0000-4000-8000-000000002601','mentor','2026-01-01','00000000-0000-4000-8000-000000002601');
do $$ declare m uuid:='00000000-0000-4000-8000-000000002901'; begin
 assert (select count(*) from public.team_memberships where user_id='00000000-0000-4000-8000-000000002603' and status='active')=2,'no cross-Team exclusivity invented';
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) select team_id,user_id,'mentor',joined_at,added_by from public.team_memberships where id=m;raise exception 'duplicate active membership';exception when unique_violation then null;end;
 begin update public.team_memberships set joined_at=joined_at+interval '1 hour' where id=m;raise exception 'join timestamp changed';exception when check_violation then null;end;
 begin update public.team_memberships set user_id='00000000-0000-4000-8000-000000002604' where id=m;raise exception 'membership identity changed';exception when check_violation then null;end;
 begin update public.team_memberships set status='inactive' where id=m;raise exception 'invalid membership status';exception when invalid_text_representation then null;end;
 begin update public.team_memberships set membership_role='admin' where id=m;raise exception 'invalid membership role';exception when invalid_text_representation then null;end;
 begin update public.team_memberships set left_at='2026-02-01' where id=m;raise exception 'active left_at';exception when check_violation then null;end;
 begin update public.team_memberships set removed_by=added_by where id=m;raise exception 'active removed_by';exception when check_violation then null;end;
 begin update public.team_memberships set status='removed' where id=m;raise exception 'missing removal metadata';exception when check_violation then null;end;
 begin update public.team_memberships set status='removed',left_at='2026-02-01' where id=m;raise exception 'missing remover';exception when check_violation then null;end;
 begin update public.team_memberships set status='removed',removed_by=added_by where id=m;raise exception 'missing departure time';exception when check_violation then null;end;
 begin update public.team_memberships set status='removed',left_at='2025-12-31',removed_by=added_by where id=m;raise exception 'negative membership duration';exception when check_violation then null;end;
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values('00000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000002602','member',now(),'00000000-0000-4000-8000-000000002601');raise exception 'invalid Team FK';exception when foreign_key_violation then null;end;
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values('00000000-0000-4000-8000-000000002801','00000000-0000-4000-8000-000000009999','member',now(),'00000000-0000-4000-8000-000000002601');raise exception 'invalid user FK';exception when foreign_key_violation then null;end;
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values('00000000-0000-4000-8000-000000002801','00000000-0000-4000-8000-000000002602','member',now(),'00000000-0000-4000-8000-000000009999');raise exception 'invalid adding actor FK';exception when foreign_key_violation then null;end;
 begin update public.team_memberships set status='removed',left_at='2026-02-01',removed_by='00000000-0000-4000-8000-000000009999' where id=m;raise exception 'invalid removing actor FK';exception when foreign_key_violation then null;end;
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values('00000000-0000-4000-8000-000000002801','00000000-0000-4000-8000-000000002602','member',null,'00000000-0000-4000-8000-000000002601');raise exception 'missing join time';exception when not_null_violation then null;end;
end $$;
update public.team_memberships set status='removed',left_at='2026-02-01',removed_by='00000000-0000-4000-8000-000000002601' where id='00000000-0000-4000-8000-000000002901';
do $$ declare m uuid:='00000000-0000-4000-8000-000000002901'; begin
 assert exists(select 1 from public.team_memberships where id=m and status='removed' and joined_at='2026-01-01'),'removed history preserved';
 assert not exists(select 1 from public.team_memberships where id=m and status='active' and left_at is null),'removed never active';
 begin update public.team_memberships set status='active',left_at=null,removed_by=null where id=m;raise exception 'historical reactivation';exception when check_violation then null;end;
 begin update public.team_memberships set membership_role='mentor' where id=m;raise exception 'historical role overwritten';exception when check_violation then null;end;
 begin update public.team_memberships set left_at='2026-03-01' where id=m;raise exception 'historical removal overwritten';exception when check_violation then null;end;
 begin delete from public.team_memberships where id=m;raise exception 'historical deletion';exception when check_violation then null;end;
end $$;
insert into public.team_memberships(id,team_id,user_id,membership_role,joined_at,added_by) values('00000000-0000-4000-8000-000000002905','00000000-0000-4000-8000-000000002801','00000000-0000-4000-8000-000000002603','member','2026-03-01','00000000-0000-4000-8000-000000002601');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000002603',true);
do $$ begin
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values('00000000-0000-4000-8000-000000002801',auth.uid(),'team_lead',now(),auth.uid());raise exception 'Student self-insert';exception when insufficient_privilege then null;end;
 begin update public.team_memberships set status='removed',left_at=now(),removed_by=auth.uid();raise exception 'client UPDATE';exception when insufficient_privilege then null;end;
 begin delete from public.team_memberships;raise exception 'client DELETE';exception when insufficient_privilege then null;end;
end $$;
reset role;
grant select,insert on public.team_memberships to authenticated;
set local role authenticated;
do $$ begin
 assert (select count(*) from public.team_memberships)=0,'RLS denies enumeration even with accidental SELECT grant';
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values('00000000-0000-4000-8000-000000002802','00000000-0000-4000-8000-000000002604','member',now(),auth.uid());raise exception 'RLS INSERT bypass';exception when insufficient_privilege then null;end;
 assert (select count(*) from public.workspaces where workspace_type='TEAM')=0,'membership schema does not prematurely grant Workspace access';
end $$;
reset role;
revoke select,insert on public.team_memberships from authenticated;
do $$ begin
 assert (select count(*) from public.team_memberships where team_id='00000000-0000-4000-8000-000000002801' and user_id='00000000-0000-4000-8000-000000002603')=2,'rejoin uses new row alongside retained history';
 assert (select count(*) from public.team_memberships where team_id='00000000-0000-4000-8000-000000002801' and user_id='00000000-0000-4000-8000-000000002603' and status='active')=1,'only one active rejoin';
 assert (select relrowsecurity from pg_class where oid='public.team_memberships'::regclass),'membership RLS enabled';
 assert not has_table_privilege('authenticated','public.team_memberships','SELECT,INSERT,UPDATE,DELETE'),'client access denied';
 assert not has_table_privilege('anon','public.team_memberships','SELECT,INSERT,UPDATE,DELETE'),'anonymous denied';
 assert (select not prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.preserve_team_membership_history()'::regprocedure),'history guard is safe invoker';
end $$;
rollback;
\echo M5.2 membership lifecycle, immutable history, rejoin uniqueness, FKs and direct client/RLS denial PASS
