\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'chat-'||n||'@example.test' from generate_series(3001,3004) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'chat-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000003001','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000003001');
create temporary table chat_cohorts(label text,id uuid);grant select,insert on chat_cohorts to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000003001',true);
insert into chat_cohorts values('A',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Chat A fixture','2026-10-01',null,'00000000-0000-4000-8000-000000003002','planned','{}')->>'id')::uuid);
insert into chat_cohorts values('B',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Chat B fixture','2026-10-01',null,'00000000-0000-4000-8000-000000003002','planned','{}')->>'id')::uuid);
reset role;
insert into public.workspaces(id,workspace_type,name,cohort_id,created_by,updated_by)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'TEAM','Chat fixture',(select id from chat_cohorts where label=case when n=3101 then 'A' else 'B' end),'00000000-0000-4000-8000-000000003001','00000000-0000-4000-8000-000000003001' from generate_series(3101,3102) n;
insert into public.workspaces(id,workspace_type,name,owner_user_id,cohort_id,created_by,updated_by) values('00000000-0000-4000-8000-000000003110','PERSONAL','Non-Team fixture','00000000-0000-4000-8000-000000003003',(select id from chat_cohorts where label='A'),'00000000-0000-4000-8000-000000003001','00000000-0000-4000-8000-000000003001');
insert into public.teams(id,cohort_id,name,master_user_id,workspace_id,created_by)
 select ('00000000-0000-4000-8000-'||lpad((n+100)::text,12,'0'))::uuid,cohort_id,'Chat Team '||n,'00000000-0000-4000-8000-000000003002',id,'00000000-0000-4000-8000-000000003001' from public.workspaces cross join lateral (select substring(id::text from 25)::integer n) x where id in ('00000000-0000-4000-8000-000000003101','00000000-0000-4000-8000-000000003102');
insert into public.chat_channels(id,channel_type,workspace_id,team_id,cohort_id,name)
 select ('00000000-0000-4000-8000-'||lpad((substring(id::text from 25)::integer+100)::text,12,'0'))::uuid,'TEAM',workspace_id,id,cohort_id,'Private Team Chat' from public.teams where id in ('00000000-0000-4000-8000-000000003201','00000000-0000-4000-8000-000000003202');
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at) values
 ('00000000-0000-4000-8000-000000003301','00000000-0000-4000-8000-000000003003','read_write',now()),
 ('00000000-0000-4000-8000-000000003301','00000000-0000-4000-8000-000000003004','read',now());
insert into public.chat_messages(id,chat_channel_id,sender_user_id,content) values('00000000-0000-4000-8000-000000003401','00000000-0000-4000-8000-000000003301','00000000-0000-4000-8000-000000003003','Canonical text');
insert into public.chat_messages(id,chat_channel_id,sender_user_id,parent_message_id,content) values('00000000-0000-4000-8000-000000003402','00000000-0000-4000-8000-000000003301','00000000-0000-4000-8000-000000003004','00000000-0000-4000-8000-000000003401','Canonical reply');
do $$ declare c uuid:='00000000-0000-4000-8000-000000003301'; t text; w uuid; begin
 assert exists(select 1 from public.chat_channels c join public.teams t on t.id=c.team_id join public.workspaces w on w.id=c.workspace_id where c.id='00000000-0000-4000-8000-000000003301' and c.cohort_id=t.cohort_id and t.workspace_id=w.id and w.workspace_type='TEAM'),'valid Team/Workspace/Cohort relation';
 assert exists(select 1 from public.chat_messages where id='00000000-0000-4000-8000-000000003401' and sender_user_id='00000000-0000-4000-8000-000000003003' and content='Canonical text' and message_type='TEXT' and created_at=now() and edited_at is null and deleted_at is null),'canonical text/sender/timestamp persist';
 assert exists(select 1 from public.chat_messages where parent_message_id='00000000-0000-4000-8000-000000003401' and chat_channel_id=c),'same-channel reply persists';
 assert (select array_agg(id order by created_at,id) from public.chat_messages where chat_channel_id=c)=array['00000000-0000-4000-8000-000000003401','00000000-0000-4000-8000-000000003402']::uuid[],'deterministic ordered loading';
 assert enum_range(null::public.chat_message_type)::text[]=array['TEXT','FILE','LINK','SYSTEM'],'exact message types';
 foreach w in array array['00000000-0000-4000-8000-000000003110','00000000-0000-4000-8000-000000003102','00000000-0000-4000-8000-000000009999']::uuid[] loop
  begin insert into public.chat_channels(channel_type,workspace_id,team_id,cohort_id,name) values('TEAM',w,'00000000-0000-4000-8000-000000003201',(select id from chat_cohorts where label='A'),'Invalid Workspace');raise exception 'invalid/non-Team Workspace accepted';exception when foreign_key_violation then null;end;
 end loop;
 begin update public.chat_channels set cohort_id=(select id from chat_cohorts where label='B') where id=c;raise exception 'cohort drift';exception when foreign_key_violation then null;end;
 begin update public.chat_channels set team_id='00000000-0000-4000-8000-000000003202' where id=c;raise exception 'Team drift';exception when foreign_key_violation then null;end;
 begin update public.chat_channels set team_id=null where id=c;raise exception 'unscoped Team Chat';exception when check_violation then null;end;
 begin update public.chat_channels set cohort_id=null where id=c;raise exception 'missing Team Chat cohort';exception when check_violation then null;end;
 begin update public.chat_channels set team_id='00000000-0000-4000-8000-000000009999' where id=c;raise exception 'invalid Team FK';exception when foreign_key_violation then null;end;
 begin update public.chat_channels set cohort_id='00000000-0000-4000-8000-000000009999' where id=c;raise exception 'invalid cohort FK';exception when foreign_key_violation then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,parent_message_id,content) values('00000000-0000-4000-8000-000000003302','00000000-0000-4000-8000-000000003003','00000000-0000-4000-8000-000000003401','Cross-channel reply');raise exception 'cross-channel parent accepted';exception when foreign_key_violation then null;end;
 begin update public.chat_messages set chat_channel_id='00000000-0000-4000-8000-000000003302' where id='00000000-0000-4000-8000-000000003402';raise exception 'reply channel drift';exception when foreign_key_violation then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,parent_message_id,content) values(c,'00000000-0000-4000-8000-000000003003','00000000-0000-4000-8000-000000009999','Missing parent');raise exception 'invalid parent';exception when foreign_key_violation then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content,message_type) values(c,'00000000-0000-4000-8000-000000003003','Bad type','INVALID');raise exception 'invalid message type';exception when invalid_text_representation then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(c,'00000000-0000-4000-8000-000000003003','   ');raise exception 'empty TEXT';exception when check_violation then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(c,'00000000-0000-4000-8000-000000009999','Invalid sender');raise exception 'invalid sender';exception when foreign_key_violation then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values('00000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000003003','Invalid channel');raise exception 'invalid message channel';exception when foreign_key_violation then null;end;
 begin insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at) values(c,'00000000-0000-4000-8000-000000009999','read',now());raise exception 'invalid membership user';exception when foreign_key_violation then null;end;
 begin insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at) values('00000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000003003','read',now());raise exception 'invalid membership channel';exception when foreign_key_violation then null;end;
 begin update public.chat_memberships set access_level='admin';raise exception 'invalid access level';exception when invalid_text_representation then null;end;
 foreach t in array array['chat_channels','chat_memberships','chat_messages'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass),'RLS enabled';
  assert not has_table_privilege('authenticated','public.'||t,'INSERT,UPDATE,DELETE,TRUNCATE'),'no direct client mutation privileges';
  assert not has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE'),'anonymous denied';
 end loop;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000003003',true);
do $$ declare t text; n integer; begin
 foreach t in array array['chat_channels','chat_memberships','chat_messages'] loop
  execute format('select count(*) from public.%I',t) into n;assert n=0,'storage metadata alone does not authorize Chat read';
 end loop;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values('00000000-0000-4000-8000-000000003301',auth.uid(),'Client message');raise exception 'client mutation';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- RLS remains default deny even if table privileges are accidentally granted.
grant select,insert,update,delete on public.chat_channels,public.chat_memberships,public.chat_messages to authenticated;
set local role authenticated;
do $$ declare t text; n integer; begin
 foreach t in array array['chat_channels','chat_memberships','chat_messages'] loop
  execute format('select count(*) from public.%I',t) into n;assert n=0,'metadata membership does not grant read access';
 end loop;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values('00000000-0000-4000-8000-000000003301',auth.uid(),'RLS attack');raise exception 'RLS INSERT bypass';exception when insufficient_privilege then null;end;
 update public.chat_messages set content='Attack';get diagnostics n=row_count;assert n=0,'RLS UPDATE denied';
 delete from public.chat_messages;get diagnostics n=row_count;assert n=0,'RLS DELETE denied';
end $$;
reset role;
revoke insert,update,delete on public.chat_channels,public.chat_memberships,public.chat_messages from authenticated;
commit;
-- Reconnect to prove committed canonical messages survive the original session.
-- This runner owns a fresh disposable database; these fixtures never reach a live project.
\connect
do $$ begin
 assert exists(select 1 from public.chat_messages where id='00000000-0000-4000-8000-000000003401' and sender_user_id='00000000-0000-4000-8000-000000003003' and content='Canonical text' and created_at is not null),'canonical message persists after reconnect';
 assert exists(select 1 from public.chat_messages where id='00000000-0000-4000-8000-000000003402' and parent_message_id='00000000-0000-4000-8000-000000003401'),'reply persists after reconnect';
end $$;
\echo M5.3 canonical Team Chat storage, same-channel replies, scope FKs and default-deny RLS PASS
