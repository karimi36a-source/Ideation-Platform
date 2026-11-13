-- Canonical M8 fixture is prepended; every fixture rolls back.
reset role;
create temporary table promotion_saved(label text primary key,payload jsonb);
grant select,insert on promotion_saved to authenticated;
create temporary table promotion_outputs as select jsonb_build_object('artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),'baselines',(select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x),'versions',(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v),'outputs',(select jsonb_agg(to_jsonb(o) order by id) from public.activity_outputs o),'activities',(select jsonb_agg(to_jsonb(a) order by id) from public.activity_instances a)) payload;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into promotion_saved select 'Personal',(select payload from bc_entries where label='Personal');
insert into promotion_saved select 'Team',(select to_jsonb(b) from public.brainstorm_entries b where id=(select (payload->>'id')::uuid from bc_entries where label='R1'));
insert into promotion_saved select 'Idea',public.promote_brainstorm_entry_to_idea((payload->>'id')::uuid) from promotion_saved where label='Personal';
-- A different authorized contributor promotes; source authorship remains A1.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into promotion_saved select 'TeamIdea',public.promote_brainstorm_entry_to_idea((payload->>'id')::uuid) from promotion_saved where label='Team';
reset role;
do $$declare s public.brainstorm_entries;o public.development_objects;label0 text;begin
 foreach label0 in array array['Personal','Team'] loop
  select * into s from public.brainstorm_entries where id=(select (payload->>'id')::uuid from promotion_saved where label=label0);
  select * into o from public.development_objects where id=s.development_object_id;
  assert o.object_type='IDEA' and o.project_id=s.project_id and o.workspace_id=s.workspace_id and o.created_by=s.created_by;
  assert o.origin_type='BRAINSTORM' and o.origin_reference_id=s.id and o.current_version_number=1;
  assert o.status is null and o.verification_status is null and o.archived_at is null;
  assert o.title=s.content and o.content=s.content;
  assert (to_jsonb(s)-array['development_object_id','updated_at','updated_by'])=(select payload-array['development_object_id','updated_at','updated_by'] from promotion_saved where label=label0);
  assert (select count(*) from public.development_objects where origin_type='BRAINSTORM' and origin_reference_id=s.id)=1;
  assert not exists(select 1 from public.idea_details where development_object_id=o.id),'Optional typed details were invented';
  assert (select count(*) from public.change_log where entity_id=o.id and change_type='OBJECT_CREATED' and reason='BRAINSTORM entry '||s.id::text and changed_by=case when label0='Team' then '00000000-0000-4000-8000-000000006005'::uuid else s.created_by end)=1;
 end loop;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare label0 text;o jsonb;begin
 foreach label0 in array array['Personal','Team'] loop
  o:=public.promote_brainstorm_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label=label0));
  assert o=(select payload from promotion_saved where label=case when label0='Personal' then 'Idea' else 'TeamIdea' end),'Retry created/replaced canonical Idea';
 end loop;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
update public.brainstorm_entries set content='Later source edit' where id=(select (payload->>'id')::uuid from promotion_saved where label='Personal');
reset role;
do $$begin
 assert (select to_jsonb(o) from public.development_objects o where id=(select (payload->>'id')::uuid from promotion_saved where label='Idea'))=(select payload from promotion_saved where label='Idea'),'Automatic synchronization';
 assert jsonb_build_object('artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),'baselines',(select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x),'versions',(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v),'outputs',(select jsonb_agg(to_jsonb(o) order by id) from public.activity_outputs o),'activities',(select jsonb_agg(to_jsonb(a) order by id) from public.activity_instances a))=(select payload from promotion_outputs),'Historical output/Activity changed';
end $$;
-- Exact IDs, roles and related Cohort knowledge do not authorize promotion.
set local role authenticated;
do $$declare actor0 text;label0 text;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  foreach label0 in array array['Personal','Team'] loop
   begin perform public.promote_brainstorm_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label=label0));raise exception 'Foreign promotion';exception when insufficient_privilege then null;end;
  end loop;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 begin perform public.promote_brainstorm_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Personal'));raise exception 'Personal peer promotion';exception when insufficient_privilege then null;end;
 begin perform public.promote_brainstorm_entry_to_idea('00000000-0000-4000-8000-000000999999');raise exception 'Unknown ID';exception when insufficient_privilege then null;end;
end $$;
-- Unrevealed Team sources never become Team-visible Objects.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.promote_brainstorm_entry_to_idea((select (payload->>'id')::uuid from bc_entries where label='R3'));raise exception 'Unrevealed promotion';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
do $$begin assert not exists(select 1 from public.development_objects where origin_reference_id=(select (payload->>'id')::uuid from bc_entries where label='R3'));end $$;
-- Trusted malformed link and archive fixtures remain rollback-only.
reset role;
select set_config('request.jwt.claim.sub','',true);
do $$begin
 begin
  update public.brainstorm_entries set status='archived',archived_at=now() where id=(select (payload->>'id')::uuid from promotion_saved where label='Personal');
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.promote_brainstorm_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Personal'));
  raise exception 'Archive promotion';
 exception when object_not_in_prerequisite_state then null;end;
 begin
  update public.brainstorm_entries set development_object_id=(select (payload->>'id')::uuid from logged_objects where label='Individual Idea') where id=(select (payload->>'id')::uuid from promotion_saved where label='Personal');
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.promote_brainstorm_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Personal'));
  raise exception 'Inconsistent link accepted';
 exception when unique_violation then null;end;
end $$;
-- Force history failure: Object insert and source linkage must roll back together.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into promotion_saved select 'Rollback',public.create_brainstorm_entry((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Personal'),'Rollback','private');
reset role;
create function pg_temp.fail_promotion_log() returns trigger language plpgsql as $$begin raise exception 'Forced history failure' using errcode='P0001';end $$;
create trigger test_promotion_failure before insert on public.change_log for each row execute function pg_temp.fail_promotion_log();
set local role authenticated;
do $$begin begin perform public.promote_brainstorm_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Rollback'));raise exception 'Expected forced failure' using errcode='XX000';exception when raise_exception then null;end;end $$;
reset role;
drop trigger test_promotion_failure on public.change_log;
do $$begin
 assert (select development_object_id is null from public.brainstorm_entries where id=(select (payload->>'id')::uuid from promotion_saved where label='Rollback'));
 assert not exists(select 1 from public.development_objects where origin_reference_id=(select (payload->>'id')::uuid from promotion_saved where label='Rollback')),'Orphan Idea';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.promote_brainstorm_entry_to_idea((select (payload->>'id')::uuid from promotion_saved where label='Team'));raise exception 'Removed retry';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from promotion_saved where label='TeamIdea')),'Removed direct Object read';
 begin update public.brainstorm_entries set development_object_id=null;raise exception 'Direct mutation';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.promote_brainstorm_entry_to_idea(uuid)'::regprocedure);
 assert has_function_privilege('authenticated','public.promote_brainstorm_entry_to_idea(uuid)','EXECUTE');
 assert not has_function_privilege('anon','public.promote_brainstorm_entry_to_idea(uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.promote_brainstorm_entry_to_idea(uuid)','EXECUTE');
 assert not has_table_privilege('authenticated','public.brainstorm_entries','UPDATE');
end $$;
do $$begin
 assert (select proargnames=array['target_entry']::text[] and prorettype='jsonb'::regtype from pg_proc where oid='public.promote_brainstorm_entry_to_idea(uuid)'::regprocedure);
 assert not exists(select 1 from public.development_objects where origin_type='BRAINSTORM' and origin_reference_id=(select (payload->>'id')::uuid from bc_entries where label='Child'));
end $$;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform public.promote_brainstorm_entry_to_idea('00000000-0000-4000-8000-000000999999');raise exception 'Anonymous RPC';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
\echo AT-BRAIN-004 PASS: Personal private / Team revealed / unrevealed denied / retry / rollback / authorship / privacy
