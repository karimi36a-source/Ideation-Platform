reset role;
create function pg_temp.link_args(label0 text,kind0 text,id0 uuid) returns jsonb language sql as $$select jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label=label0),'linkedEntityType',kind0,'linkedEntityId',id0,'relationshipType',case when kind0='VOTING_SESSION' then 'INFORMED_BY' else 'CONSIDERED_IN_DECISION' end)$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select public.finalize_decision(jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label='Team'),'outcome','Human','reasoning','Reason'));
reset role;
create temporary table dl_final_before as select
 (select to_jsonb(d) from public.decisions d where id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='Team')) body,
 (select jsonb_agg(to_jsonb(o) order by id) from public.decision_options o) options,
 (select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p) participants;
set local role authenticated;
select public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team')));
reset role;
do $$begin
 assert (select body from dl_final_before)=(select to_jsonb(d) from public.decisions d where id=(select (payload#>>'{decision,id}')::uuid from df_drafts where label='Team'));
 assert (select options from dl_final_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.decision_options o);
 assert (select participants from dl_final_before)=(select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p);
 assert (select count(*) from public.change_log where change_type='DECISION_LINK_ADDED')=1;
end $$;
select 'M10.11 focused finalized PASS';
rollback;
