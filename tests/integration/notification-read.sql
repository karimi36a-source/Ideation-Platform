reset role;
do $$begin assert not exists(select 1 from public.shares where id='ffffffff-ffff-4fff-8fff-ffffffffffff'),'disposable missing target precondition';end $$;
create temporary table read_notification_ids(label text,id uuid);
grant select on read_notification_ids to authenticated;
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id)
 values('00000000-0000-4000-8000-000000006004','MEMBER_ADDED','Historical notice','A safe summary.','share','ffffffff-ffff-4fff-8fff-ffffffffffff') returning id
) insert into read_notification_ids select 'own',id from inserted;
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body)
 values('00000000-0000-4000-8000-000000006004','LEGACY_PILOT_CODE','Another notice','A safe summary.') returning id
) insert into read_notification_ids select 'unread',id from inserted;
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id)
 select '00000000-0000-4000-8000-000000006006','ARTIFACT_SHARED','Historical notice','A safe summary.','ARTIFACT',(payload->>'artifactId')::uuid from submitted_fixtures where label='Team' returning id
) insert into read_notification_ids select 'inaccessible-target',id from inserted;
create temporary table read_history_before as select id,to_jsonb(n)-'read_at' payload from public.notifications n;
create temporary table read_results(label text,payload jsonb);
grant select,insert on read_results to authenticated;
create function pg_temp.read_bad(statement0 text,expected text default '42501') returns void language plpgsql as $$begin
 execute statement0;raise exception 'Read-state attack succeeded';
exception when others then if sqlstate<>expected then raise;end if;end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into read_results select 'first',public.mark_notification_read(id) from read_notification_ids where label='own';
insert into read_results select 'retry',public.mark_notification_read(id) from read_notification_ids where label='own';
do $$begin
 assert (select payload from read_results where label='first')=(select payload from read_results where label='retry'),'retry preserves original read_at';
 assert exists(select 1 from public.notifications where id=(select id from read_notification_ids where label='own') and read_at is not null and read_at>=created_at and read_at<=clock_timestamp()),'server read timestamp and retained row';
 assert (select count(*) from public.notifications where id in(select id from read_notification_ids where label in ('own','unread')))=2,'normal listing retains both rows';
 assert (select count(*) from public.notifications where id in(select id from read_notification_ids where label in ('own','unread')) and read_at is null)=1,'unread listing excludes read record';
 -- The missing target was checked by the fixture owner; recipient need not read Shares.
end $$;
select pg_temp.read_bad('select id from public.shares where id=''ffffffff-ffff-4fff-8fff-ffffffffffff''');
select pg_temp.read_bad('select public.mark_notification_read(null)','22023');
select pg_temp.read_bad('select public.mark_notification_read(''ffffffff-ffff-4fff-8fff-ffffffffffff'')');
-- Exact read IDs cannot mutate peers, even with current Team/role authority.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.read_bad(format('select public.mark_notification_read(%L)',id)) from read_notification_ids where label='own';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select pg_temp.read_bad(format('select public.mark_notification_read(%L)',id)) from read_notification_ids where label='own';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.read_bad(format('select public.mark_notification_read(%L)',id)) from read_notification_ids where label='own';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
select pg_temp.read_bad(format('select public.mark_notification_read(%L)',id)) from read_notification_ids where label='own';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.read_bad(format('select public.mark_notification_read(%L)',id)) from read_notification_ids where label='own';
insert into read_results select 'inaccessible',public.mark_notification_read(id) from read_notification_ids where label='inaccessible-target';
do $$begin
 assert not exists(select 1 from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team')),'read reference confers no source authority';
 assert exists(select 1 from public.notifications where id=(select id from read_notification_ids where label='inaccessible-target') and read_at is not null),'inaccessible linked target does not block own mark read';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Direct updates remain denied even to owner: no field or timestamp patches.
select pg_temp.read_bad(format('update public.notifications set read_at=null where id=%L',id)) from read_notification_ids where label='own';
select pg_temp.read_bad(format('update public.notifications set read_at=''2000-01-01'' where id=%L',id)) from read_notification_ids where label='own';
select pg_temp.read_bad(format('update public.notifications set recipient_user_id=''00000000-0000-4000-8000-000000006006'' where id=%L',id)) from read_notification_ids where label='own';
select pg_temp.read_bad(format('update public.notifications set notification_type=''ARTIFACT_APPROVED'' where id=%L',id)) from read_notification_ids where label='own';
select pg_temp.read_bad(format('update public.notifications set title=''Rewrite'',body=''Private replacement'' where id=%L',id)) from read_notification_ids where label='own';
select pg_temp.read_bad(format('update public.notifications set entity_id=''ffffffff-ffff-4fff-8fff-ffffffffffff'' where id=%L',id)) from read_notification_ids where label='own';
select pg_temp.read_bad(format('update public.notifications set entity_type=''ARTIFACT'' where id=%L',id)) from read_notification_ids where label='own';
select pg_temp.read_bad(format('update public.notifications set created_at=now(),metadata=''{}'',idempotency_digest=null,request_fingerprint=null where id=%L',id)) from read_notification_ids where label='own';
select pg_temp.read_bad(format('select public.mark_notification_read(target_notification=>%L,read_at=>null)',id),'42883') from read_notification_ids where label='own';
select pg_temp.read_bad(format('select public.mark_notification_read(target_notification=>%L,recipient_user_id=>''00000000-0000-4000-8000-000000006006'')',id),'42883') from read_notification_ids where label='own';
reset role;
do $$begin
 assert not exists(select 1 from read_history_before b join public.notifications n using(id) where to_jsonb(n)-'read_at' is distinct from b.payload),'all protected fields and internal history preserved';
 assert (select count(*) from public.notifications)=(select count(*) from read_history_before),'no deleted or duplicate rows';
 assert not has_table_privilege('authenticated','public.notifications','update');
 assert not has_table_privilege('authenticated','public.notifications','insert');
 assert not has_table_privilege('authenticated','public.notifications','delete');
 assert has_function_privilege('authenticated','public.mark_notification_read(uuid)','execute');
 assert not has_function_privilege('anon','public.mark_notification_read(uuid)','execute');
 assert not has_function_privilege('service_role','public.mark_notification_read(uuid)','execute');
end $$;
-- Account deactivation and absent auth are denied independently of row ID.
update public.users set account_status='suspended' where id='00000000-0000-4000-8000-000000006004';
set local role authenticated;
select pg_temp.read_bad(format('select public.mark_notification_read(%L)',id)) from read_notification_ids where label='own';
select set_config('request.jwt.claim.sub','',true);
select pg_temp.read_bad('select public.mark_notification_read(''ffffffff-ffff-4fff-8fff-ffffffffffff'')','28000');
reset role;
set local role anon;
select pg_temp.read_bad('select public.mark_notification_read(''ffffffff-ffff-4fff-8fff-ffffffffffff'')');
reset role;
rollback;
select 'M15.5 own idempotent read timestamp/immutability/direct-mutation denial PASS';
