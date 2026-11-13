begin read only;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
-- Canonical RLS reads in independent reauthenticated requests, no memory mocks.
select 'M919_STATE='||jsonb_build_object(
 'resume',(select jsonb_agg(public.resume_activity((payload#>>'{activity,id}')::uuid) order by label) from public.m919_fixture where label in('ProblemActivity','SolutionActivity','Session5')),
 'concept',(select to_jsonb(v) from public.artifact_versions v where v.id=(select (payload->>'id')::uuid from public.m919_fixture where label='ConceptV2')),
 'objects',(select jsonb_agg(to_jsonb(o) order by o.id) from public.development_objects o where o.id in(select (payload->>'id')::uuid from public.m919_fixture where label in('Problem1','Problem2','Problem3','Solution1','Solution2','Solution3'))),
 'entries',(select jsonb_agg(to_jsonb(e) order by e.id) from public.brainstorm_entries e where e.id in(select (payload->>'id')::uuid from public.m919_fixture where label like 'Entry%')),
 'banks',(select jsonb_agg(to_jsonb(a) order by a.id) from public.artifacts a where a.id in(select (payload#>>'{artifact,id}')::uuid from public.m919_fixture where label in('ProblemBank','SolutionBank'))),
 'versions',(select jsonb_agg(to_jsonb(v) order by v.artifact_id,v.version_number) from public.artifact_versions v where v.artifact_id in(select (payload#>>'{artifact,id}')::uuid from public.m919_fixture where label in('ProblemBank','SolutionBank'))),
 'relationships',(select jsonb_agg(to_jsonb(r) order by r.id) from public.development_object_relationships r where r.source_object_id in(select (payload->>'id')::uuid from public.m919_fixture where label in('Solution1','Solution2','Solution3'))),
 'links',(select jsonb_agg(to_jsonb(l) order by l.id) from public.artifact_object_links l where l.artifact_id in(select (payload#>>'{artifact,id}')::uuid from public.m919_fixture where label in('ProblemBank','SolutionBank'))),
 'counts',jsonb_build_array((select count(*) from public.development_objects),(select count(*) from public.artifacts),(select count(*) from public.artifact_versions),(select count(*) from public.activity_outputs),(select count(*) from public.artifact_object_links),(select count(*) from public.development_object_relationships))
)::text;
do $$begin
 assert (select count(*) from public.development_objects where id in(select (payload->>'id')::uuid from public.m919_fixture where label in('Problem1','Problem2','Problem3','Solution1','Solution2','Solution3')))=6;
 assert (select count(*) from public.brainstorm_entries where id in(select (payload->>'id')::uuid from public.m919_fixture where label like 'Entry%'))=3;
 assert (select count(*) from public.artifact_object_links where artifact_id in(select (payload#>>'{artifact,id}')::uuid from public.m919_fixture where label in('ProblemBank','SolutionBank')))=6;
end $$;
commit;
