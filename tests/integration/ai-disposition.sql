-- Canonical M14.1 outputs have been created under current source authority.
create temporary table disposition_before as select to_jsonb(o)-'disposition'-'disposition_revision' body from public.ai_outputs o;
create temporary table disposition_counts as select (select count(*) from public.evidence) evidence_count,(select count(*) from public.development_objects) object_count,(select count(*) from public.artifacts) artifact_count,(select count(*) from public.ai_context_references) ref_count;
grant select on ai_cases to authenticated;
set local role authenticated;
do $$declare oid uuid:=(select (row_data->>'id')::uuid from ai_cases where label='Team/ANALYSIS');r jsonb;n bigint;d public.ai_output_disposition;begin
 foreach d in array array['ACCEPT_AS_CANDIDATE','REJECTED','INVESTIGATE_FURTHER','MODIFIED','KEEP_FOR_REVIEW']::public.ai_output_disposition[] loop
  select disposition_revision into n from public.ai_outputs where id=oid;
  r:=public.set_ai_output_disposition(oid,d,n);
  assert r->>'disposition'=d::text and r->>'verification_status'='UNVERIFIED' and (r->>'disposition_revision')::bigint=n+1;
  assert public.set_ai_output_disposition(oid,d,n)=r,'Exact retry must be a no-op even with old revision';
 end loop;
 perform pg_temp.ai_bad(format('select public.set_ai_output_disposition(%L,''REJECTED'',0)',oid),'40001');
 perform pg_temp.ai_bad(format('select public.set_ai_output_disposition(%L,''CONVERTED_TO_PROJECT_OBJECT'',5)',oid),'22023');
 perform pg_temp.ai_bad('update public.ai_outputs set disposition=''REJECTED''','42501');
 perform pg_temp.ai_bad('update public.ai_outputs set verification_status=''VERIFIED_AGAINST_SOURCES''','42501');
 perform pg_temp.ai_bad('delete from public.ai_outputs','42501');
 -- Personal owner also has normal authority.
 perform public.set_ai_output_disposition((select (row_data->>'id')::uuid from ai_cases where label='Individual/SUGGESTION'),'ACCEPT_AS_CANDIDATE',0);
end$$;
reset role;
do $$declare oid uuid:=(select (row_data->>'id')::uuid from ai_cases where label='Team/ANALYSIS');begin
 assert (select count(*) from public.change_log where entity_type::text='AI_OUTPUT')=6;
 assert (select count(*) from public.change_log where entity_id=oid and changed_by='00000000-0000-4000-8000-000000006004' and created_at is not null and reason::jsonb ?& array['previous','new','revision','workspace_id'])=5;
 assert not exists((select to_jsonb(o)-'disposition'-'disposition_revision' from public.ai_outputs o) except (select body from disposition_before));
end$$;
-- Required audit failure must roll back disposition and revision.
create function pg_temp.fail_disposition_audit() returns trigger language plpgsql as $$begin if new.entity_type::text='AI_OUTPUT' then raise exception 'Forced audit failure' using errcode='23514';end if;return new;end$$;
create trigger test_disposition_audit_failure before insert on public.change_log for each row execute function pg_temp.fail_disposition_audit();
set local role authenticated;
do $$declare oid uuid:=(select (row_data->>'id')::uuid from ai_cases where label='Team/ANALYSIS');begin
 perform pg_temp.ai_bad(format('select public.set_ai_output_disposition(%L,''REJECTED'',5)',oid),'23514');
 assert (select disposition='KEEP_FOR_REVIEW' and disposition_revision=5 from public.ai_outputs where id=oid);
end$$;
reset role;
drop trigger test_disposition_audit_failure on public.change_log;
-- Same exact IDs do not grant normal access to unrelated or role-only actors.
do $$declare u text;oid uuid:=(select (row_data->>'id')::uuid from ai_cases where label='Team/ANALYSIS');begin
 foreach u in array array['00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',u,true);execute 'set local role authenticated';
  perform pg_temp.ai_bad(format('select public.set_ai_output_disposition(%L,''REJECTED'',5)',oid),'42501');
  perform pg_temp.ai_bad(format('select public.set_ai_output_disposition(%L,''REJECTED'',0)',(select row_data->>'id' from ai_cases where label='Individual/SUGGESTION')),'42501');
  execute 'reset role';
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.14 removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin perform pg_temp.ai_bad(format('select public.set_ai_output_disposition(%L,''REJECTED'',5)',(select row_data->>'id' from ai_cases where label='Team/ANALYSIS')),'42501');end$$;
reset role;
do $$begin
 assert (select count(*) from public.change_log where entity_type::text='AI_OUTPUT')=6;
 assert (select count(*) from public.evidence)=(select evidence_count from disposition_counts);
 assert (select count(*) from public.development_objects)=(select object_count from disposition_counts);
 assert (select count(*) from public.artifacts)=(select artifact_count from disposition_counts);
 assert (select count(*) from public.ai_context_references)=(select ref_count from disposition_counts);
 assert not has_table_privilege('authenticated','public.ai_outputs','UPDATE');
 assert not has_function_privilege('anon','public.set_ai_output_disposition(uuid,public.ai_output_disposition,bigint)','EXECUTE');
end$$;
select 'M14.14 human-disposition/CAS/audit/rollback/immutability/verification/Personal/Team/role-only/removal PASS';
rollback;
