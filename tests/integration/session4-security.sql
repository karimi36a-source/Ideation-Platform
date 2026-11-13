begin;
create temporary table m919_history as select jsonb_build_object(
 'entries',(select jsonb_agg(to_jsonb(e) order by e.id) from public.brainstorm_entries e),
 'objects',(select jsonb_agg(to_jsonb(o) order by o.id) from public.development_objects o),
 'links',(select jsonb_agg(to_jsonb(l) order by l.id) from public.artifact_object_links l),
 'edges',(select jsonb_agg(to_jsonb(r) order by r.id) from public.development_object_relationships r),
 'versions',(select jsonb_agg(to_jsonb(v) order by v.id) from public.artifact_versions v)) payload;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006004',null) from public.m919_fixture where label='Team';
do $$declare actor0 text;b record;a uuid;p jsonb:=(select payload from public.m919_fixture where label='Project');t jsonb:=(select payload from public.m919_fixture where label='Team');begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006004'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  assert not exists(select 1 from public.development_objects where id in(select (payload->>'id')::uuid from public.m919_fixture where label in('Problem1','Problem2','Problem3','Solution1','Solution2','Solution3'))),'Object leakage';
  assert not exists(select 1 from public.brainstorm_entries where id in(select (payload->>'id')::uuid from public.m919_fixture where label like 'Entry%')),'Revealed pool leakage';
  for b in select * from public.m919_fixture where label in('ProblemBank','SolutionBank') loop
   assert not exists(select 1 from public.artifacts where id=(b.payload#>>'{artifact,id}')::uuid),'Bank leakage';
   assert not exists(select 1 from public.artifact_versions where id=(b.payload#>>'{version,id}')::uuid),'Version leakage';
   begin perform public.add_activity_artifact_input((select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label='Session5'),(b.payload#>>'{artifact,id}')::uuid,(b.payload#>>'{version,id}')::uuid,true);raise exception 'Foreign input allowed';exception when insufficient_privilege then null;end;
  end loop;
  begin perform public.promote_brainstorm_entry_to_solution((select (payload->>'id')::uuid from public.m919_fixture where label='Entry1'),(select (payload->>'id')::uuid from public.m919_fixture where label='Problem1'));raise exception 'Foreign promotion';exception when insufficient_privilege then null;end;
  begin assert public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000919803',(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,(t->>'teamId')::uuid)->>'satisfied'='false';exception when insufficient_privilege then null;end;
  for a in select (payload#>>'{activity,id}')::uuid from public.m919_fixture where label in('ProblemActivity','SolutionActivity','Session5') loop assert public.resume_activity(a) is null,'Resume scope bypass';end loop;
 end loop;
end $$;
reset role;
do $$begin
 assert (select payload from m919_history)=jsonb_build_object(
 'entries',(select jsonb_agg(to_jsonb(e) order by e.id) from public.brainstorm_entries e),
 'objects',(select jsonb_agg(to_jsonb(o) order by o.id) from public.development_objects o),
 'links',(select jsonb_agg(to_jsonb(l) order by l.id) from public.artifact_object_links l),
 'edges',(select jsonb_agg(to_jsonb(r) order by r.id) from public.development_object_relationships r),
 'versions',(select jsonb_agg(to_jsonb(v) order by v.id) from public.artifact_versions v)),'Removal/attacks rewrote source history';
end $$;
rollback;
\echo M9.19 TeamB/removed-member exact Objects/Banks/entries/promotion/input/dependency/resume denial + source history PASS
