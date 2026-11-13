reset role;
-- A new scenario only: production policies, grants and authorization helpers
-- remain unchanged. IDs are intentionally known to every attacker fixture.
create temporary table notification_rls_cases(case_id integer primary key);
create temporary table notification_rls_ids(bucket text,id uuid);
create temporary table notification_rls_state(label text,payload jsonb);
grant select,insert on notification_rls_cases,notification_rls_ids,notification_rls_state to authenticated,anon,service_role;
create function pg_temp.nr_record(n integer) returns void language plpgsql as $$begin
 if n>0 then insert into notification_rls_cases values(n) on conflict do nothing;end if;
end $$;
create function pg_temp.nr_denied(n integer,command text,expected text default '42501') returns void language plpgsql as $$begin
 begin execute command;raise exception 'Notification attack unexpectedly succeeded';
 exception when others then if sqlstate<>expected then raise;end if;end;
 perform pg_temp.nr_record(n);
end $$;
create function pg_temp.nr_hidden(n integer,command text) returns void language plpgsql as $$declare total bigint;begin
 execute 'select count(*) from ('||command||') q' into total;assert total=0,'notification disclosure';perform pg_temp.nr_record(n);
end $$;
create function pg_temp.nr_own_id() returns uuid language sql as $$select id from notification_rls_ids where bucket='own' order by id limit 1$$;
-- Distinct canonical membership makes 6007 a same-Team peer as well as a
-- same-Cohort participant. It grants no notification ownership.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006007','member');
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id)
 select '00000000-0000-4000-8000-000000006004','RLS_TEST','Private notice','A safe summary.','ARTIFACT',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team') from generate_series(1,100) returning id
) insert into notification_rls_ids select 'own',id from inserted;
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body)
 select '00000000-0000-4000-8000-000000006006','RLS_TEST','Other recipient','A safe summary.' from generate_series(1,2000) returning id
) insert into notification_rls_ids select 'other',id from inserted;
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id)
 select '00000000-0000-4000-8000-000000006006','RLS_TEST','Stored reference','A safe summary.','ARTIFACT',(payload->>'artifactId')::uuid from submitted_fixtures where label='Team' returning id
) insert into notification_rls_ids select 'private-target',id from inserted;
-- A real Share, then revocation, proves recipient history is independent of a
-- recipient's current access to the referenced Share/Snapshot.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into notification_rls_state select 'share',public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',payload->>'initialVersionId','destinationType','TEAM','destinationId',(select payload->>'teamId' from acceptance_teams where label='A'),'permissionLevel','VIEW','shareMode','SNAPSHOT')) from submitted_fixtures where label='Personal';
reset role;
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id)
 select '00000000-0000-4000-8000-000000006005','ARTIFACT_SHARED','Artifact shared','A safe summary.','share',(payload->>'id')::uuid from notification_rls_state where label='share' returning id
) insert into notification_rls_ids select 'revoked-history',id from inserted;
create temporary table notification_rls_before as select id,to_jsonb(n)-'read_at' payload from public.notifications n;
analyze public.notifications;
-- Grants AND policy predicates: both are necessary. The permissive own-read
-- policy supplies a grant; its restrictive twin prevents future OR broadening.
do $$declare f record;begin
 assert (select relrowsecurity from pg_class where oid='public.notifications'::regclass);
 assert has_table_privilege('authenticated','public.notifications','select');
 assert not has_table_privilege('authenticated','public.notifications','insert');
 assert not has_table_privilege('authenticated','public.notifications','update');
 assert not has_table_privilege('authenticated','public.notifications','delete');
 assert not has_table_privilege('service_role','public.notifications','select');
 assert not has_table_privilege('service_role','public.notifications','insert');
 assert exists(select 1 from pg_policy where polrelid='public.notifications'::regclass and polname='notifications_own_read' and polpermissive);
 assert exists(select 1 from pg_policy where polrelid='public.notifications'::regclass and polname='notifications_own_read_guard' and not polpermissive);
 for f in select p.* from pg_proc p where p.oid in ('public.create_domain_notification(jsonb)'::regprocedure,'public.mark_notification_read(uuid)'::regprocedure,'private.notification_team_recipient(uuid,uuid)'::regprocedure) loop
  assert f.prosecdef and 'search_path=""'=any(f.proconfig),'fixed empty search_path';
  assert not exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE'),'no PUBLIC function execution';
 end loop;
 assert has_function_privilege('service_role','public.create_domain_notification(jsonb)','execute');
 assert not has_function_privilege('authenticated','public.create_domain_notification(jsonb)','execute');
 assert not has_function_privilege('anon','public.create_domain_notification(jsonb)','execute');
 assert has_function_privilege('authenticated','public.mark_notification_read(uuid)','execute');
 assert not has_function_privilege('anon','public.mark_notification_read(uuid)','execute');
 assert not has_function_privilege('service_role','public.mark_notification_read(uuid)','execute');
 assert not has_function_privilege('authenticated','private.notification_team_recipient(uuid,uuid)','execute');
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare plan jsonb;begin
 assert (select count(*) from public.notifications where id in(select id from notification_rls_ids where bucket='own'))=100;
 perform pg_temp.nr_record(1);
 execute 'explain (format json) select id from public.notifications where recipient_user_id=''00000000-0000-4000-8000-000000006004'' order by created_at desc,id desc limit 50' into plan;
 assert plan::text like '%notifications_recipient_time%','chronological recipient index used';
 execute 'explain (format json) select id from public.notifications where recipient_user_id=''00000000-0000-4000-8000-000000006004'' and read_at is null order by created_at desc,id desc limit 50' into plan;
 assert plan::text like '%notifications_recipient_%','recipient/unread index available to actual query';
 assert exists(select 1 from public.notifications where notification_type='MEMBER_ADDED' and recipient_user_id=auth.uid()),'real M5 history remains readable';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.nr_hidden(2,format('select id from public.notifications where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_hidden(4,'select id from public.notifications where recipient_user_id=''00000000-0000-4000-8000-000000006004''');
select pg_temp.nr_denied(13,format('update public.notifications set read_at=now() where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_denied(23,format('select public.mark_notification_read(%L)',pg_temp.nr_own_id()));
select pg_temp.nr_denied(25,format('delete from public.notifications where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_hidden(26,'select id from public.notifications where recipient_user_id in (''00000000-0000-4000-8000-000000006004'',''00000000-0000-4000-8000-000000006005'')');
do $$begin
 assert exists(select 1 from public.notifications where id in(select id from notification_rls_ids where bucket='private-target'));
 assert not exists(select 1 from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'));
 perform pg_temp.nr_record(28);
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
select pg_temp.nr_hidden(3,format('select id from public.notifications where id=%L',pg_temp.nr_own_id()));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.nr_hidden(5,format('select id from public.notifications where id=%L',pg_temp.nr_own_id()));
do $$begin
 assert exists(select 1 from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team')),'independent linked entity access precondition';
 assert not exists(select 1 from public.notifications where recipient_user_id='00000000-0000-4000-8000-000000006004' and entity_id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'));
 perform pg_temp.nr_record(27);
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.nr_hidden(6,format('select id from public.notifications where id=%L',pg_temp.nr_own_id()));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select pg_temp.nr_hidden(7,format('select id from public.notifications where id=%L',pg_temp.nr_own_id()));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
select pg_temp.nr_hidden(7,format('select id from public.notifications where id=%L',pg_temp.nr_own_id()));
reset role;
set local role anon;
select pg_temp.nr_denied(8,'select id from public.notifications');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare code text;begin
 foreach code in array array['COMMENT_RECEIVED','APPROVAL','ARTIFACT_APPROVED','REVISION_REQUESTED','SUBMISSION_RECEIVED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','ARTIFACT_SHARED'] loop
  perform pg_temp.nr_denied(9,format('insert into public.notifications(recipient_user_id,notification_type) values(''00000000-0000-4000-8000-000000006004'',%L)',code));
 end loop;
end $$;
select pg_temp.nr_denied(10,'insert into public.notifications(recipient_user_id,notification_type) values(''00000000-0000-4000-8000-000000006004'',''MEMBER_ADDED'')');
select pg_temp.nr_denied(11,'insert into public.notifications(recipient_user_id,notification_type) values(''00000000-0000-4000-8000-000000006006'',''MEMBER_ADDED'')');
select pg_temp.nr_denied(12,'insert into public.notifications(recipient_user_id,notification_type,title,body) values(''00000000-0000-4000-8000-000000006006'',''ARTIFACT_APPROVED'',''Forged'',''Forged'')');
select pg_temp.nr_denied(0,'select public.create_domain_notification(''{}'')');
select pg_temp.nr_denied(0,'select private.notification_team_recipient(null,null)');
insert into notification_rls_state values('first-read',public.mark_notification_read(pg_temp.nr_own_id()));
do $$begin
 assert exists(select 1 from public.notifications where id=pg_temp.nr_own_id() and read_at is not null);perform pg_temp.nr_record(21);
 assert public.mark_notification_read(pg_temp.nr_own_id())=(select payload from notification_rls_state where label='first-read');perform pg_temp.nr_record(22);
end $$;
select pg_temp.nr_denied(14,format('update public.notifications set title=''Forged'' where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_denied(15,format('update public.notifications set body=''Forged'' where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_denied(16,format('update public.notifications set notification_type=''ARTIFACT_APPROVED'' where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_denied(17,format('update public.notifications set entity_id=''ffffffff-ffff-4fff-8fff-ffffffffffff'' where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_denied(18,format('update public.notifications set recipient_user_id=''00000000-0000-4000-8000-000000006006'' where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_denied(19,format('update public.notifications set read_at=null where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_denied(20,format('update public.notifications set read_at=''2000-01-01'' where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_denied(24,format('delete from public.notifications where id=%L',pg_temp.nr_own_id()));
select pg_temp.nr_denied(0,format('update public.notifications set entity_type=''team'',created_at=now(),metadata=''{}'',idempotency_digest=null,request_fingerprint=null where id=%L',pg_temp.nr_own_id()));
reset role;
-- A future permissive SELECT policy cannot OR around the restrictive guard.
-- This test-only policy is removed immediately, never shipped in a migration.
create policy test_notification_broadening_attack on public.notifications for select to authenticated using(true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.nr_hidden(0,'select id from public.notifications where recipient_user_id=''00000000-0000-4000-8000-000000006004''');
reset role;
drop policy test_notification_broadening_attack on public.notifications;
set local role service_role;
select pg_temp.nr_denied(0,'select id from public.notifications');
select pg_temp.nr_denied(0,'select public.create_domain_notification(''{"notificationId":"ffffffff-ffff-4fff-8fff-ffffffffffff"}'')','22023');
reset role;
-- Revoking the actual Share does not erase the exact recipient's notification.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.revoke_share(jsonb_build_object('shareId',payload->>'id')) from notification_rls_state where label='share';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert exists(select 1 from public.notifications where id in(select id from notification_rls_ids where bucket='revoked-history'));
 assert (public.resolve_shared_entity_access(jsonb_build_object('shareId',(select payload->>'id' from notification_rls_state where label='share')))->>'allowed')='false';
end $$;
select public.mark_notification_read(id) from notification_rls_ids where bucket='revoked-history';
-- Removing A1 from Team A changes future source access, never history ownership.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','Disposable RLS history check');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert (select count(*) from public.notifications where id in(select id from notification_rls_ids where bucket='own'))=100;
 assert exists(select 1 from public.notifications where notification_type='MEMBER_ADDED' and recipient_user_id=auth.uid()),'M5 original history retained after removal';
 assert not exists(select 1 from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team')),'history does not reopen source';
 assert public.mark_notification_read(pg_temp.nr_own_id())=(select payload from notification_rls_state where label='first-read');
end $$;
reset role;
do $$begin
 assert (select count(*) from notification_rls_cases)=28,'entire required attack matrix executed';
 assert not exists(select n from generate_series(1,28) n except select case_id from notification_rls_cases),'no missing matrix cases';
 assert not exists(select 1 from notification_rls_before b left join public.notifications n on n.id=b.id where n.id is null or to_jsonb(n)-'read_at' is distinct from b.payload),'original ownership/content/history retained';
 assert not exists(select 1 from pg_policy where polname='test_notification_broadening_attack' and polrelid='public.notifications'::regclass),'temporary adversarial policy cleaned';
end $$;
rollback;
select 'M15.6 notification RLS 28/28 attacks + grants/RPC/search_path/indexes/history/linked independence PASS';
