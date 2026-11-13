\set ON_ERROR_STOP on
begin;
create temporary table breakout_checks(key text primary key,value jsonb);grant select,insert on breakout_checks to authenticated,service_role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into breakout_checks select 'parent_context',public.authorize_master_live_room((value->>'cohortId')::uuid,(value->>'sessionId')::uuid,null) from public.mind_map_browser_fixture where key='scope';
set local role service_role;
insert into breakout_checks select 'parent',public.master_live_room_mapping('REUSE_OR_CREATE',(value->>'cohortId')::uuid,(value->>'sessionDefinitionId')::uuid,null,value->>'roomKey','00000000-0000-4000-8000-000000006002') from breakout_checks where key='parent_context';
set local role authenticated;
insert into breakout_checks select 'context',public.authorize_master_live_breakout((p.value->>'id')::uuid,(s.value->>'teamId')::uuid) from breakout_checks p,public.mind_map_browser_fixture s where p.key='parent' and s.key='scope';
set local role service_role;
insert into breakout_checks select 'breakout',public.manage_live_breakout_mapping('REUSE_OR_CREATE',(value->>'liveSessionRoomId')::uuid,(value->>'teamId')::uuid,'00000000-0000-4000-8000-000000006002',value->>'roomKey') from breakout_checks where key='context';
do $$declare r jsonb;v jsonb;begin select value into v from breakout_checks where key='context';r:=public.manage_live_breakout_mapping('REUSE_OR_CREATE',(v->>'liveSessionRoomId')::uuid,(v->>'teamId')::uuid,'00000000-0000-4000-8000-000000006002',v->>'roomKey');assert r=(select value from breakout_checks where key='breakout'),'Retry changed canonical mapping';begin perform public.manage_live_breakout_mapping('FIND_ACTIVE',(v->>'liveSessionRoomId')::uuid,(v->>'teamId')::uuid,'00000000-0000-4000-8000-000000006004',null);raise exception 'Student managed breakout';exception when insufficient_privilege then null;end;end $$;
set local role authenticated;
do $$declare actor uuid;target uuid:=(select (value->>'id')::uuid from breakout_checks where key='breakout');begin
 foreach actor in array array['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005','00000000-0000-4000-8000-000000006002']::uuid[] loop perform set_config('request.jwt.claim.sub',actor::text,true);assert public.authorize_live_breakout_join(target)->>'userId'=actor::text;end loop;
 foreach actor in array array['00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006001']::uuid[] loop perform set_config('request.jwt.claim.sub',actor::text,true);begin perform public.authorize_live_breakout_join(target);raise exception 'Foreign/role-only breakout authorized';exception when insufficient_privilege then null;end;end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform * from public.live_team_breakout_rooms;raise exception 'Mapping enumeration allowed';exception when insufficient_privilege then null;end;
 begin insert into public.live_team_breakout_rooms(live_session_room_id,team_id,provider_room_ref,created_by) values(gen_random_uuid(),gen_random_uuid(),'fici-'||repeat('a',64),auth.uid());raise exception 'Direct insert allowed';exception when insufficient_privilege then null;end;
 begin update public.live_team_breakout_rooms set status='EXPIRED';raise exception 'Direct update allowed';exception when insufficient_privilege then null;end;
 begin delete from public.live_team_breakout_rooms;raise exception 'Direct delete allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((value->>'teamId')::uuid,'00000000-0000-4000-8000-000000006004') from public.mind_map_browser_fixture where key='scope';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.authorize_live_breakout_join((value->>'id')::uuid) from breakout_checks where key='breakout';raise exception 'Removed member allowed';exception when insufficient_privilege then null;end;end $$;
set local role service_role;
select public.manage_live_breakout_mapping('EXPIRE',(value->>'liveSessionRoomId')::uuid,(value->>'teamId')::uuid,'00000000-0000-4000-8000-000000006002',null) from breakout_checks where key='context';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into breakout_checks select 'replacement_context',public.authorize_master_live_breakout((value->>'liveSessionRoomId')::uuid,(value->>'teamId')::uuid) from breakout_checks where key='context';
set local role service_role;
insert into breakout_checks select 'replacement',public.manage_live_breakout_mapping('REUSE_OR_CREATE',(value->>'liveSessionRoomId')::uuid,(value->>'teamId')::uuid,'00000000-0000-4000-8000-000000006002',value->>'roomKey') from breakout_checks where key='replacement_context';
reset role;
do $$begin assert (select value->>'id' from breakout_checks where key='replacement')<>(select value->>'id' from breakout_checks where key='breakout');assert (select value->>'provider_room_ref' from breakout_checks where key='replacement')<>(select value->>'provider_room_ref' from breakout_checks where key='breakout');assert exists(select 1 from public.live_team_breakout_rooms where id=(select (value->>'id')::uuid from breakout_checks where key='breakout') and status='EXPIRED');end $$;
do $$declare v jsonb;begin
 select value into v from breakout_checks where key='context';
 begin insert into public.live_team_breakout_rooms(live_session_room_id,team_id,provider_room_ref,created_by) values((v->>'liveSessionRoomId')::uuid,(v->>'teamId')::uuid,'fici-'||repeat('b',64),'00000000-0000-4000-8000-000000006002');raise exception 'Duplicate ACTIVE mapping accepted';exception when unique_violation then null;end;
 begin update public.live_team_breakout_rooms set provider_room_ref='fici-'||repeat('c',64) where id=(select (value->>'id')::uuid from breakout_checks where key='replacement');raise exception 'Provider history mutable';exception when check_violation then null;end;
 begin delete from public.live_team_breakout_rooms where id=(select (value->>'id')::uuid from breakout_checks where key='breakout');raise exception 'History deleted';exception when check_violation then null;end;
 update public.live_session_rooms set status='EXPIRED' where id=(v->>'liveSessionRoomId')::uuid;
 assert not exists(select 1 from public.live_team_breakout_rooms where live_session_room_id=(v->>'liveSessionRoomId')::uuid and status='ACTIVE'),'Parent expiration left active breakouts';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin begin perform public.authorize_live_breakout_join((value->>'id')::uuid) from breakout_checks where key='replacement';raise exception 'Expired parent authorized';exception when insufficient_privilege then null;end;end $$;
rollback;
\echo Team breakout mapping/retry/history/authorization/direct-client-denial PASS
