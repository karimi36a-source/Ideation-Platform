reset role;
create function pg_temp.link_args(label0 text,kind0 text,id0 uuid) returns jsonb language sql as $$select jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label=label0),'linkedEntityType',kind0,'linkedEntityId',id0,'relationshipType',case when kind0='VOTING_SESSION' then 'INFORMED_BY' else 'CONSIDERED_IN_DECISION' end)$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$declare a jsonb;b jsonb;begin
 a:=public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team')));
 b:=public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team')));assert a=b;
end $$;
reset role;
do $$begin assert (select count(*) from public.decision_links)=1;assert (select count(*) from public.change_log where change_type='DECISION_LINK_ADDED')=1;end $$;
select 'M10.11 focused retry PASS';
rollback;
