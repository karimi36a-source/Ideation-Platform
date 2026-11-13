\set ON_ERROR_STOP on
begin;
-- Deterministic identities: Admin, assigned/unrelated Masters, A1/A2/B1/B2,
-- plus Mentor for negative authority regression. Resources use canonical RPC IDs.
insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'team-acceptance-'||n||'@example.test' from generate_series(6001,6008) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'team-acceptance-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by)
 select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('00000000-0000-4000-8000-'||lpad((case when n=6001 then 101 when n=6008 then 103 else 104 end)::text,12,'0'))::uuid,
 '00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000006001'
 from generate_series(6001,6008) n where n not in (6002,6003);
create temporary table acceptance_cohorts(label text primary key,id uuid);grant select,insert on acceptance_cohorts to authenticated;
create temporary table acceptance_teams(label text primary key,payload jsonb);grant select,insert on acceptance_teams to authenticated;
create temporary table acceptance_messages(label text primary key,payload jsonb);grant select,insert on acceptance_messages to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into acceptance_cohorts values('Test',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Professional Course Test Cohort','2026-10-01',null,'00000000-0000-4000-8000-000000006002','active','{}')->>'id')::uuid);
insert into acceptance_cohorts values('Unrelated',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Unrelated acceptance cohort','2026-10-01',null,'00000000-0000-4000-8000-000000006003','active','{}')->>'id')::uuid);
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
 select c.id,('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'participant','active' from acceptance_cohorts c cross join generate_series(6004,6008) n where c.label='Test';
-- Canonical Personal provisioning, retained unchanged through all Team operations.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select public.create_personal_workspace();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);select public.create_personal_workspace();
create temporary table acceptance_personal as select id,to_jsonb(w) data from public.workspaces w where workspace_type='PERSONAL' and owner_user_id in ('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into acceptance_teams values('A',public.create_team((select id from acceptance_cohorts where label='Test'),'Team A'));
insert into acceptance_teams values('B',public.create_team((select id from acceptance_cohorts where label='Test'),'Team B'));

select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005','team_lead');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006008','mentor');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006','member');
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007','member');

reset role;
create temporary table removal_target as
 select (t.payload->>'teamId')::uuid team_id,(t.payload->>'workspaceId')::uuid workspace_id,(t.payload->>'chatChannelId')::uuid channel_id,
 m.id membership_id,cm.id chat_membership_id,(select id from public.workspaces where workspace_type='PERSONAL' and status='active' and owner_user_id='00000000-0000-4000-8000-000000006004') personal_id
 from acceptance_teams t join public.team_memberships m on m.team_id=(t.payload->>'teamId')::uuid and m.user_id='00000000-0000-4000-8000-000000006004'
 join public.chat_memberships cm on cm.chat_channel_id=(t.payload->>'chatChannelId')::uuid and cm.user_id=m.user_id and cm.left_at is null where t.label='A';
grant select on removal_target to authenticated;
create temporary table removal_before_member as select to_jsonb(m) data from public.team_memberships m where id=(select membership_id from removal_target);
create temporary table removal_before_chat_member as select to_jsonb(m) data from public.chat_memberships m where id=(select chat_membership_id from removal_target);
create temporary table removal_before_history as
 select 'workspace' kind,id,to_jsonb(t) data from public.workspaces t union all select 'team',id,to_jsonb(t) from public.teams t
 union all select 'channel',id,to_jsonb(t) from public.chat_channels t union all select 'audit',id,to_jsonb(t) from public.audit_events t
 union all select 'notification',id,to_jsonb(t) from public.notifications t;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare x record;begin select * into x from removal_target;
 assert public.get_team_workspace_access(x.workspace_id)='member' and public.get_team_chat_access(x.channel_id)='read_write','before: authorized Workspace and Chat';
 assert exists(select 1 from public.teams where id=x.team_id),'before: Team metadata';
 assert exists(select 1 from public.chat_memberships where id=x.chat_membership_id and left_at is null),'before: Chat membership';end $$;
insert into acceptance_messages values('A1',public.send_team_chat_message((select team_id from removal_target),'Canonical A1 removal scenario message'));
do $$begin assert exists(select 1 from public.chat_messages where id=(select (payload->>'id')::uuid from acceptance_messages where label='A1') and sender_user_id=auth.uid() and created_at is not null),'before: sender/timestamp persistence';
 assert public.list_team_chat_messages((select channel_id from removal_target))->'items'->0=(select payload from acceptance_messages where label='A1'),'before: canonical reload';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select team_id from removal_target),'00000000-0000-4000-8000-000000006004','Private reason must not enter metadata');
reset role;
do $$declare x record;begin select * into x from removal_target;
 assert exists(select 1 from public.team_memberships m where id=x.membership_id and status='removed' and left_at>=joined_at and removed_by='00000000-0000-4000-8000-000000006002'
 and to_jsonb(m)-array['status','left_at','removed_by']=(select data-array['status','left_at','removed_by'] from removal_before_member)),'historical join/identity/role/creation preserved';
 assert exists(select 1 from public.chat_memberships m where id=x.chat_membership_id and left_at is not null and to_jsonb(m)-'left_at'=(select data-'left_at' from removal_before_chat_member)),'original closed Chat history preserved';
 assert exists(select 1 from public.chat_messages m where id=(select (payload->>'id')::uuid from acceptance_messages where label='A1') and to_jsonb(m)=(select payload from acceptance_messages where label='A1')),'historical message/attribution/timestamp exact';
 assert (select count(*) from public.audit_events where event_type='MEMBER_REMOVED' and entity_id=x.team_id and actor_user_id='00000000-0000-4000-8000-000000006002'
 and scope_id=x.team_id and metadata->>'userId'='00000000-0000-4000-8000-000000006004' and metadata->>'membershipId'=x.membership_id::text)=1,'verified Master/member/Team removal audit';
 assert not exists(select 1 from public.audit_events a cross join lateral jsonb_object_keys(a.metadata) k where event_type='MEMBER_REMOVED' and entity_id=x.team_id and k not in ('cohortId','userId','membershipId','membershipRole','previousLeadUserId')),'allowlisted metadata only';
 assert not exists(select 1 from public.audit_events where metadata::text like '%Private reason%' or metadata::text like '%Canonical A1%'),'no reason or content copied';
 assert exists(select 1 from public.notifications where notification_type='MEMBER_REMOVED' and entity_id=x.team_id and recipient_user_id='00000000-0000-4000-8000-000000006004' and metadata='{}'),'affected-user minimal notification';
end $$;
-- Inject a separate stale open access row; retain the original closed history.
insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at)
 select channel_id,'00000000-0000-4000-8000-000000006004','read_write',clock_timestamp() from removal_target;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare x record;mid uuid;begin select * into x from removal_target;mid:=(select (payload->>'id')::uuid from acceptance_messages where label='A1');
 assert not exists(select 1 from public.teams where id=x.team_id),'exact Team ID denied';
 assert not exists(select 1 from public.workspaces where id=x.workspace_id),'exact Workspace denied';
 assert not exists(select 1 from public.chat_channels where id=x.channel_id),'exact Channel denied';
 assert not exists(select 1 from public.chat_messages where id=mid or chat_channel_id=x.channel_id),'exact message/list denied';
 begin assert not exists(select 1 from public.team_memberships where id=x.membership_id),'historical membership private';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.chat_memberships where id=x.chat_membership_id or chat_channel_id=x.channel_id),'original/stale Chat membership no access';
 assert public.get_team_workspace_access(x.workspace_id) is null and public.get_team_chat_access(x.channel_id) is null,'stale membership no capability';
 assert not public.can_receive_team_chat_broadcast('team-chat:'||x.channel_id::text||':'||auth.uid()::text),'removed realtime denied';
 begin perform public.list_team_chat_messages(x.channel_id);raise exception 'removed reload';exception when insufficient_privilege then null;end;
 begin perform public.send_team_chat_message(x.team_id,'removed send');raise exception 'removed send';exception when insufficient_privilege then null;end;
 begin perform public.add_team_member(x.team_id,auth.uid(),'member');raise exception 'self readd';exception when insufficient_privilege then null;end;
 begin update public.team_memberships set status='active',left_at=null,removed_by=null where id=x.membership_id;raise exception 'reactivation';exception when insufficient_privilege then null;end;
 begin update public.chat_memberships set left_at=null,access_level='read_write' where id=x.chat_membership_id;raise exception 'Chat escalation';exception when insufficient_privilege then null;end;
 begin insert into public.team_memberships(team_id,user_id,membership_role,joined_at,added_by) values(x.team_id,auth.uid(),'member',clock_timestamp(),auth.uid());raise exception 'membership insertion';exception when insufficient_privilege then null;end;
 begin insert into public.chat_memberships(chat_channel_id,user_id,access_level,joined_at) values(x.channel_id,auth.uid(),'read_write',clock_timestamp());raise exception 'Chat insertion';exception when insufficient_privilege then null;end;
 begin insert into public.chat_messages(chat_channel_id,sender_user_id,content) values(x.channel_id,auth.uid(),'removed direct INSERT');raise exception 'message insertion';exception when insufficient_privilege then null;end;
 assert exists(select 1 from public.notifications where notification_type='MEMBER_REMOVED' and recipient_user_id=auth.uid() and entity_id=x.team_id),'own removal notification still readable';
 assert exists(select 1 from public.workspaces where id=x.personal_id and owner_user_id=auth.uid() and status='active'),'Personal normal owner access retained';
end $$;
-- Remaining member reads A1 history, posts, and subscribes; no Personal leakage.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare x record;begin select * into x from removal_target;
 assert public.get_team_workspace_access(x.workspace_id)='team_lead' and public.get_team_chat_access(x.channel_id)='read_write','remaining Team functional';
 assert public.list_team_chat_messages(x.channel_id)->'items'->0=(select payload from acceptance_messages where label='A1'),'remaining member reads historical canonical message';
 assert public.can_receive_team_chat_broadcast('team-chat:'||x.channel_id::text||':'||auth.uid()::text),'remaining subscription';
 assert not exists(select 1 from public.workspaces where id=x.personal_id),'teammate cannot view Personal';
 assert not exists(select 1 from public.notifications where recipient_user_id='00000000-0000-4000-8000-000000006004'),'cannot read A1 notification';
 begin insert into public.notifications(recipient_user_id,notification_type,entity_type,entity_id) values('00000000-0000-4000-8000-000000006004','MEMBER_REMOVED','team',x.team_id);raise exception 'forged notification';exception when insufficient_privilege then null;end;
end $$;
insert into acceptance_messages values('remaining',public.send_team_chat_message((select team_id from removal_target),'Remaining Team A member still posts'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert not exists(select 1 from public.workspaces where id=(select personal_id from removal_target)),'Master cannot view Personal';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin assert not exists(select 1 from public.workspaces where id=(select workspace_id from removal_target));assert not exists(select 1 from public.chat_messages where chat_channel_id=(select channel_id from removal_target));assert not exists(select 1 from public.notifications where recipient_user_id='00000000-0000-4000-8000-000000006004'),'Team B remains isolated';end $$;
reset role;
do $$declare x record;actual jsonb;begin
 for x in select * from removal_before_history loop
 case x.kind
 when 'workspace' then select to_jsonb(t) into actual from public.workspaces t where id=x.id;
 when 'team' then select to_jsonb(t) into actual from public.teams t where id=x.id;
 when 'channel' then select to_jsonb(t) into actual from public.chat_channels t where id=x.id;
 when 'audit' then select to_jsonb(t) into actual from public.audit_events t where id=x.id;
 when 'notification' then select to_jsonb(t) into actual from public.notifications t where id=x.id;
 end case;
 assert actual is not distinct from x.data,'existing history/Personal metadata unchanged';
 end loop;
 assert exists(select 1 from public.chat_messages where id=(select (payload->>'id')::uuid from acceptance_messages where label='A1') and to_jsonb(chat_messages)=(select payload from acceptance_messages where label='A1')),'original attribution remains after continued activity';
 assert not exists(select 1 from realtime.messages where payload->>'messageId'=(select payload->>'id' from acceptance_messages where label='remaining') and topic like '%00000000-0000-4000-8000-000000006004'),'removed stale recipient gets no future publication';
end $$;
\echo M5.17 AT-E2E-MEMBER-001 M5-owned scenario PASS
\echo M5.17 Idea contribution preservation DEFERRED - M6 Development Objects / M9 Ideas
\echo M5.17 Vote preservation DEFERRED - M10 Voting
\echo M5.17 Artifact edit/history DEFERRED - M8 Artifacts
\echo M5.17 AI access/revocation DEFERRED - M14 AI
set constraints all immediate;
rollback;
