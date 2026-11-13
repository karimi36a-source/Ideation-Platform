-- Canonical deterministic M8 fixture is prepended. No hosted identities.
reset role;
create temporary table privacy_entries(label text primary key,payload jsonb);
grant select,insert on privacy_entries to authenticated,anon;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into privacy_entries select 'Personal',public.create_scamper_entry((select id from instances where label='Individual'),'SUBSTITUTE','Private original','Private proposal','Private result');
insert into privacy_entries select 'Team',public.create_scamper_entry((select id from instances where label='Team'),'COMBINE','Team original','Team proposal','Team result');

-- M9.17: assert the original canonical creation result, before any edits.
do $$declare row0 jsonb:=(select payload from privacy_entries where label='Personal');begin
 assert row0->>'scamper_type'='SUBSTITUTE';
 assert row0->>'original_element'='Private original';
 assert row0->>'proposed_change'='Private proposal';
 assert row0->>'result_text'='Private result';
 assert row0->>'created_by'='00000000-0000-4000-8000-000000006004';
 assert (row0->>'activity_instance_id')::uuid=(select id from instances where label='Individual');
 assert (row0->>'project_id')::uuid=(select (payload->>'id')::uuid from logged_projects where label='Individual');
 assert (row0->>'workspace_id')::uuid=(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual');
 assert row0->>'status'='active' and row0->>'archived_at' is null and row0->>'idea_object_id' is null;
 assert public.list_scamper_entries((row0->>'activity_instance_id')::uuid)=jsonb_build_array(row0);
end $$;

do $$declare label0 text;begin
 foreach label0 in array array['Personal','Team'] loop
  assert public.get_scamper_entry((select (payload->>'id')::uuid from privacy_entries where label=label0))=(select payload from privacy_entries where label=label0);
 end loop;
end $$;
-- Team Lead has current Team AND Project authority; this does not expose Personal.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert public.get_scamper_entry((select (payload->>'id')::uuid from privacy_entries where label='Team'))=(select payload from privacy_entries where label='Team');
 begin perform public.get_scamper_entry((select (payload->>'id')::uuid from privacy_entries where label='Personal'));raise exception 'Team Lead Personal bypass';exception when insufficient_privilege then null;end;
end $$;
-- Admin, assigned/unrelated Master, Team B and contextual Mentor: exact IDs
-- cannot substitute for canonical Activity/Project/Workspace authority.
do $$declare actor0 text;label0 text;entry0 uuid;message0 text;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  foreach label0 in array array['Personal','Team'] loop
   select (payload->>'id')::uuid into entry0 from privacy_entries where label=label0;
   begin perform public.get_scamper_entry(entry0);raise exception 'Foreign fetch';exception when insufficient_privilege then get stacked diagnostics message0=message_text;assert message0='Resource unavailable';end;
   begin perform public.update_scamper_entry(entry0,'{"resultText":"Stolen"}');raise exception 'Foreign update';exception when insufficient_privilege then null;end;
   begin perform public.promote_scamper_entry_to_idea(entry0);raise exception 'Foreign promotion';exception when insufficient_privilege then null;end;
  end loop;
  begin perform public.get_scamper_entry('00000000-0000-4000-8000-000000999999');raise exception 'Missing fetch';exception when insufficient_privilege then get stacked diagnostics message0=message_text;assert message0='Resource unavailable';end;
  begin perform * from public.scamper_entries where id=(select (payload->>'id')::uuid from privacy_entries where label='Personal');raise exception 'Direct ID SELECT';exception when insufficient_privilege then null;end;
  begin perform * from public.scamper_entries where created_by='00000000-0000-4000-8000-000000006004';raise exception 'Owner enumeration';exception when insufficient_privilege then null;end;
  begin perform * from public.scamper_entries where workspace_id=(select (payload->>'workspace_id')::uuid from privacy_entries where label='Team');raise exception 'Team enumeration';exception when insufficient_privilege then null;end;
  begin update public.scamper_entries set created_by=actor0::uuid;raise exception 'Provenance update';exception when insufficient_privilege then null;end;
  begin delete from public.scamper_entries;raise exception 'Direct DELETE';exception when insufficient_privilege then null;end;
  begin insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
   select (payload->>'activity_instance_id')::uuid,(payload->>'project_id')::uuid,(payload->>'workspace_id')::uuid,actor0::uuid,'SUBSTITUTE','','','' from privacy_entries where label='Personal';raise exception 'Forged INSERT';exception when insufficient_privilege then null;end;
 end loop;
end $$;

-- M9.17: canonical list retrieval fails closed for all non-owner identities.
set local role authenticated;
do $$declare actor0 text;message0 text;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006005','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  begin perform public.list_scamper_entries((select (payload->>'activity_instance_id')::uuid from privacy_entries where label='Personal'));raise exception 'Personal list leak';
  exception when insufficient_privilege then get stacked diagnostics message0=message_text;assert message0='Resource unavailable';end;
 end loop;
end $$;

-- A2's own-Team relationship and same Cohort do not expose A1's Personal source.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 begin perform public.update_scamper_entry((select (payload->>'id')::uuid from privacy_entries where label='Personal'),'{"resultText":"Stolen"}');raise exception 'Peer update';exception when insufficient_privilege then null;end;
 begin perform public.promote_scamper_entry_to_idea((select (payload->>'id')::uuid from privacy_entries where label='Personal'));raise exception 'Peer promote';exception when insufficient_privilege then null;end;
end $$;
-- A valid scoped Master still needs the existing Team + Project access paths.
-- Trusted test relationships explicitly supply those prerequisites, no new policy.
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006002','participant','active' from acceptance_cohorts where label='Test';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006002','member');
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006002' from logged_projects where label='Team';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert public.get_scamper_entry((select (payload->>'id')::uuid from privacy_entries where label='Team'))=(select payload from privacy_entries where label='Team');
 begin perform public.get_scamper_entry((select (payload->>'id')::uuid from privacy_entries where label='Personal'));raise exception 'Scoped Master Personal bypass';exception when insufficient_privilege then null;end;
end $$;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare entry0 uuid:=(select (payload->>'id')::uuid from privacy_entries where label='Team');begin
 begin perform public.get_scamper_entry(entry0);raise exception 'Removed read';exception when insufficient_privilege then null;end;
 begin perform public.update_scamper_entry(entry0,'{"resultText":"Stale"}');raise exception 'Removed update';exception when insufficient_privilege then null;end;
 begin perform public.promote_scamper_entry_to_idea(entry0);raise exception 'Removed promote';exception when insufficient_privilege then null;end;
 begin perform * from public.scamper_entries where id=entry0;raise exception 'Removed DB bypass';exception when insufficient_privilege then null;end;
 assert public.get_scamper_entry((select (payload->>'id')::uuid from privacy_entries where label='Personal'))=(select payload from privacy_entries where label='Personal');
end $$;
set local role anon;
do $$begin
 begin perform public.get_scamper_entry((select (payload->>'id')::uuid from privacy_entries where label='Personal'));raise exception 'Anonymous RPC';exception when insufficient_privilege then null;end;
 begin perform * from public.scamper_entries;raise exception 'Anonymous SELECT';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare f regprocedure;begin
 foreach f in array array['public.get_scamper_entry(uuid)'::regprocedure,'public.create_scamper_entry(uuid,public.scamper_lens,text,text,text)'::regprocedure,'public.update_scamper_entry(uuid,jsonb)'::regprocedure,'public.promote_scamper_entry_to_idea(uuid)'::regprocedure] loop
  assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid=f);
  assert has_function_privilege('authenticated',f,'EXECUTE');
  assert not has_function_privilege('anon',f,'EXECUTE') and not has_function_privilege('service_role',f,'EXECUTE');
 end loop;
 assert (select relrowsecurity from pg_class where oid='public.scamper_entries'::regclass);
 assert not has_table_privilege('authenticated','public.scamper_entries','SELECT');
 assert not has_table_privilege('authenticated','public.scamper_entries','INSERT');
 assert not has_table_privilege('authenticated','public.scamper_entries','UPDATE');
 assert not has_table_privilege('authenticated','public.scamper_entries','DELETE');
 assert not exists(select 1 from public.scamper_entries where idea_object_id is not null),'Unauthorized promotion side effect';
 assert (select count(*) from public.scamper_entries)=2;
end $$;
-- M9.15: exercise RLS independently of table ACLs. These hostile grants and
-- permissive policy exist only inside this rolled-back disposable fixture.
update public.scamper_entries set status='archived',archived_at=clock_timestamp()
 where id=(select (payload->>'id')::uuid from privacy_entries where label='Team');
create temporary table m915_before as select * from public.scamper_entries;
grant select on m915_before to authenticated;
grant select,insert,update,delete on public.scamper_entries to authenticated,anon;
create policy m915_hostile on public.scamper_entries for all to authenticated,anon using(true) with check(true);
set local role authenticated;
do $$declare actor0 text;entry0 uuid;scope0 uuid;column0 text;affected integer;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  assert (select count(*) from public.scamper_entries)=0,'Broad enumeration';
  assert (select count(*) from public.scamper_entries where created_by='00000000-0000-4000-8000-000000006004')=0,'Creator filter leak';
  foreach entry0 in array array[(select (payload->>'id')::uuid from privacy_entries where label='Personal'),(select (payload->>'id')::uuid from privacy_entries where label='Team'),'00000000-0000-4000-8000-000000999999'::uuid] loop
   assert (select count(*) from public.scamper_entries where id=entry0)=0,'Exact ID leak';
   foreach column0 in array array['id','created_by','activity_instance_id','project_id','workspace_id','idea_object_id'] loop
    execute format('update public.scamper_entries set %I=$1 where id=$2',column0) using '00000000-0000-4000-8000-000000999999'::uuid,entry0;
    get diagnostics affected=row_count;assert affected=0,'Identity/scope/link mutation';
   end loop;
   update public.scamper_entries set status='active',archived_at=null where id=entry0;assert not found,'Lifecycle mutation';
   delete from public.scamper_entries where id=entry0;assert not found,'History deletion';
  end loop;
  for scope0 in select (payload->>'workspace_id')::uuid from privacy_entries loop
   assert (select count(*) from public.scamper_entries where workspace_id=scope0)=0,'Workspace filter leak';
  end loop;
  assert not exists(select 1 from public.scamper_entries s join public.activity_instances a on a.id=s.activity_instance_id),'Join leakage';
  begin
   insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,updated_by,scamper_type,original_element,proposed_change,result_text)
   select activity_instance_id,project_id,workspace_id,created_by,created_by,scamper_type,original_element,proposed_change,result_text from m915_before limit 1;
   raise exception 'Hostile grant INSERT bypass';
  exception when insufficient_privilege or check_violation then null;end;
 end loop;
end $$;
-- A currently authorized owner still reads through canonical RPCs while the
-- restrictive table policy denies raw SELECT, even under accidental ACLs.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert jsonb_array_length(public.list_scamper_entries((select (payload->>'activity_instance_id')::uuid from privacy_entries where label='Personal')))=1;
 begin perform public.list_scamper_entries((select (payload->>'activity_instance_id')::uuid from privacy_entries where label='Team'));raise exception 'Removed creator list bypass';exception when insufficient_privilege then null;end;
end $$;
set local role anon;
do $$begin assert (select count(*) from public.scamper_entries)=0;end $$;
reset role;
do $$begin
 assert not exists((select * from public.scamper_entries except select * from m915_before) union all (select * from m915_before except select * from public.scamper_entries)),'Attack rewrote history';
 assert (select not polpermissive and pg_get_expr(polqual,polrelid)='false' and pg_get_expr(polwithcheck,polrelid)='false' from pg_policy where polrelid='public.scamper_entries'::regclass and polname='scamper_client_deny');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.list_scamper_entries(uuid)'::regprocedure);
 assert not has_function_privilege('authenticated','private.require_scamper_write(uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.list_scamper_entries(uuid)','EXECUTE');
end $$;
rollback;
\echo M9.15 restrictive RLS hostile-grant CRUD/exact-ID/filter/count/join/revoked-creator/history PASS
\echo AT-SCAMPER-002 PASS — Personal/Team exact-ID/direct-DB/privacy/revocation
\echo M9 SCAMPER source privacy retained; selected sharing uses standard M13.6 acceptance

\echo M9.17 AT-SCAMPER-001 structured canonical persistence/retrieval PASS
\echo M9.17 AT-SCAMPER-002 owner-only RPC/list/exact-ID/DB/enumeration PASS
