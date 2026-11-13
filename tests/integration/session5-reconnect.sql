begin read only;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select 'M1018_STATE='||jsonb_build_object(
 'decisions',(select jsonb_agg(to_jsonb(d) order by id) from public.decisions d where id=(select id from public.m1018_ids where label='Decision')),
 'options',(select jsonb_agg(to_jsonb(o) order by id) from public.decision_options o where decision_id=(select id from public.m1018_ids where label='Decision')),
 'participants',(select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p where decision_id=(select id from public.m1018_ids where label='Decision')),
 'links',(select jsonb_agg(to_jsonb(l) order by id) from public.decision_links l where decision_id=(select id from public.m1018_ids where label='Decision')),
 'results',public.get_voting_results((select id from public.m1018_ids where label='Voting')),
 'objects',(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o where id in(select id from public.m1018_ids where label in('Problem1','Problem2','Problem3','Solution1','Solution2','Solution3'))),
 'artifacts',(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a where id in(select id from public.m1018_ids where label in('ProblemBank','SolutionBank','Record'))),
 'versions',(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v where id in(select id from public.m1018_ids where label in('ProblemBankVersion','SolutionBankVersion','RecordVersion'))),
 'source',(select to_jsonb(s) from public.artifact_decision_sources s where artifact_id=(select id from public.m1018_ids where label='Record')),
 'objectLinks',(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l where artifact_id in(select id from public.m1018_ids where label in('ProblemBank','SolutionBank','Record'))),
 'inputs',(select jsonb_agg(to_jsonb(i) order by id) from public.activity_inputs i where activity_instance_id in(select id from public.m1018_ids where label in('Activity','Downstream'))),
 'outputs',(select jsonb_agg(to_jsonb(o) order by id) from public.activity_outputs o where artifact_id=(select id from public.m1018_ids where label='Record'))
)::text;
do $$begin
 assert exists(select 1 from public.decisions where id=(select id from public.m1018_ids where label='Decision') and status='FINALIZED');
 assert exists(select 1 from public.activity_inputs where activity_instance_id=(select id from public.m1018_ids where label='Downstream') and artifact_id=(select id from public.m1018_ids where label='Record'));
end $$;
commit;
