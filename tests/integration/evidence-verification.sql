-- Prepended canonical M8 scopes; actual M12.3 creation and current auth contexts.
reset role;
insert into public.project_memberships(project_id,user_id)
 select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects p where label='Team'
 and not exists(select 1 from public.project_memberships m where m.project_id=(p.payload->>'id')::uuid and m.user_id='00000000-0000-4000-8000-000000006005' and status='active');
create temporary table ev_cases(label text primary key,id uuid);
grant select,insert on ev_cases to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ev_cases select 'Team',(public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'MEASUREMENT','Named measurement','Recorded observations','Lab notebook')->>'id')::uuid from logged_projects where label='Team';
insert into ev_cases select 'Archived',(public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PAPER','Archived source','Source details','Paper reference','https://example.test/paper')->>'id')::uuid from logged_projects where label='Team';
insert into ev_cases select 'Personal',(public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'CUSTOMER_INTERVIEW','Personal interview','Recorded interview','Interview P1')->>'id')::uuid from logged_projects where label='Individual';
insert into ev_cases select 'Gap',(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'GAP','Canonical Gap','Unchanged source','User')->>'id')::uuid from logged_projects where label='Team';
select public.link_evidence(jsonb_build_object('evidenceId',(select id from ev_cases where label='Team'),'entityType','GAP','entityId',(select id from ev_cases where label='Gap'),'relationshipType','SUPPORTS'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into ev_cases select 'Case',(public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'OTHER','Case source','Recorded notes','Named source')->>'id')::uuid from logged_projects where label='Case';
reset role;
create temporary table ev_sources as select id,to_jsonb(e)-array['verification_status','verified_by','verified_at','updated_at','updated_by','archived_at'] payload from public.evidence e;
create temporary table ev_downstream as select
 (select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l) links,
 (select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o) objects,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) artifacts,
 (select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v) versions,
 (select jsonb_agg(to_jsonb(d) order by id) from public.decisions d) decisions;
create function pg_temp.ev_call(changes jsonb default '{}') returns jsonb language sql as $$
 select public.verify_evidence(coalesce(($1->>'id')::uuid,(select id from ev_cases where label='Team')),coalesce($1->>'status','VERIFIED')::public.evidence_verification_status,$1->>'note')
$$;
create function pg_temp.ev_bad(changes jsonb default '{}',expected text default '42501') returns void language plpgsql as $$
begin perform pg_temp.ev_call(changes);raise exception 'Unauthorized verification';exception when others then if sqlstate<>expected then raise;end if;end $$;
grant execute on function pg_temp.ev_call(jsonb),pg_temp.ev_bad(jsonb,text) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Creator is a normal member, not verifier authority.
select pg_temp.ev_bad();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare before_row jsonb;after_row jsonb;begin
 assert not exists(select 1 from public.evidence_verification_history),'creation is not verification';
 select to_jsonb(e) into before_row from public.evidence e where id=(select id from ev_cases where label='Team');
 after_row:=pg_temp.ev_call('{"status":"UNVERIFIED","note":"No new event"}');
 assert before_row=after_row,'same-status no-op preserves complete current row';
 assert not exists(select 1 from public.evidence_verification_history);
end $$;
select pg_temp.ev_call('{"status":"VERIFIED","note":"  Initial source review  "}');
do $$declare e public.evidence;h public.evidence_verification_history;before_row jsonb;begin
 select * into e from public.evidence where id=(select id from ev_cases where label='Team');
 select * into h from public.evidence_verification_history where evidence_id=e.id;
 assert e.verification_status='VERIFIED' and e.verified_by=public.current_platform_user_id() and e.verified_at is not null;
 assert h.previous_status='UNVERIFIED' and h.new_status='VERIFIED' and h.verified_by=e.verified_by and h.verified_at=e.verified_at and h.note='Initial source review';
 before_row:=to_jsonb(e);
 assert pg_temp.ev_call('{"status":"VERIFIED","note":"Must not replace prior review"}')=before_row;
 assert (select count(*) from public.evidence_verification_history)=1;
 assert (select note from public.evidence_verification_history)='Initial source review';
end $$;
reset role;
create temporary table ev_first_event as select id,to_jsonb(h) payload from public.evidence_verification_history h;
grant select(id) on ev_first_event to authenticated;
set local role authenticated;
select pg_temp.ev_call('{"status":"PARTIALLY_VERIFIED","note":"Partial check"}');
select pg_temp.ev_call('{"status":"CONTRADICTED","note":"Contrary source"}');
select pg_temp.ev_call('{"status":"NEEDS_REVIEW","note":"Further review needed"}');
select pg_temp.ev_call('{"status":"VERIFIED","note":"Rechecked"}');
select pg_temp.ev_call('{"status":"UNVERIFIED","note":"Reset confidence"}');
do $$declare e public.evidence;begin
 select * into e from public.evidence where id=(select id from ev_cases where label='Team');
 assert e.verification_status='UNVERIFIED' and e.verified_by is null and e.verified_at is null;
 assert (select count(*) from public.evidence_verification_history where evidence_id=e.id)=6;
 assert exists(select 1 from public.evidence_verification_history where evidence_id=e.id and previous_status='VERIFIED' and new_status='UNVERIFIED' and verified_by=public.current_platform_user_id() and verified_at is not null and note='Reset confidence');
end $$;
select pg_temp.ev_bad('{"status":"APPROVED"}','22P02');
select pg_temp.ev_bad('{"note":" \t\n "}','22023');
select pg_temp.ev_bad('{"id":"00000000-0000-4000-8000-000000009999"}');
-- A2 owns a different Personal Workspace; exact IDs grant no authority.
select pg_temp.ev_bad(jsonb_build_object('id',(select id from ev_cases where label='Personal')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.verify_evidence((select id from ev_cases where label='Personal'),'VERIFIED');
do $$begin
 assert exists(select 1 from public.evidence_verification_history where evidence_id=(select id from ev_cases where label='Personal') and verified_by=public.current_platform_user_id() and note is null);
 assert (select count(*) from public.evidence_verification_history)=7,'ordinary member can read authorized history but cannot verify Team';
end $$;
-- Role-only, cross-Team, exact history IDs and indirect joins remain denied.
do $$declare n int;begin
 foreach n in array array[6007,6002,6003,6001,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  perform pg_temp.ev_bad();
  assert not exists(select 1 from public.evidence_verification_history);
  assert not exists(select 1 from public.evidence_verification_history where id=(select id from ev_first_event));
  assert not exists(select 1 from public.evidence_verification_history h join public.evidence e on e.id=h.evidence_id);
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.ev_bad(jsonb_build_object('id',(select id from ev_cases where label='Case')));
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
update public.evidence set archived_at=clock_timestamp() where id=(select id from ev_cases where label='Archived');
set local role authenticated;
select pg_temp.ev_bad(jsonb_build_object('id',(select id from ev_cases where label='Archived')));
-- Both failure directions preserve the current row and all existing events.
reset role;
create temporary table ev_atomic_before as select to_jsonb(e) payload from public.evidence e where id=(select id from ev_cases where label='Team');
create function pg_temp.ev_force_failure() returns trigger language plpgsql as $$begin raise exception 'Forced verification failure' using errcode='23514';end $$;
create trigger ev_force_failure before insert on public.evidence_verification_history for each row execute function pg_temp.ev_force_failure();
set local role authenticated;
select pg_temp.ev_bad('{}','23514');
reset role;
drop trigger ev_force_failure on public.evidence_verification_history;
create trigger ev_force_failure before update on public.evidence for each row execute function pg_temp.ev_force_failure();
set local role authenticated;
select pg_temp.ev_bad('{"status":"CONTRADICTED"}','23514');
reset role;
drop trigger ev_force_failure on public.evidence;
do $$begin
 assert (select payload from ev_atomic_before)=(select to_jsonb(e) from public.evidence e where id=(select id from ev_cases where label='Team'));
 assert (select count(*) from public.evidence_verification_history)=7;
 begin update public.evidence_verification_history set note='Erased history';raise exception 'History UPDATE';exception when object_not_in_prerequisite_state then null;end;
 begin delete from public.evidence_verification_history;raise exception 'History DELETE';exception when object_not_in_prerequisite_state then null;end;
end $$;
set local role authenticated;
do $$begin
 begin update public.evidence set verification_status='VERIFIED',verified_by=public.current_platform_user_id(),verified_at=now();raise exception 'Direct verification';exception when insufficient_privilege then null;end;
 begin insert into public.evidence_verification_history(evidence_id,previous_status,new_status,verified_by,verified_at) select id,'UNVERIFIED','VERIFIED',public.current_platform_user_id(),now() from ev_cases where label='Team';raise exception 'Direct history INSERT';exception when insufficient_privilege then null;end;
 begin update public.evidence_verification_history set verified_by='00000000-0000-4000-8000-000000006004';raise exception 'Direct history UPDATE';exception when insufficient_privilege then null;end;
 begin delete from public.evidence_verification_history;raise exception 'Direct history DELETE';exception when insufficient_privilege then null;end;
end $$;
-- Explicit accepted removal + assignment operations change current authority.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005');
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.ev_bad('{"status":"UNVERIFIED"}');
do $$begin assert not exists(select 1 from public.evidence_verification_history);end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.ev_call('{"status":"NEEDS_REVIEW","note":"New current Lead review"}');
do $$begin
 assert exists(select 1 from public.evidence where id=(select id from ev_cases where label='Team') and verified_by=public.current_platform_user_id());
 assert (select count(*) from public.evidence_verification_history)=8;
end $$;
reset role;
do $$declare f oid:='public.verify_evidence(uuid,public.evidence_verification_status,text)'::regprocedure;begin
 assert not exists(select 1 from ev_sources s join public.evidence e on e.id=s.id where s.payload is distinct from to_jsonb(e)-array['verification_status','verified_by','verified_at','updated_at','updated_by','archived_at']);
 assert (select links from ev_downstream)=(select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l);
 assert (select objects from ev_downstream)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
 assert (select artifacts from ev_downstream)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select versions from ev_downstream)=(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v);
 assert (select decisions from ev_downstream) is not distinct from (select jsonb_agg(to_jsonb(d) order by id) from public.decisions d);
 assert (select payload from ev_first_event)=(select to_jsonb(h) from public.evidence_verification_history h where id=(select id from ev_first_event));
 assert exists(select 1 from pg_class where oid='public.evidence_verification_history'::regclass and relrowsecurity);
 assert not has_table_privilege('authenticated','public.evidence','UPDATE');
 assert not has_table_privilege('authenticated','public.evidence_verification_history','INSERT');
 assert not has_function_privilege('authenticated','private.preserve_evidence_verification()','EXECUTE');
 assert has_function_privilege('authenticated',f,'EXECUTE');
 assert not has_function_privilege('anon',f,'EXECUTE');
 assert not has_function_privilege('service_role',f,'EXECUTE');
 assert not exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where p.oid=f and a.grantee=0 and a.privilege_type='EXECUTE');
 assert (select prosecdef and proconfig=array['search_path=""'] and proargnames=array['target_evidence','target_status','verification_note'] from pg_proc where oid=f);
end $$;
select 'EVIDENCE_VERIFICATION_HISTORY_ROW='||to_jsonb(h)::text from public.evidence_verification_history h where note='Reset confidence';
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.ev_bad('{}','28000');
reset role;
set local role anon;
do $$begin
 begin perform 1 from public.evidence_verification_history;raise exception 'Anonymous history';exception when insufficient_privilege then null;end;
 begin perform public.verify_evidence(null,'VERIFIED');raise exception 'Anonymous verification';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'M12.4 TeamLead/Personal/all-states/UNVERIFIED/history/no-op/role-only/removed/lead-change/archive/source-links/rollback/grants/RLS PASS';
rollback;
