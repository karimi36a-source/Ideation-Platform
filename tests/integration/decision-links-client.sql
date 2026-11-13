reset role;
create function pg_temp.link_args(label0 text,kind0 text,id0 uuid) returns jsonb language sql as $$select jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label=label0),'linkedEntityType',kind0,'linkedEntityId',id0,'relationshipType',case when kind0='VOTING_SESSION' then 'INFORMED_BY' else 'CONSIDERED_IN_DECISION' end)$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team')));
do $$begin
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values((select (payload#>>'{decision,id}')::uuid from df_drafts where label='Team'),'ARTIFACT',(select id from df_artifacts where label='Team'),'CONSIDERED_IN_DECISION');raise exception 'Direct insert';exception when insufficient_privilege then null;end;
 begin update public.decision_links set linked_entity_id=gen_random_uuid();raise exception 'Retarget';exception when insufficient_privilege then null;end;
 begin update public.decision_links set relationship_type='INFORMED_BY';raise exception 'Relation mutation';exception when insufficient_privilege then null;end;
 begin delete from public.decision_links;raise exception 'Delete';exception when insufficient_privilege then null;end;
 begin insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,changed_by) select (payload#>>'{decision,project_id}')::uuid,'DECISION',(payload#>>'{decision,id}')::uuid,'DECISION_LINK_ADDED','Fake',public.current_platform_user_id() from df_drafts where label='Team';raise exception 'Forge event';exception when insufficient_privilege then null;end;
end $$;
select 'M10.11 focused client PASS';
rollback;
