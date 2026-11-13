reset role;
create temporary table dr_record(payload jsonb);
grant select,insert on dr_record to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into dr_record select public.create_team_decision_record_artifact(pg_temp.da_id('Team'));
select public.link_decision_entity(jsonb_build_object('decisionId',pg_temp.da_id('Team'),'linkedEntityType','ARTIFACT','linkedEntityId',id,'relationshipType','CONSIDERED_IN_DECISION')) from df_artifacts where label='Team';
reset role;
create temporary table dr_known(table_name text,key_name text,key_value uuid);
insert into dr_known values('decisions','id',pg_temp.da_id('Team'));
insert into dr_known select 'decision_options','id',id from public.decision_options where decision_id=pg_temp.da_id('Team') limit 1;
insert into dr_known select 'decision_participants','id',id from public.decision_participants where decision_id=pg_temp.da_id('Team') limit 1;
insert into dr_known select 'decision_links','id',id from public.decision_links where decision_id=pg_temp.da_id('Team') limit 1;
insert into dr_known select 'artifact_decision_sources','artifact_id',artifact_id from public.artifact_decision_sources where decision_id=pg_temp.da_id('Team');
grant select on dr_known to authenticated;
create function pg_temp.dr_denied(command text) returns void language plpgsql as $$begin
 begin execute command;exception when insufficient_privilege then return;end;
 raise exception 'Unexpected attack success';end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare x record;found0 boolean;begin
 assert exists(select 1 from public.decisions where id=pg_temp.da_id('Personal'));
 for x in select * from dr_known loop
  execute format('select exists(select 1 from public.%I where %I=%L)',x.table_name,x.key_name,x.key_value) into found0;
  assert found0,'Current Team member reads safe parent/children';
 end loop;
 perform pg_temp.dr_denied(format('select public.finalize_decision(%L::jsonb)',jsonb_build_object('decisionId',pg_temp.da_id('Team'),'outcome','Forged','reasoning','Forged')));
end $$;
-- Test every writable field, including selected flags, scope, owner and source IDs.
do $$declare x record;c record;begin
 for x in select * from dr_known loop
  perform pg_temp.dr_denied(format('delete from public.%I where %I=%L',x.table_name,x.key_name,x.key_value));
  perform pg_temp.dr_denied(format('insert into public.%I select * from public.%I where %I=%L',x.table_name,x.table_name,x.key_name,x.key_value));
  for c in select column_name from information_schema.columns where table_schema='public' and table_name=x.table_name loop
   perform pg_temp.dr_denied(format('update public.%I set %I=%I where %I=%L',x.table_name,c.column_name,c.column_name,x.key_name,x.key_value));
  end loop;
 end loop;
end $$;
-- Non-owner Personal privacy and exact Team IDs under real authenticated contexts.
do $$declare u uuid;x record;found0 boolean;begin
 foreach u in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008']::uuid[] loop
  perform set_config('request.jwt.claim.sub',u::text,true);
  assert not exists(select 1 from public.decisions where id=pg_temp.da_id('Personal'));
  for x in select * from dr_known loop
   execute format('select exists(select 1 from public.%I where %I=%L)',x.table_name,x.key_name,x.key_value) into found0;
   assert not found0;
  end loop;
  assert not exists(select 1 from public.decisions d join public.decision_links l on d.id=l.decision_id);
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert exists(select 1 from public.decisions where id=pg_temp.da_id('Team'));
 assert not exists(select 1 from public.decisions where id=pg_temp.da_id('Personal'));
end $$;
reset role;
-- With hypothetical writes, existing invoker FK/history guards can reject before
-- the INSERT policy check. Both fail closed; normal-grant attacks above require 42501.
create function pg_temp.dr_accidental_denied(command text) returns void language plpgsql as $$begin
 begin execute command;exception when insufficient_privilege or foreign_key_violation or check_violation then return;end;
 raise exception 'Unexpected accidental-grant write';end $$;
-- Restrictive RLS is independently effective even with accidental broad grants.
do $$declare t text;begin foreach t in array array['decisions','decision_options','decision_participants','decision_links','artifact_decision_sources'] loop
 execute format('grant insert,update,delete on public.%I to authenticated',t);
 execute format('create policy dr_accidental on public.%I for all to authenticated using(true) with check(true)',t);
end loop;end $$;
set local role authenticated;
do $$declare x record;n bigint;begin for x in select * from dr_known loop
 execute format('update public.%I set %I=%I where %I=%L',x.table_name,x.key_name,x.key_name,x.key_name,x.key_value);get diagnostics n=row_count;assert n=0;
 execute format('delete from public.%I where %I=%L',x.table_name,x.key_name,x.key_value);get diagnostics n=row_count;assert n=0;
 perform pg_temp.dr_accidental_denied(format('insert into public.%I select * from public.%I where %I=%L',x.table_name,x.table_name,x.key_name,x.key_value));
end loop;end $$;
reset role;
do $$declare t text;begin foreach t in array array['decisions','decision_options','decision_participants','decision_links','artifact_decision_sources'] loop
 execute format('drop policy dr_accidental on public.%I',t);execute format('revoke insert,update,delete on public.%I from authenticated',t);
end loop;end $$;
-- A visible Decision cannot disclose a source when Artifact visibility is denied.
create policy dr_artifact_hidden on public.artifacts as restrictive for select to authenticated using(false);
set local role authenticated;
do $$begin assert exists(select 1 from public.decisions where id=pg_temp.da_id('Team'));assert not exists(select 1 from public.artifact_decision_sources);end $$;
reset role;
drop policy dr_artifact_hidden on public.artifacts;
-- The real M8 reviewer Version exception must not expose an inaccessible Decision.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
create temporary table dr_submission as select public.submit_artifact((payload#>>'{artifact,id}')::uuid,(payload#>>'{version,id}')::uuid,(payload#>>'{artifact,activity_instance_id}')::uuid) payload from dr_record;
reset role;
savepoint dr_reviewer_isolation;
create temporary table dr_project_memberships as select id,status,ends_at from public.project_memberships where user_id='00000000-0000-4000-8000-000000006002';
update public.project_memberships set status='inactive',ends_at=clock_timestamp() where id in (select id from dr_project_memberships);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert exists(select 1 from public.artifact_versions where id=(select (payload#>>'{version,id}')::uuid from dr_record));
 assert not exists(select 1 from public.decisions where id=pg_temp.da_id('Team'));
 assert not exists(select 1 from public.artifact_decision_sources);
end $$;
reset role;
rollback to dr_reviewer_isolation;
-- Inactive/future/expired Master scope is not a permanent creator grant.
create temporary table dr_master_memberships as select id,membership_role from public.team_memberships where user_id='00000000-0000-4000-8000-000000006002' and status='active';
-- Remove the fixture's independent member access while testing role-only scope.
update public.team_memberships set status='removed',left_at=clock_timestamp(),removed_by='00000000-0000-4000-8000-000000006009' where id in (select id from dr_master_memberships);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert not exists(select 1 from public.decisions where id=pg_temp.da_id('Team'));end $$;
reset role;
-- Historical owner/finalizer removed: all child rows survive but grant no access.
create temporary table dr_history as select to_jsonb(d) decision,(select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p where p.decision_id=d.id) participants from public.decisions d where d.id=pg_temp.da_id('Team');
-- Trusted closure avoids attempting management with the intentionally revoked actor.
update public.team_memberships set status='removed',left_at=clock_timestamp(),removed_by='00000000-0000-4000-8000-000000006002' where user_id='00000000-0000-4000-8000-000000006009' and status='active';
update public.teams set team_lead_user_id=null where team_lead_user_id='00000000-0000-4000-8000-000000006009';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare x record;found0 boolean;begin
 for x in select * from dr_known loop
  execute format('select exists(select 1 from public.%I where %I=%L)',x.table_name,x.key_name,x.key_value) into found0;assert not found0;
 end loop;
 perform pg_temp.dr_denied(format('select public.create_team_decision_record_artifact(%L)',pg_temp.da_id('Team')));
end $$;
reset role;
do $$begin
 assert (select decision from dr_history)=(select to_jsonb(d) from public.decisions d where id=pg_temp.da_id('Team'));
 assert (select participants from dr_history)=(select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p where decision_id=pg_temp.da_id('Team'));
end $$;
set local role anon;
select pg_temp.dr_denied('select * from public.decisions');
select pg_temp.dr_denied('select * from public.artifact_decision_sources');
reset role;
do $$declare t text;begin foreach t in array array['decisions','decision_options','decision_participants','decision_links','artifact_decision_sources'] loop
 assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass);
 assert not has_table_privilege('authenticated','public.'||t,'insert,update,delete');
end loop;
assert exists(select 1 from pg_proc where oid='public.can_read_decision(uuid)'::regprocedure and prosecdef and provolatile='s' and proconfig=array['search_path=""']);
assert not has_function_privilege('anon','public.can_read_decision(uuid)','execute');
end $$;
select 'M10.15 Decision RLS parent-scope/Personal/children/source-both-sides/CRUD/history PASS';
rollback;
