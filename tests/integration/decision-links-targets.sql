reset role;
create function pg_temp.link_args(label0 text,kind0 text,id0 uuid) returns jsonb language sql as $$select jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label=label0),'linkedEntityType',kind0,'linkedEntityId',id0,'relationshipType',case when kind0='VOTING_SESSION' then 'INFORMED_BY' else 'CONSIDERED_IN_DECISION' end)$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare kind0 text;id0 uuid;begin
 foreach kind0 in array array['PROBLEM','SOLUTION','FEATURE'] loop perform public.link_decision_entity(pg_temp.link_args('Team','DEVELOPMENT_OBJECT',(select id from vc_objects where kind=kind0)));end loop;
 perform public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team')));
 perform public.link_decision_entity(pg_temp.link_args('Team','VOTING_SESSION',(select (payload#>>'{session,id}')::uuid from vc_results where jsonb_array_length(payload->'options')=3 limit 1)));
 foreach kind0 in array array['EVIDENCE','AI_OUTPUT'] loop
 begin perform public.link_decision_entity(pg_temp.link_args('Team',kind0,gen_random_uuid()));raise exception 'Future target';exception when feature_not_supported then null;end;end loop;
 begin perform public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',gen_random_uuid()));raise exception 'Missing target';exception when insufficient_privilege then null;end;
 begin perform public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team'))||'{"relationshipType":"INFORMED_BY"}'::jsonb);raise exception 'Wrong mapping';exception when invalid_parameter_value then null;end;
end $$;
select 'M10.11 focused targets PASS';
rollback;
