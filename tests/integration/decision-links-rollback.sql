reset role;
create function pg_temp.link_args(label0 text,kind0 text,id0 uuid) returns jsonb language sql as $$select jsonb_build_object('decisionId',(select payload#>>'{decision,id}' from df_drafts where label=label0),'linkedEntityType',kind0,'linkedEntityId',id0,'relationshipType',case when kind0='VOTING_SESSION' then 'INFORMED_BY' else 'CONSIDERED_IN_DECISION' end)$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
reset role;
create temporary table dl_rollback_before as select
 (select jsonb_agg(to_jsonb(d) order by id) from public.decisions d) decisions,
 (select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a) targets,
 (select jsonb_agg(to_jsonb(c) order by id) from public.change_log c) logs;
create function pg_temp.dl_fail() returns trigger language plpgsql as $$begin if new.change_type='DECISION_LINK_ADDED' then raise exception 'Injected failure' using errcode='23514';end if;return new;end $$;
create trigger dl_fail before insert on public.change_log for each row execute function pg_temp.dl_fail();
set local role authenticated;
do $$begin begin perform public.link_decision_entity(pg_temp.link_args('Team','ARTIFACT',(select id from df_artifacts where label='Team')));raise exception 'Missing failure';exception when check_violation then null;end;end $$;
reset role;
do $$begin
 assert not exists(select 1 from public.decision_links);
 assert (select decisions from dl_rollback_before)=(select jsonb_agg(to_jsonb(d) order by id) from public.decisions d);
 assert (select targets from dl_rollback_before)=(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a);
 assert (select logs from dl_rollback_before)=(select jsonb_agg(to_jsonb(c) order by id) from public.change_log c);
end $$;
select 'M10.11 focused rollback PASS';
rollback;
