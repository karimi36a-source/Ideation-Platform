-- Canonical M8 Project fixture is prepended; all calls use real PostgreSQL auth.
reset role;
create temporary table ec_scope as select label,(payload->>'id')::uuid project_id,(payload->>'primary_workspace_id')::uuid workspace_id from logged_projects;
create temporary table ec_saved(label text,payload jsonb);
grant select on ec_scope to authenticated;
grant select,insert on ec_saved to authenticated;
create function pg_temp.ec_call(changes jsonb default '{}') returns jsonb language sql as $$
 select public.create_evidence(
 coalesce(($1->>'project')::uuid,(select project_id from ec_scope where label=coalesce($1->>'scope','Team'))),
 coalesce(($1->>'workspace')::uuid,(select workspace_id from ec_scope where label=coalesce($1->>'scope','Team'))),
 coalesce($1->>'kind','MEASUREMENT')::public.evidence_type,
 case when $1 ? 'title' then $1->>'title' else 'Recorded measurement' end,
 case when $1 ? 'description' then $1->>'description' else 'Observed source information' end,
 case when $1 ? 'source' then $1->>'source' else 'Lab notebook, observation 1' end,
 $1->>'url',($1->>'file')::uuid)
$$;
create function pg_temp.ec_bad(changes jsonb,expected text default '42501') returns void language plpgsql as $$
begin perform pg_temp.ec_call(changes);raise exception 'Unauthorized Evidence creation';exception when others then if sqlstate<>expected then raise;end if;end $$;
grant execute on function pg_temp.ec_call(jsonb),pg_temp.ec_bad(jsonb,text) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ec_saved select kind,pg_temp.ec_call(jsonb_build_object('kind',kind,'title',E' \tRecorded measurement\n','description',' Observed source information ','source',chr(160)||'Lab notebook, observation 1'||chr(160),'url',case when kind in ('PATENT','STANDARD','PAPER','MARKET_SOURCE') then ' https://example.test/source?q=1#section ' else null end))
 from unnest(array['PATENT','STANDARD','DATASHEET','PAPER','CALCULATION','MEASUREMENT','TEST_RESULT','CUSTOMER_INTERVIEW','MARKET_SOURCE','SECONDARY_SOURCE','OTHER']) kind;
insert into ec_saved values('Intentional second record',pg_temp.ec_call());
insert into ec_saved values('Personal',pg_temp.ec_call('{"scope":"Individual"}'));
do $$declare p jsonb;begin
 assert (select count(*) from ec_saved)=13;
 assert (select count(distinct payload->>'id') from ec_saved)=13,'no invented idempotency';
 assert (select count(distinct payload->>'evidence_type') from ec_saved)=11;
 assert not exists(select 1 from public.evidence_links),'creation never links implicitly';
 for p in select payload from ec_saved loop
  assert p->>'verification_status'='UNVERIFIED' and p->>'verified_by' is null and p->>'verified_at' is null;
  assert p->>'created_by'=public.current_platform_user_id()::text and p->>'updated_by'=public.current_platform_user_id()::text;
  assert p->>'title'='Recorded measurement' and p->>'description'='Observed source information' and p->>'source_name'='Lab notebook, observation 1';
  assert p->'metadata'='{}'::jsonb and p->>'archived_at' is null and p->>'file_id' is null;
  assert (p->>'captured_at')::timestamptz>=transaction_timestamp() and (p->>'captured_at')::timestamptz<=clock_timestamp();
  assert exists(select 1 from public.evidence e where e.id=(p->>'id')::uuid and to_jsonb(e)=p);
 end loop;
 assert (select payload->>'source_url' from ec_saved where label='PATENT')='https://example.test/source?q=1#section';
 assert (select payload->>'source_url' is null from ec_saved where label='CUSTOMER_INTERVIEW');
end $$;
-- Explicit M12.2 composition: no automatic link or verification transition.
insert into ec_saved values('Gap',public.create_development_object((select project_id from ec_scope where label='Team'),(select workspace_id from ec_scope where label='Team'),'GAP','Evidence gap','Canonical gap unchanged','User'));
select public.link_evidence(jsonb_build_object('evidenceId',(select payload->>'id' from ec_saved where label='MEASUREMENT'),'entityType','GAP','entityId',(select payload->>'id' from ec_saved where label='Gap'),'relationshipType','SUPPORTS'));
do $$begin
 assert (select count(*) from public.evidence_links)=1;
 assert not exists(select 1 from public.evidence where verification_status<>'UNVERIFIED' or verified_by is not null or verified_at is not null);
end $$;
select pg_temp.ec_bad('{"kind":"PATENT_CLAIM"}','23514'); -- M12.14 now requires an explicit claim locator.
select pg_temp.ec_bad('{"kind":"CUSTOM"}','22P02');
select pg_temp.ec_bad('{"kind":"AI_OUTPUT"}','22P02');
select pg_temp.ec_bad('{"title":" \t\n "}','22023');
select pg_temp.ec_bad('{"title":null}','22023');
select pg_temp.ec_bad('{"source":" \t\n "}','22023');
select pg_temp.ec_bad(jsonb_build_object('source',chr(160)||chr(65279)),'22023');
select pg_temp.ec_bad('{"description":" "}','22023');
select pg_temp.ec_bad(jsonb_build_object('url',bad),'22023') from unnest(array['not a URL','https://','https://bad host/source','javascript:alert(1)','file:///source','data:text/plain,source','']) bad;
select pg_temp.ec_bad('{"file":"00000000-0000-4000-8000-000000009999"}','0A000');
select pg_temp.ec_bad(jsonb_build_object('workspace',(select workspace_id from ec_scope where label='Individual')));
select pg_temp.ec_bad('{"project":"00000000-0000-4000-8000-000000009999"}');
-- Missing and inaccessible scopes produce the same authorization outcome.
do $$declare n int;begin
 foreach n in array array[6007,6002,6003,6001,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  perform pg_temp.ec_bad('{}');
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Direct inserts remain denied independently of the RPC validation.
do $$declare patch text;begin
 foreach patch in array array['created_by','verification_status','verified_by','verified_at','workspace_id'] loop
  begin
   insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name,created_by,verification_status,verified_by,verified_at)
   select project_id,case when patch='workspace_id' then '00000000-0000-4000-8000-000000009999'::uuid else workspace_id end,'PATENT','Spoof','Spoof','Spoof',
    case when patch='created_by' then '00000000-0000-4000-8000-000000006005'::uuid else public.current_platform_user_id() end,
    case when patch='verification_status' then 'VERIFIED'::public.evidence_verification_status else 'UNVERIFIED'::public.evidence_verification_status end,
    case when patch='verified_by' then public.current_platform_user_id() else null end,
    case when patch='verified_at' then now() else null end from ec_scope where label='Team';
   raise exception 'Direct INSERT bypass';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
create function pg_temp.ec_fail() returns trigger language plpgsql as $$begin raise exception 'Forced creation failure' using errcode='23514';end $$;
create trigger ec_fail before insert on public.evidence for each row execute function pg_temp.ec_fail();
set local role authenticated;
select pg_temp.ec_bad('{}','23514');
reset role;
drop trigger ec_fail on public.evidence;
set local role authenticated;
do $$begin assert (select count(*) from public.evidence)=13;assert (select count(*) from public.evidence_links)=1;end $$;
insert into ec_saved values('Clean retry after failure',pg_temp.ec_call());
-- Current Case Study owner retains their own exact scoped creation path.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into ec_saved values('Case owner',pg_temp.ec_call('{"scope":"Case"}'));
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.ec_bad('{}');
do $$begin
 assert (select count(*) from public.evidence)=1,'Personal owner access survives Team removal';
 assert not exists(select 1 from public.evidence_links);
end $$;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.ec_bad('{}','28000');
reset role;
set local role anon;
do $$begin
 begin perform public.create_evidence(null,null,'OTHER','T','D','S');raise exception 'Anonymous RPC';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare f oid:='public.create_evidence(uuid,uuid,public.evidence_type,text,text,text,text,uuid)'::regprocedure;begin
 assert (select count(*) from public.evidence)=15,'no partial or unauthorized rows';
 assert exists(select 1 from public.evidence e where e.id=(select (payload->>'id')::uuid from ec_saved where label='MEASUREMENT') and to_jsonb(e)=(select payload from ec_saved where label='MEASUREMENT')),'removed creator history unchanged';
 assert not has_table_privilege('authenticated','public.evidence','INSERT');
 assert not has_table_privilege('service_role','public.evidence','INSERT');
 assert has_function_privilege('authenticated',f,'EXECUTE');
 assert not has_function_privilege('anon',f,'EXECUTE');
 assert not has_function_privilege('service_role',f,'EXECUTE');
 assert not exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where p.oid=f and a.grantee=0 and a.privilege_type='EXECUTE');
 assert (select prosecdef and proconfig=array['search_path=""'] and proargnames=array['project_id','workspace_id','evidence_type','title','description','source_name','source_url','file_id'] from pg_proc where oid=f);
 assert (select count(*) from pg_proc where pronamespace='public'::regnamespace and proname='create_evidence')=1;
 -- M12.6 introduces canonical Files without enabling non-null createEvidence
 -- input. All explicit creation cases above still use the accepted null path.
 assert to_regclass('public.files') is not null;
 assert not exists(select 1 from public.files),'Evidence creation does not manufacture Files';
end $$;
select 'M12.3 create RPC vocabulary/normalization/offline/UNVERIFIED/actor/capture/scope/spoof/RLS/rollback/explicit-link PASS';
rollback;
