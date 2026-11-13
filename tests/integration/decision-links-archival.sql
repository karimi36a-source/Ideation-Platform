reset role;
create function pg_temp.link_args(label0 text,kind0 text,id0 uuid) returns jsonb language sql as $$select jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label=label0),'linkedEntityType',kind0,'linkedEntityId',id0,'relationshipType',case when kind0='VOTING_SESSION' then 'INFORMED_BY' else 'CONSIDERED_IN_DECISION' end)$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin
 perform public.link_decision_entity(pg_temp.link_args('Team','DEVELOPMENT_OBJECT',(select id from vc_objects where kind='PROBLEM')));
 begin perform public.link_decision_entity(pg_temp.link_args('Team','DEVELOPMENT_OBJECT',(select id from vc_objects where kind='ARCHIVED')));raise exception 'Archived Object accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$begin assert exists(select 1 from public.decision_links where linked_entity_id=(select id from vc_objects where kind='PROBLEM'));assert not exists(select 1 from public.decision_links where linked_entity_id=(select id from vc_objects where kind='ARCHIVED'));end $$;
select 'M10.11 focused archival PASS';
rollback;
