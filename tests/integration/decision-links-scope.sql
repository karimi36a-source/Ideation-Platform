reset role;
create function pg_temp.link_args(label0 text,kind0 text,id0 uuid) returns jsonb language sql as $$select jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label=label0),'linkedEntityType',kind0,'linkedEntityId',id0,'relationshipType',case when kind0='VOTING_SESSION' then 'INFORMED_BY' else 'CONSIDERED_IN_DECISION' end)$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare who integer;begin
 foreach who in array array[6001,6003,6004,6005,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(who::text,12,'0'),true);
 begin perform public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team')));raise exception 'Wrong actor';exception when insufficient_privilege then null;end;end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
 begin perform public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team B')));raise exception 'Foreign Team Project Workspace';exception when insufficient_privilege then null;end;
 begin perform public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Personal')));raise exception 'Foreign Personal';exception when insufficient_privilege then null;end;
 begin perform public.link_decision_entity(pg_temp.link_args('Personal','ARTIFACT',(select id from df_artifacts where label='Personal')));raise exception 'Lead accesses Personal';exception when insufficient_privilege then null;end;
 begin perform public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team'))||'{"role":"MASTER"}'::jsonb);raise exception 'Spoof';exception when invalid_parameter_value then null;end;
 perform set_config('request.jwt.claim.sub','',true);
 begin perform public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team')));raise exception 'Anonymous';exception when sqlstate '28000' then null;end;
end $$;
select 'M10.11 focused scope PASS';
rollback;
