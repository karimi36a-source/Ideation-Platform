-- Real source/Problem operations and real PostgreSQL persistence; all rolled back.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into sp_results select 'Personal',public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Personal'),pg_temp.sp_problem('Problem'));
insert into sp_results select label,public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry(label),pg_temp.sp_problem('Problem')) from unnest(array['S2','S3','Blank']) label;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into sp_results select 'Team',public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Team'),pg_temp.sp_problem('Team'));
reset role;
do $$declare x record;s public.brainstorm_entries;o public.development_objects;edge public.development_object_relationships;begin
 for x in select * from sp_results loop
  select * into s from public.brainstorm_entries where id=pg_temp.sp_entry(x.label);
  select * into o from public.development_objects where id=(x.payload->>'id')::uuid;
  assert to_jsonb(o)=x.payload and s.development_object_id=o.id;
  assert o.object_type='SOLUTION' and (o.project_id,o.workspace_id,o.created_by)=(s.project_id,s.workspace_id,s.created_by);
  assert o.origin_type='BRAINSTORM' and o.origin_reference_id=s.id;
  assert o.content=s.content and o.title=case when length(btrim(s.content))>0 then s.content else 'Brainstorm Solution' end;
  assert o.status is null and o.verification_status is null and o.metadata='{}' and o.current_version_number=1 and o.archived_at is null,'Evaluation/extra data';
  assert (select count(*) from public.development_object_relationships where source_object_id=o.id and relationship_type='SOLVES')=1;
  select * into edge from public.development_object_relationships where source_object_id=o.id and relationship_type='SOLVES';
  assert edge.target_object_id=pg_temp.sp_problem(case when x.label='Team' then 'Team' else 'Problem' end) and edge.status='active' and edge.project_id=o.project_id;
  assert not exists(select 1 from public.development_object_relationships where source_object_id=edge.target_object_id and target_object_id=o.id),'Automatic inverse';
  assert (select count(*) from public.activity_outputs where activity_instance_id=s.activity_instance_id and development_object_id=o.id and output_type='development_object')=1;
  assert (select count(*) from public.change_log where entity_id=o.id and change_type='OBJECT_CREATED')=1;
  assert exists(select 1 from public.change_log where entity_id=o.id and change_type='OBJECT_CREATED' and changed_by=case when x.label='Team' then '00000000-0000-4000-8000-000000006005'::uuid else s.created_by end and reason='BRAINSTORM entry '||s.id::text);
  assert (select count(*) from public.change_log where entity_id=edge.id and change_type='RELATIONSHIP_CREATED')=1;
  assert (to_jsonb(s)-array['development_object_id','updated_at','updated_by'])=(select payload-array['development_object_id','updated_at','updated_by'] from sp_source_before where label=x.label),'Source rewrite';
 end loop;
 assert (select count(distinct source_object_id) from public.development_object_relationships where target_object_id=pg_temp.sp_problem('Problem') and source_object_id in(select (payload->>'id')::uuid from sp_results))=4,'Multiple independent Solutions';
 assert (select count(distinct payload->>'id') from sp_results where label in('S2','S3'))=2,'Content deduplication';
end $$;
create temporary table sp_after as select pg_temp.bc_outputs() payload;
create temporary table sp_edges_after as select jsonb_agg(to_jsonb(e) order by id) payload from public.development_object_relationships e;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare x record;begin
 for x in select * from sp_results loop
  assert public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry(x.label),pg_temp.sp_problem(case when x.label='Team' then 'Team' else 'Problem' end))=x.payload,'Retry canonical identity';
 end loop;
end $$;
reset role;
do $$begin
 assert pg_temp.bc_outputs()=(select payload from sp_after),'Retry changed state';
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.development_object_relationships e)=(select payload from sp_edges_after),'Retry changed edges';
 assert not exists(select 1 from sp_problem_before p join public.development_objects o on o.id=(p.payload->>'id')::uuid where p.payload<>to_jsonb(o)),'Source Problem mutation';
 assert jsonb_build_object('artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),'links',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_object_links x))=(select payload from sp_artifacts_before),'Artifact/Solution Bank mutation';
end $$;
-- One Entry binds to one Object and one Problem; no repair/repoint on retry.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.promote_brainstorm_entry_to_idea(pg_temp.sp_entry('IdeaConflict'));
do $$begin
 begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('IdeaConflict'),pg_temp.sp_problem('Problem'));raise exception 'Idea link repointed';exception when unique_violation then null;end;
 begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Personal'),pg_temp.sp_problem('P2'));raise exception 'Different Problem';exception when unique_violation then null;end;
 begin perform public.promote_brainstorm_entry_to_idea(pg_temp.sp_entry('Personal'));raise exception 'Solution became Idea';exception when unique_violation then null;end;
end $$;
-- Exact missing/foreign/non-Problem IDs have identical safe denials.
do $$declare bad uuid;err text;baseline text;begin
 begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('S2'),gen_random_uuid());raise exception 'Unknown Problem';exception when insufficient_privilege then get stacked diagnostics baseline=message_text;end;
 foreach bad in array array[pg_temp.sp_problem('Individual Idea'),pg_temp.sp_problem('Case'),pg_temp.sp_problem('Team'),pg_temp.sp_problem('Team B')] loop
  begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('S2'),bad);raise exception 'Foreign/type bypass';exception when insufficient_privilege then get stacked diagnostics err=message_text;assert err=baseline and err='Resource unavailable';end;
 end loop;
 begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Team'),pg_temp.sp_problem('Team B'));raise exception 'Team A to Team B Problem';exception when insufficient_privilege then assert sqlerrm=baseline;end;
 begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Team'),pg_temp.sp_problem('Problem'));raise exception 'Team to Personal Problem';exception when insufficient_privilege then assert sqlerrm=baseline;end;
 begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('S2'),(select (payload->>'id')::uuid from sp_results where label='Personal'));raise exception 'Solution selected as Problem';exception when insufficient_privilege then assert sqlerrm=baseline;end;
 begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Hidden'),pg_temp.sp_problem('Team'));raise exception 'Unrevealed Team leak';exception when insufficient_privilege then null;end;
 begin perform public.promote_brainstorm_entry_to_solution(null,pg_temp.sp_problem('Problem'));raise exception 'Null entry';exception when invalid_parameter_value then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
-- Trusted rollback-only invalid lifecycle/inconsistent-chain fixtures.
do $$begin
 begin
  update public.development_objects set archived_at=clock_timestamp() where id=pg_temp.sp_problem('Problem');
  set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Personal'),pg_temp.sp_problem('Problem'));raise exception 'Archived Problem';
 exception when insufficient_privilege then null;end;
 begin
  update public.brainstorm_entries set status='archived',archived_at=clock_timestamp() where id=pg_temp.sp_entry('Personal');
  set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Personal'),pg_temp.sp_problem('Problem'));raise exception 'Archived Entry';
 exception when object_not_in_prerequisite_state then null;end;
 begin
  update public.development_object_relationships set status='inactive' where source_object_id=(select (payload->>'id')::uuid from sp_results where label='Personal');
  set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
  perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Personal'),pg_temp.sp_problem('Problem'));raise exception 'Inactive edge repaired';
 exception when unique_violation then null;end;
end $$;
-- Fail each required write after Object insertion; all business state rolls back.
create function pg_temp.sp_fail() returns trigger language plpgsql as $$begin raise exception 'Forced Solution failure' using errcode='P0001';end $$;
do $$declare table0 text;i integer:=0;before0 jsonb;edges0 jsonb;begin
 foreach table0 in array array['development_objects','brainstorm_entries','development_object_relationships','activity_outputs','change_log'] loop
  i:=i+1;before0:=pg_temp.bc_outputs();select jsonb_agg(to_jsonb(x) order by id) into edges0 from public.development_object_relationships x;
  execute format('create trigger sp_failure before %s on public.%I for each row %s execute function pg_temp.sp_fail()',case when table0='brainstorm_entries' then 'update' else 'insert' end,table0,case when table0='change_log' then 'when (new.change_type = ''OBJECT_CREATED'')' else '' end);
  begin
   set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
   perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Rollback'||i),pg_temp.sp_problem('Problem'));
   raise exception 'Fault not reached' using errcode='XX000';
  exception when raise_exception then null;end;
  execute 'reset role';perform set_config('request.jwt.claim.sub','',true);
  execute format('drop trigger sp_failure on public.%I',table0);
  assert pg_temp.bc_outputs()=before0,'Partial Object/source/output/log state';
  assert (select jsonb_agg(to_jsonb(x) order by id) from public.development_object_relationships x)=edges0,'Orphan edge';
 end loop;
end $$;
set local role authenticated;
do $$declare actor0 text;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Personal'),pg_temp.sp_problem('Problem'));raise exception 'Role/private bypass';exception when insufficient_privilege then null;end;
 end loop;
 foreach actor0 in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Team'),pg_temp.sp_problem('Team'));raise exception 'Team scope bypass';exception when insufficient_privilege then null;end;
  assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from sp_results where label='Team')),'Foreign exact Object ID';
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.promote_brainstorm_entry_to_solution(pg_temp.sp_entry('Team'),pg_temp.sp_problem('Team'));raise exception 'Removed retry';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from sp_results where label='Team'));
 begin update public.brainstorm_entries set development_object_id=null;raise exception 'Direct source mutation';exception when insufficient_privilege then null;end;
 begin insert into public.development_object_relationships(project_id,source_object_id,target_object_id,relationship_type,created_by) select project_id,id,pg_temp.sp_problem('Team'),'SOLVES',auth.uid() from public.development_objects limit 1;raise exception 'Direct edge mutation';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin
 assert (select prosecdef and proconfig=array['search_path=""'] and proargnames=array['target_entry','target_problem']::text[] and prorettype='jsonb'::regtype from pg_proc where oid='public.promote_brainstorm_entry_to_solution(uuid,uuid)'::regprocedure),'RPC/type parity';
 assert has_function_privilege('authenticated','public.promote_brainstorm_entry_to_solution(uuid,uuid)','EXECUTE');
 assert not has_function_privilege('anon','public.promote_brainstorm_entry_to_solution(uuid,uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.promote_brainstorm_entry_to_solution(uuid,uuid)','EXECUTE');
 assert not has_table_privilege('authenticated','public.brainstorm_entries','UPDATE');
end $$;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$begin begin perform public.promote_brainstorm_entry_to_solution(gen_random_uuid(),gen_random_uuid());raise exception 'Anonymous RPC';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
\echo M9.12 Solution promotion Personal-Team/reveal/Problem/author/provenance/SOLVES/output/retry/rollback/privacy/history PASS
