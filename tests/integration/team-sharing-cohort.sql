-- M13.8 policy boundary uses canonical Teams and the existing Share transaction.
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
insert into acceptance_teams values('C',public.create_team((select id from acceptance_cohorts where label='Unrelated'),'Other Cohort Team C'));
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare r jsonb;begin
 r:=public.resolve_shareability(pg_temp.share_request());assert r->>'allowed'='true';
 r:=public.resolve_shareability(pg_temp.share_request(target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='C')));
 assert r='{"allowed":false,"deniedReason":"DESTINATION_SCOPE_DENIED"}'::jsonb;
end$$;
reset role;
do $$declare n bigint;s bigint;a bigint;begin
 select count(*) into n from public.shares;select count(*) into s from public.share_snapshots;select count(*) into a from public.audit_events;
 begin
  perform public.share_entity(pg_temp.share_request(target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='C')));
  raise exception 'Cross-Cohort creation succeeded';
 exception when insufficient_privilege then null;end;
 assert n=(select count(*) from public.shares) and s=(select count(*) from public.share_snapshots) and a=(select count(*) from public.audit_events);
end$$;
-- Planned/completed/archived Cohorts cannot authorize new Team-to-Team Shares.
do $$declare lifecycle public.cohort_status;begin
 foreach lifecycle in array array['planned','completed','archived']::public.cohort_status[] loop
  update public.cohorts set status=lifecycle where id=(select id from acceptance_cohorts where label='Test');
  assert public.resolve_shareability(pg_temp.share_request())->>'allowed'='false';
  begin perform public.share_entity(pg_temp.share_request());raise exception 'Inactive Cohort Share succeeded';exception when insufficient_privilege then null;end;
 end loop;
 update public.cohorts set status='active' where id=(select id from acceptance_cohorts where label='Test');
 assert public.resolve_shareability(pg_temp.share_request())->>'allowed'='true';
end$$;
select 'M13.8 same-active-Cohort/cross-Cohort-denied/no-partial-records PASS';
