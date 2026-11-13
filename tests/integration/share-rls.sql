-- No raw table read is required: safe recipient projection and source history
-- use their existing authorized RPCs, preserving internal provenance privacy.
reset role;
-- The reused M13.5 fixture deliberately grants SELECT for its RLS probe.
-- Restore the migration baseline, already checked before loading the fixture.
revoke all on public.shares,public.share_snapshots from public,anon,authenticated,service_role;
create temporary table rls_context(label text primary key,payload jsonb);
grant select on rls_context to authenticated;
create function pg_temp.rls_id(label0 text) returns uuid language sql as $$select (payload->>'id')::uuid from rls_context where label=$1$$;
create function pg_temp.rls_denied(statement0 text) returns void language plpgsql as $$begin
 begin execute statement0;raise exception 'Direct authenticated operation succeeded: %',statement0;
 exception when insufficient_privilege then null;end;
end$$;
do $$declare t text;r text;begin
 foreach t in array array['shares','share_snapshots'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass);
  assert exists(select 1 from pg_policy where polrelid=('public.'||t)::regclass and not polpermissive and polcmd='*' and pg_get_expr(polqual,polrelid)='false' and pg_get_expr(polwithcheck,polrelid)='false');
  foreach r in array array['anon','authenticated','service_role'] loop
   assert not has_table_privilege(r,'public.'||t,'SELECT,INSERT,UPDATE,DELETE');
  end loop;
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Team Lead canonical creation and Personal-owner creation still work.
insert into rls_context select 'Comment',public.share_entity(pg_temp.share_request('ARTIFACT',pg_temp.shared_id('Artifact'),permission0=>'COMMENT')||jsonb_build_object('sourceVersionId',pg_temp.shared_id('V2')));
insert into rls_context select 'Personal',public.share_entity(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent'),target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
do $$declare r jsonb;begin
 r:=public.list_entity_shares(jsonb_build_object('entityType','ARTIFACT','entityId',pg_temp.shared_id('Artifact')));
 assert r->>'entityId'=pg_temp.shared_id('Artifact')::text and jsonb_array_length(r->'shares')>0;
 -- The Personal source owner is also an authorized destination Team member.
 assert public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.rls_id('Personal')))->>'allowed'='true';
end$$;
insert into rls_context select 'Snapshot',jsonb_build_object('id',id) from public.share_snapshots where share_id=pg_temp.rls_id('Comment');
insert into rls_context select 'Before',jsonb_build_object('shares',(select jsonb_agg(to_jsonb(s) order by id) from public.shares s),'snapshots',(select jsonb_agg(to_jsonb(s) order by id) from public.share_snapshots s),'audit',(select jsonb_agg(to_jsonb(a) order by id) from public.audit_events a));
-- Active recipient reads only its frozen projection, never internal provenance.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$declare r jsonb;begin
 r:=public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.rls_id('Comment')));
 assert r->>'allowed'='true' and r->>'canComment'='true' and r->>'canEdit'='false' and r->>'canReshare'='false';
 assert r->>'sourceVersionId'=pg_temp.shared_id('V2')::text;
 assert not r?'provenance' and not r?'sourceWorkspaceId' and r::text not like '%source_workspace_id%';
 perform pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.rls_id('Snapshot')));
 perform pg_temp.shared_denied(jsonb_build_object('shareId','ffffffff-ffff-4fff-8fff-ffffffffffff'));
 perform pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('ArtifactLive')));
 perform pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Collaborate')));
end$$;
-- Baseline ACL attacks: source owners, ordinary source members, recipients,
-- scoped/unrelated Masters, Admin and Mentor all lack direct table mutations.
do $$declare actor0 uuid;statement0 text;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006004'::uuid,'00000000-0000-4000-8000-000000006005'::uuid,'00000000-0000-4000-8000-000000006006'::uuid,'00000000-0000-4000-8000-000000006001'::uuid,'00000000-0000-4000-8000-000000006002'::uuid,'00000000-0000-4000-8000-000000006003'::uuid,'00000000-0000-4000-8000-000000006008'::uuid] loop
  perform set_config('request.jwt.claim.sub',actor0::text,true);
  perform pg_temp.rls_denied(format('insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode,shared_by,source_workspace_id) values(''ARTIFACT'',%L,''TEAM'',%L,''VIEW'',''SNAPSHOT'',%L,%L)',pg_temp.shared_id('Artifact'),(select payload->>'teamId' from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006004',(select payload->>'source_workspace_id' from shared_access_context where label='View')));
  foreach statement0 in array array[
   'select * from public.shares where id='||quote_literal(pg_temp.rls_id('Comment')),
   'select * from public.share_snapshots where id='||quote_literal(pg_temp.rls_id('Snapshot')),
   'update public.shares set permission_level=''COMMENT'' where id='||quote_literal(pg_temp.shared_id('View')),
   'update public.shares set permission_level=''COLLABORATE'' where id='||quote_literal(pg_temp.rls_id('Comment')),
   'update public.shares set destination_id=shared_by,destination_type=''USER'' where id='||quote_literal(pg_temp.rls_id('Comment')),
   'update public.shares set shared_entity_id=gen_random_uuid(),source_workspace_id=gen_random_uuid(),shared_by=gen_random_uuid() where id='||quote_literal(pg_temp.rls_id('Comment')),
   'update public.shares set share_mode=''LIVE_REFERENCE'' where id='||quote_literal(pg_temp.rls_id('Comment')),
   'update public.shares set revoked_at=null,revoked_by=null where id='||quote_literal(pg_temp.shared_id('Comment')),
   'update public.shares set revoked_at=clock_timestamp(),revoked_by=gen_random_uuid() where id='||quote_literal(pg_temp.rls_id('Comment')),
   'update public.share_snapshots set source_version_id='||quote_literal(pg_temp.shared_id('V3'))||',snapshot_data=''{}'' where id='||quote_literal(pg_temp.rls_id('Snapshot')),
   'insert into public.share_snapshots(share_id,source_version_id,snapshot_data) values('||quote_literal(pg_temp.rls_id('Comment'))||','||quote_literal(pg_temp.shared_id('V2'))||',''{}'')',
   'delete from public.shares where id='||quote_literal(pg_temp.rls_id('Comment')),
   'delete from public.share_snapshots where id='||quote_literal(pg_temp.rls_id('Snapshot')),
   'insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata) values('||quote_literal(actor0)||',''SHARE_CREATED'',''share'','||quote_literal(pg_temp.rls_id('Comment'))||',''share'','||quote_literal(pg_temp.rls_id('Comment'))||',''{}'')',
   'insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata) values('||quote_literal(actor0)||',''SHARE_REVOKED'',''share'','||quote_literal(pg_temp.rls_id('Comment'))||',''share'','||quote_literal(pg_temp.rls_id('Comment'))||',''{}'')',
   'update public.audit_events set actor_user_id='||quote_literal(actor0)||' where entity_id='||quote_literal(pg_temp.rls_id('Comment')),
   'delete from public.audit_events where entity_id='||quote_literal(pg_temp.rls_id('Comment'))
  ] loop perform pg_temp.rls_denied(statement0);end loop;
 end loop;
end$$;
reset role;
do $$begin assert (select payload from rls_context where label='Before')=jsonb_build_object('shares',(select jsonb_agg(to_jsonb(s) order by id) from public.shares s),'snapshots',(select jsonb_agg(to_jsonb(s) order by id) from public.share_snapshots s),'audit',(select jsonb_agg(to_jsonb(a) order by id) from public.audit_events a));end$$;
-- Test-only accidental grant + permissive policy cannot override restrictive RLS.
savepoint accidental_grants;
grant select,insert,update,delete on public.shares,public.share_snapshots to authenticated;
create policy test_accidental_shares on public.shares for all to authenticated using(true) with check(true);
create policy test_accidental_snapshots on public.share_snapshots for all to authenticated using(true) with check(true);
set local role authenticated;
do $$declare actor0 uuid;t text;n bigint;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006004'::uuid,'00000000-0000-4000-8000-000000006006'::uuid] loop
  perform set_config('request.jwt.claim.sub',actor0::text,true);
  foreach t in array array['shares','share_snapshots'] loop
   execute format('select count(*) from public.%I',t) into n;assert n=0,'Raw internal records exposed';
   execute format('update public.%I set id=id',t);get diagnostics n=row_count;assert n=0;
   execute format('delete from public.%I',t);get diagnostics n=row_count;assert n=0;
  end loop;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
 assert public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.rls_id('Comment')))->>'allowed'='true';
end$$;
reset role;
rollback to savepoint accidental_grants;
-- Current authorization is rechecked on all canonical read/mutation routes.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.revoke_share(jsonb_build_object('shareId',pg_temp.rls_id('Comment')));
select public.revoke_share(jsonb_build_object('shareId',pg_temp.shared_id('File')));
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.rls_id('Comment')));
do $$begin
 perform pg_temp.rls_denied(format('select public.add_share_comment(%L::jsonb)',jsonb_build_object('shareId',pg_temp.rls_id('Comment'),'content','Revoked')));
 assert not public.authorize_shared_file_access(pg_temp.shared_id('FileRow'));
 perform pg_temp.rls_denied(format('select public.list_entity_shares(%L::jsonb)',jsonb_build_object('entityType','ARTIFACT','entityId',pg_temp.shared_id('Artifact'))));
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
update public.role_assignments set ends_at=clock_timestamp()-interval '1 second' where id=(select id from shared_master);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Master')));
update public.role_assignments set ends_at=null,status='inactive' where id=(select id from shared_master);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('Master')));
update public.role_assignments set status='active' where id=(select id from shared_master);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006','M13.19 destination removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.shared_denied(jsonb_build_object('shareId',pg_temp.shared_id('View')));
do $$begin assert not public.authorize_shared_file_access(pg_temp.shared_id('FileRow'));end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare r jsonb;begin
 assert exists(select 1 from public.share_snapshots where share_id=pg_temp.rls_id('Comment') and source_version_id=pg_temp.shared_id('V2'));
 r:=public.list_entity_shares(jsonb_build_object('entityType','ARTIFACT','entityId',pg_temp.shared_id('Artifact')));
 assert exists(select 1 from jsonb_array_elements(r->'shares') s where s->>'shareId'=pg_temp.rls_id('Comment')::text and s->>'state'='REVOKED');
end$$;
select 'M13.19 Share-Snapshot raw-RLS/forgery/escalation/accidental-grants/safe-RPC/revocation/destination/audit/history PASS';
