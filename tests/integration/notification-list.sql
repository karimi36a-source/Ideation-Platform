reset role;
-- All rows belong to disposable fixture accounts. Current insert timestamp guard
-- stays enabled; pagination compares the exact timestamps PostgreSQL assigned.
create temporary table list_notification_ids(label text,id uuid);
grant select on list_notification_ids to authenticated;
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id)
 select '00000000-0000-4000-8000-000000006004',case when n=1 then 'MEMBER_ADDED' else 'LEGACY_PILOT_CODE' end,
 'M15.4 private notice','A safe stored summary.',case when n=2 then 'ARTIFACT' end,
 case when n=2 then (select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team') end
 from generate_series(1,7) n returning id
) insert into list_notification_ids select 'own',id from inserted;
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body)
 select '00000000-0000-4000-8000-000000006006','MEMBER_ADDED','Other user','A separate safe notice.' from generate_series(1,3) returning id
) insert into list_notification_ids select 'other',id from inserted;
-- Narrow privileged schema-test read-state setup; no mark-read API is added.
update public.notifications set read_at=clock_timestamp() where id in (
 select n.id from public.notifications n join list_notification_ids ids on ids.id=n.id where ids.label='own' order by n.created_at,n.id limit 2
);
create temporary table notification_history_before as select id,to_jsonb(n) payload from public.notifications n;
create temporary table notification_pages(page integer,id uuid,created_at timestamptz);
grant select,insert on notification_pages to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Exact same cursor predicate as listMyNotifications; normal SELECT under RLS.
insert into notification_pages select 1,id,created_at from public.notifications
 where recipient_user_id=public.current_platform_user_id() and id in(select id from list_notification_ids where label='own')
 order by created_at desc,id desc limit 3;
insert into notification_pages select 2,n.id,n.created_at from public.notifications n
 where n.recipient_user_id=public.current_platform_user_id() and n.id in(select id from list_notification_ids where label='own')
 and (n.created_at<(select created_at from notification_pages where page=1 order by created_at,id limit 1)
 or (n.created_at=(select created_at from notification_pages where page=1 order by created_at,id limit 1)
 and n.id<(select id from notification_pages where page=1 order by created_at,id limit 1)))
 order by n.created_at desc,n.id desc limit 3;
insert into notification_pages select 3,n.id,n.created_at from public.notifications n
 where n.recipient_user_id=public.current_platform_user_id() and n.id in(select id from list_notification_ids where label='own')
 and (n.created_at<(select created_at from notification_pages where page=2 order by created_at,id limit 1)
 or (n.created_at=(select created_at from notification_pages where page=2 order by created_at,id limit 1)
 and n.id<(select id from notification_pages where page=2 order by created_at,id limit 1)))
 order by n.created_at desc,n.id desc limit 3;
do $$begin
 assert (select count(*) from notification_pages)=7 and (select count(distinct id) from notification_pages)=7,'all pages no gaps/duplicates';
 assert (select count(*) from notification_pages where page=1)=3 and (select count(*) from notification_pages where page=2)=3 and (select count(*) from notification_pages where page=3)=1;
 assert (select count(*) from public.notifications where id in(select id from list_notification_ids where label='own') and read_at is null)=5,'unread filter';
 assert (select count(*) from public.notifications where id in(select id from list_notification_ids where label='own'))=7,'normal listing includes read';
 assert exists(select 1 from public.notifications where notification_type='MEMBER_ADDED' and id in(select id from list_notification_ids)),'legacy membership code listable';
 assert not exists(select 1 from public.notifications where id in(select id from list_notification_ids where label='other')),'other recipient hidden';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin
 assert (select count(*) from public.notifications where id in(select id from list_notification_ids))=3,'A2 own notifications only';
 assert not exists(select 1 from public.notifications where id in(select id from list_notification_ids where label='own')),'known IDs do not reveal A1';
 assert not exists(select 1 from public.notifications where recipient_user_id='00000000-0000-4000-8000-000000006004'),'spoofed SQL recipient filter still denied by RLS';
 assert not exists(select 1 from public.notifications where (created_at,id)<(select created_at,id from notification_pages where page=1 order by created_at desc,id desc limit 1) and recipient_user_id='00000000-0000-4000-8000-000000006004'),'known A1 cursor not authority';
end $$;
reset role;
-- A visible notification may reference an inaccessible or missing target.
with inserted as (
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id)
 select '00000000-0000-4000-8000-000000006006','ARTIFACT_SHARED','Stored share notice','Open the application for details.','ARTIFACT',(payload->>'artifactId')::uuid from submitted_fixtures where label='Team' returning id
) insert into list_notification_ids select 'inaccessible-target',id from inserted;
set local role authenticated;
do $$begin
 assert exists(select 1 from public.notifications where id in(select id from list_notification_ids where label='inaccessible-target'));
 assert not exists(select 1 from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team')),'reference grants no source content';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not exists(select 1 from public.notifications where id in(select id from list_notification_ids)),'same Team/Cohort Lead grants no recipient authority';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
do $$begin assert not exists(select 1 from public.notifications where id in(select id from list_notification_ids)),'Admin role grants no recipient authority';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert not exists(select 1 from public.notifications where id in(select id from list_notification_ids)),'scoped Master grants no recipient authority';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006008',true);
do $$begin assert not exists(select 1 from public.notifications where id in(select id from list_notification_ids)),'Mentor role grants no recipient authority';end $$;
reset role;
do $$begin
 assert not exists(select 1 from notification_history_before b join public.notifications n using(id) where to_jsonb(n) is distinct from b.payload),'listing preserves all notification state';
 assert exists(select 1 from pg_indexes where tablename='notifications' and indexname='notifications_recipient_time');
 assert exists(select 1 from pg_indexes where tablename='notifications' and indexname='notifications_recipient_unread');
end $$;
set local role anon;
do $$begin begin perform id from public.notifications;raise exception 'anonymous history';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
select 'M15.4 own notification pagination/unread/history/role isolation PASS';
