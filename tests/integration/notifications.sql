-- Appended to the existing disposable canonical authorization fixture.
create temporary table notification_ids(label text,id uuid);
grant select on notification_ids to authenticated;
with n as (insert into public.notifications(recipient_user_id,notification_type,title,body)
 values('00000000-0000-4000-8000-000000006004','SCHEMA_TEST','Update available','Open the application for details.') returning id)
insert into notification_ids select 'first',id from n;
with n as (insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id,created_at,read_at)
 select '00000000-0000-4000-8000-000000006004','SCHEMA_TEST','Update available','An informational reference.','ARTIFACT',(payload->>'artifactId')::uuid,'2000-01-01','2000-01-01' from submitted_fixtures where label='Team' returning id)
insert into notification_ids select 'second',id from n;
insert into public.notifications(recipient_user_id,notification_type,title,body)
 values('00000000-0000-4000-8000-000000006006','SCHEMA_TEST','Other recipient','A separate private notification.');
do $$ declare k text;begin
 assert (select count(*) from public.notifications where id in(select id from notification_ids))=2;
 assert not exists(select 1 from public.notifications where id in(select id from notification_ids) and (read_at is not null or created_at<'2026-01-01')),'database controls creation/unread defaults';
 assert exists(select 1 from public.notifications where id=(select id from notification_ids where label='first') and entity_type is null and entity_id is null),'target optional';
 assert (select id from public.notifications where id in(select id from notification_ids) order by created_at,id limit 1)=(select id from notification_ids where label='first'),'chronological order';
 assert exists(select 1 from pg_indexes where tablename='notifications' and indexname='notifications_recipient_time');
 assert exists(select 1 from pg_indexes where tablename='notifications' and indexname='notifications_recipient_unread' and indexdef like '%WHERE (read_at IS NULL)%');
 begin insert into public.notifications(notification_type) values('SCHEMA_TEST');raise exception 'recipient optional';exception when not_null_violation then null;end;
 begin insert into public.notifications(recipient_user_id,notification_type) values(gen_random_uuid(),'SCHEMA_TEST');raise exception 'missing recipient allowed';exception when foreign_key_violation then null;end;
 foreach k in array array['','invalid type',repeat('X',65)] loop
  begin insert into public.notifications(recipient_user_id,notification_type) values('00000000-0000-4000-8000-000000006004',k);raise exception 'bad type allowed';exception when check_violation then null;end;
 end loop;
 begin insert into public.notifications(recipient_user_id,notification_type,title) values('00000000-0000-4000-8000-000000006004','SCHEMA_TEST',' ');raise exception 'empty title';exception when check_violation then null;end;
 begin insert into public.notifications(recipient_user_id,notification_type,body) values('00000000-0000-4000-8000-000000006004','SCHEMA_TEST',repeat('x',501));raise exception 'unbounded body';exception when check_violation then null;end;
 begin insert into public.notifications(recipient_user_id,notification_type,entity_id) values('00000000-0000-4000-8000-000000006004','SCHEMA_TEST',gen_random_uuid());raise exception 'partial target';exception when check_violation then null;end;
end $$;
update public.notifications set read_at=clock_timestamp() where id=(select id from notification_ids where label='first');
do $$ begin
 assert exists(select 1 from public.notifications where id=(select id from notification_ids where label='first') and read_at is not null),'mark read retains row';
 assert (select count(*) from public.notifications where id in(select id from notification_ids) and read_at is null)=1,'unread semantics';
 begin update public.notifications set body='Rewrite';raise exception 'content mutable';exception when check_violation then null;end;
 begin update public.notifications set recipient_user_id='00000000-0000-4000-8000-000000006006';raise exception 'recipient mutable';exception when check_violation then null;end;
 begin delete from public.notifications;raise exception 'history deletable';exception when check_violation then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$ begin
 assert (select count(*) from public.notifications where notification_type='SCHEMA_TEST')=2,'recipient reads own only';
 begin insert into public.notifications(recipient_user_id,notification_type) values(auth.uid(),'SCHEMA_TEST');raise exception 'client forge';exception when insufficient_privilege then null;end;
 begin update public.notifications set read_at=now();raise exception 'broad client update';exception when insufficient_privilege then null;end;
 begin delete from public.notifications;raise exception 'client delete';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$ begin
 assert (select count(*) from public.notifications where notification_type='SCHEMA_TEST')=1,'A2 only own row';
 assert not exists(select 1 from public.notifications where id in(select id from notification_ids)),'known IDs hidden';
end $$;
reset role;
-- An informational reference deliberately does not confer target authority.
insert into public.notifications(recipient_user_id,notification_type,entity_type,entity_id)
 select '00000000-0000-4000-8000-000000006006','SCHEMA_TEST','ARTIFACT',(payload->>'artifactId')::uuid from submitted_fixtures where label='Team';
set local role authenticated;
do $$ begin
 assert exists(select 1 from public.notifications where entity_type='ARTIFACT'),'reference visible';
 assert not exists(select 1 from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team')),'reference not target ACL';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
do $$ begin assert not exists(select 1 from public.notifications),'role-only has no recipient access';end $$;
reset role;
rollback;
select 'M15.1 notification schema/history/recipient privacy/reference isolation PASS';
