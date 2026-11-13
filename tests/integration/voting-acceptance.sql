-- M10.16 follows the real reveal/results regression in the same transaction.
-- The clear top result is sequence 2 (two votes), not sequence 1 (one vote).
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare s uuid;r jsonb;begin
 select id into s from result_cases where label='live';
 r:=public.get_voting_results(s);
 assert r#>>'{session,status}'='CLOSED';
 assert r#>>'{options,0,voteCount}'='1' and r#>>'{options,1,voteCount}'='2';
 assert not exists(select 1 from public.decisions where status='FINALIZED');
 assert not exists(select 1 from public.decision_options where selected);
end $$;
reset role;
create temporary table va_objects_before as select jsonb_agg(to_jsonb(o) order by id) payload from public.development_objects o;
set local role authenticated;
-- Human choice uses the already accepted Decision operations and exact Objects.
create temporary table va_decision as select public.create_decision(jsonb_build_object(
 'projectId',p.payload->>'id','workspaceId',p.payload->>'primary_workspace_id',
 'title','Human choice differs from vote leader','question','Which option should we pursue?',
 'method','DOT_VOTE','options',(select jsonb_agg(jsonb_build_object('label',o.label,'developmentObjectId',o.development_object_id) order by o.sequence)
 from result_options o where o.voting_session_id=(select id from result_cases where label='live') and o.sequence<=2))) payload
 from logged_projects p where p.label='Team';
select public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}',
 'selectedOptionId',payload#>>'{options,0,id}','outcome','Choose the lower-vote alternative',
 'reasoning','Human evaluation takes precedence over popularity')) from va_decision;
reset role;
do $$begin
 assert exists(select 1 from public.decisions d join va_decision v on d.id=(v.payload#>>'{decision,id}')::uuid where d.status='FINALIZED');
 assert exists(select 1 from public.decision_options o join va_decision v on o.id=(v.payload#>>'{options,0,id}')::uuid where o.selected);
 assert not exists(select 1 from public.decision_options o join va_decision v on o.id=(v.payload#>>'{options,1,id}')::uuid where o.selected);
 assert (select payload from va_objects_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o);
end $$;
select 'M10.16 AT-VOTE-003 clear top/read-only/no automatic downstream mutation/human non-top choice PASS';
