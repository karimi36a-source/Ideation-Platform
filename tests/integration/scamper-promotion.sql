-- Canonical M8 fixture is prepended; every fixture rolls back.
reset role;
create temporary table promotion_saved(label text primary key,payload jsonb);
grant select,insert on promotion_saved to authenticated;
create temporary table promotion_outputs as select jsonb_build_object('versions',(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v),'outputs',(select jsonb_agg(to_jsonb(o) order by id) from public.activity_outputs o),'activities',(select jsonb_agg(to_jsonb(a) order by id) from public.activity_instances a)) payload;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into promotion_saved select 'Personal',public.create_scamper_entry((select id from instances where label='Individual'),'SUBSTITUTE','Original','Proposed','Result');
insert into promotion_saved select 'Team',public.create_scamper_entry((select id from instances where label='Team'),'COMBINE','Team original','Team proposal','Team result');
insert into promotion_saved select 'Idea',public.promote_scamper_entry_to_idea((payload->>'id')::uuid) from promotion_saved where label='Personal';
-- A different authorized contributor promotes; source authorship remains A1.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into promotion_saved select 'TeamIdea',public.promote_scamper_entry_to_idea((payload->>'id')::uuid) from promotion_saved where label='Team';
reset role;
do $$declare s public.scamper_entries;o public.development_objects;label0 text;begin
 foreach label0 in array array['Personal','Team'] loop
  select * into s from public.scamper_entries where id=(select (payload->>'id')::uuid from promotion_saved where label=label0);
  select * into o from public.development_objects where id=s.idea_object_id;
  assert o.object_type='IDEA' and o.project_id=s.project_id and o.workspace_id=s.workspace_id and o.created_by=s.created_by;
  assert o.origin_type='SCAMPER' and o.origin_reference_id=s.id and o.current_version_number=1;
  assert o.status is null and o.verification_status is null and o.archived_at is null;
  assert o.title=s.proposed_change and o.content::jsonb=jsonb_build_object('scamper_type',s.scamper_type,'original_element',s.original_element,'proposed_change',s.proposed_change,'result_text',s.result_text);
  assert (to_jsonb(s)-array['idea_object_id','updated_at','updated_by'])=(select payload-array['idea_object_id','updated_at','updated_by'] from promotion_saved where label=label0);
  assert (select count(*) from public.development_objects where origin_type='SCAMPER' and origin_reference_id=s.id)=1;
  assert not exists(select 1 from public.idea_details where development_object_id=o.id),'Optional typed details were invented';
  assert (select count(*) from public.change_log where entity_id=o.id and change_type='OBJECT_CREATED' and reason='SCAMPER entry '||s.id::text and changed_by=case when label0='Team' then '00000000-0000-4000-8000-000000006005'::uuid else s.created_by end)=1;
 end loop;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare label0 text;o jsonb;begin
 foreach label0 in array array['Personal','Team'] loop
  o:=public.promote_scamper_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label=label0));
  assert o=(select payload from promotion_saved where label=case when label0='Personal' then 'Idea' else 'TeamIdea' end),'Retry created/replaced canonical Idea';
 end loop;
end $$;
select public.update_scamper_entry((select (payload->>'id')::uuid from promotion_saved where label='Personal'),'{"resultText":"Later source edit"}');
reset role;
do $$begin
 assert (select to_jsonb(o) from public.development_objects o where id=(select (payload->>'id')::uuid from promotion_saved where label='Idea'))=(select payload from promotion_saved where label='Idea'),'Automatic synchronization';
 assert jsonb_build_object('versions',(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v),'outputs',(select jsonb_agg(to_jsonb(o) order by id) from public.activity_outputs o),'activities',(select jsonb_agg(to_jsonb(a) order by id) from public.activity_instances a))=(select payload from promotion_outputs),'Historical output/Activity changed';
end $$;
-- Exact IDs, roles and related Cohort knowledge do not authorize promotion.
set local role authenticated;
do $$declare actor0 text;label0 text;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  foreach label0 in array array['Personal','Team'] loop
   begin perform public.promote_scamper_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label=label0));raise exception 'Foreign promotion';exception when insufficient_privilege then null;end;
  end loop;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 begin perform public.promote_scamper_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Personal'));raise exception 'Personal peer promotion';exception when insufficient_privilege then null;end;
 begin perform public.promote_scamper_entry_to_idea('00000000-0000-4000-8000-000000999999');raise exception 'Unknown ID';exception when insufficient_privilege then null;end;
end $$;
-- Trusted malformed link and archive fixtures remain rollback-only.
reset role;
do $$begin
 begin
  update public.scamper_entries set status='archived',archived_at=now() where id=(select (payload->>'id')::uuid from promotion_saved where label='Personal');
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.promote_scamper_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Personal'));
  raise exception 'Archive promotion';
 exception when object_not_in_prerequisite_state then null;end;
 begin
  update public.scamper_entries set idea_object_id=(select (payload->>'id')::uuid from logged_objects where label='Individual Idea') where id=(select (payload->>'id')::uuid from promotion_saved where label='Personal');
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.promote_scamper_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Personal'));
  raise exception 'Inconsistent link accepted';
 exception when unique_violation then null;end;
end $$;
-- Force history failure: Object insert and source linkage must roll back together.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into promotion_saved select 'Rollback',public.create_scamper_entry((select id from instances where label='Individual'),'ADAPT','','','');
reset role;
create function pg_temp.fail_promotion_log() returns trigger language plpgsql as $$begin raise exception 'Forced history failure' using errcode='P0001';end $$;
create trigger test_promotion_failure before insert on public.change_log for each row execute function pg_temp.fail_promotion_log();
set local role authenticated;
do $$begin begin perform public.promote_scamper_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Rollback'));raise exception 'Expected forced failure' using errcode='XX000';exception when raise_exception then null;end;end $$;
reset role;
drop trigger test_promotion_failure on public.change_log;
do $$begin
 assert (select idea_object_id is null from public.scamper_entries where id=(select (payload->>'id')::uuid from promotion_saved where label='Rollback'));
 assert not exists(select 1 from public.development_objects where origin_reference_id=(select (payload->>'id')::uuid from promotion_saved where label='Rollback')),'Orphan Idea';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.promote_scamper_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Team'));raise exception 'Removed retry';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from promotion_saved where label='TeamIdea')),'Removed direct Object read';
 begin update public.scamper_entries set idea_object_id=null;raise exception 'Direct mutation';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.promote_scamper_entry_to_idea(uuid)'::regprocedure);
 assert has_function_privilege('authenticated','public.promote_scamper_entry_to_idea(uuid)','EXECUTE');
 assert not has_function_privilege('anon','public.promote_scamper_entry_to_idea(uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.promote_scamper_entry_to_idea(uuid)','EXECUTE');
 assert not has_table_privilege('authenticated','public.scamper_entries','UPDATE');
end $$;
rollback;
\echo M9.3 Personal/Team promotion authorship/provenance retry rollback privacy source/output preservation PASS
