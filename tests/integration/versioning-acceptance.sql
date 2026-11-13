-- New numbered/revision/reopen Drafts start at zero; V1 retained its saved token.
-- M8.17 follows the canonical M8.16 workflow through V1 revision-requested,
-- V2 CURRENT. No service-role mutation is counted as ordinary-user behavior.
create temporary table version_acceptance(key text primary key,data jsonb);
grant select,insert on version_acceptance to authenticated,anon;
insert into version_acceptance select 'V2Before',to_jsonb(v) from public.artifact_versions v where id=(select (data->>'id')::uuid from review_acceptance where key='V2');
insert into version_acceptance select 'Objects',coalesce(jsonb_agg(to_jsonb(o) order by id),'[]') from public.development_objects o;
insert into version_acceptance select 'Links',coalesce(jsonb_agg(to_jsonb(l) order by id),'[]') from public.artifact_object_links l;
insert into version_acceptance select 'Inputs',coalesce(jsonb_agg(to_jsonb(i) order by id),'[]') from public.activity_inputs i;

-- Ordinary creator/Lead, member, reviewer/Master and outsiders cannot rewrite
-- any protected field, delete history or forge a current pointer.
create function pg_temp.version_attacks() returns void language plpgsql as $$
declare v uuid; field text; actor integer; value text;begin
 foreach actor in array array[6005,6004,6002,6001,6003,6006] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor::text,12,'0'),true);
  for v in select (data->>'id')::uuid from review_acceptance where key in ('V1','V2') union select (data->'version'->>'id')::uuid from version_acceptance where key='Reopen' loop
   foreach field in array array['content_snapshot','version_number','version_label','change_summary','created_by','created_at','previous_version_id','approved_by','approved_at','approval_note','status'] loop
    value:=case field when 'content_snapshot' then '''{"forged":true}''::jsonb' when 'version_number' then '999' when 'created_by' then 'auth.uid()' when 'created_at' then 'clock_timestamp()' when 'previous_version_id' then quote_literal(v) || '::uuid' when 'approved_by' then 'auth.uid()' when 'approved_at' then 'clock_timestamp()' when 'status' then '''DRAFT''' else '''forged''' end;
    perform pg_temp.reject(format('update public.artifact_versions set %I=%s where id=%L',field,value,v));
   end loop;
   perform pg_temp.reject(format('update public.artifact_versions set approved_by=%L,approved_at=clock_timestamp(),status=''CURRENT'' where id=%L','00000000-0000-4000-8000-000000006002',v));
   perform pg_temp.reject(format('delete from public.artifact_versions where id=%L',v));
  end loop;
  perform pg_temp.reject(format('update public.artifacts set current_version_id=%L where id=%L',(select data->>'id' from review_acceptance where key='V1'),(select data->>'artifactId' from review_acceptance where key='A')));
 end loop;
end $$;
insert into version_acceptance values('BeforeAttacks',pg_temp.review_state());
set local role authenticated;
select pg_temp.version_attacks();
reset role;
do $$begin assert pg_temp.review_state()=(select data from version_acceptance where key='BeforeAttacks');end$$;

-- Approved reopen forks the current snapshot, not the latest historical row.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into version_acceptance select 'Reopen',public.reopen_approved_artifact((data->>'artifactId')::uuid) from review_acceptance where key='A';
reset role;
do $$declare v jsonb;begin
 select data->'version' into v from version_acceptance where key='Reopen';
 assert v->>'id'<>(select data->>'id' from review_acceptance where key='V2');
 assert v->>'status'='DRAFT' and v->>'version_number'='3';
 assert v->>'previous_version_id'=(select data->>'id' from review_acceptance where key='V2');
 assert v->'content_snapshot'=(select data->'content_snapshot' from version_acceptance where key='V2Before');
 assert v->>'created_by'='00000000-0000-4000-8000-000000006005';
 assert v->'approved_by'='null'::jsonb and v->'approved_at'='null'::jsonb and v->'approval_note'='null'::jsonb;
 assert (select data from version_acceptance where key='V2Before')=(select to_jsonb(v0) from public.artifact_versions v0 where id=(select (data->>'id')::uuid from review_acceptance where key='V2'));
 assert (select current_version_id from public.artifacts where id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'))=(select (data->>'id')::uuid from review_acceptance where key='V2');
 assert (select data from version_acceptance where key='Objects')=(select coalesce(jsonb_agg(to_jsonb(o) order by id),'[]') from public.development_objects o);
 assert (select data from version_acceptance where key='Links')=(select coalesce(jsonb_agg(to_jsonb(l) order by id),'[]') from public.artifact_object_links l);
end$$;
\echo M8.17 AT-VER-002 revision/reopen new identity / exact lineage / no cloning PASS

-- Complete this existing workflow to obtain actual SUPERSEDED approval history.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into version_acceptance select 'S3',public.submit_artifact((select (data->>'artifactId')::uuid from review_acceptance where key='A'),(data->'version'->>'id')::uuid,(select id from instances where label='Team')) from version_acceptance where key='Reopen';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (data->>'id')::uuid from version_acceptance where key='S3'));
select public.approve_artifact((select (data->>'id')::uuid from version_acceptance where key='S3'));
reset role;
do $$begin
 assert (select to_jsonb(v)-'status' from public.artifact_versions v where id=(select (data->>'id')::uuid from review_acceptance where key='V2'))=(select data-'status' from version_acceptance where key='V2Before');
 assert (select status from public.artifact_versions where id=(select (data->>'id')::uuid from review_acceptance where key='V2'))='SUPERSEDED';
end$$;
insert into version_acceptance values('BeforeSupersededAttacks',pg_temp.review_state());
set local role authenticated;select pg_temp.version_attacks();
reset role;
do $$begin assert pg_temp.review_state()=(select data from version_acceptance where key='BeforeSupersededAttacks');end$$;
\echo M8.17 AT-VER-001 CURRENT/SUPERSEDED/revision history all protected fields / deletion / pointer forgery PASS

-- V4 is later than the current approved V3 but must not become current.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into version_acceptance select 'Latest',public.reopen_approved_artifact((data->>'artifactId')::uuid) from review_acceptance where key='A';
insert into version_acceptance select 'History',jsonb_agg(to_jsonb(v) order by version_number) from public.artifact_versions v where artifact_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A');
do $$declare h jsonb;begin
 select data into h from version_acceptance where key='History';
 assert jsonb_array_length(h)=4;
 assert (select array_agg((x->>'version_number')::int order by ord) from jsonb_array_elements(h) with ordinality e(x,ord))=array[1,2,3,4];
 assert h->0->>'status'='REVISION_REQUESTED' and h->1->>'status'='SUPERSEDED' and h->2->>'status'='CURRENT' and h->3->>'status'='DRAFT';
 assert h->3->'change_summary'='null'::jsonb;
 assert (select current_version_id from public.artifacts where id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'))=(h->2->>'id')::uuid;
 assert (select count(*) from public.artifact_versions where artifact_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A') and status='CURRENT')=1;
end$$;
reset role;
do $$begin
 assert (select data from review_acceptance where key='HistoricalV1')=(select to_jsonb(v) from public.artifact_versions v where id=(select (data->>'id')::uuid from review_acceptance where key='V1'));
 assert (select data from review_acceptance where key='HistoricalS1')=(select to_jsonb(s) from public.submissions s where id=(select (data->>'id')::uuid from review_acceptance where key='S1'));
 assert (select data from version_acceptance where key='Inputs')=(select coalesce(jsonb_agg(to_jsonb(i) order by id),'[]') from public.activity_inputs i);
 assert (select count(*) from public.feedback_items where target_version_id=(select (data->>'id')::uuid from review_acceptance where key='V1'))=2;
end$$;

-- Direct authenticated constraint attacks must fail before a row can be forged.
set local role authenticated;
do $$declare a uuid;v uuid;begin
 select (data->>'artifactId')::uuid into a from review_acceptance where key='A';
 select (data->'version'->>'id')::uuid into v from version_acceptance where key='Latest';
 perform pg_temp.reject(format('insert into public.artifact_versions(artifact_id,version_number,content_snapshot,created_by) values(%L,1,''{}'',auth.uid())',a));
 perform pg_temp.reject(format('update public.artifact_versions set previous_version_id=id where id=%L',v));
 perform pg_temp.reject(format('update public.artifact_versions set previous_version_id=%L where id=%L',(select payload->>'initialVersionId' from submitted_fixtures where label='Personal'),v));
 perform pg_temp.reject(format('update public.artifacts set current_version_id=%L where id=%L',(select payload->>'initialVersionId' from submitted_fixtures where label='Personal'),a));
 perform pg_temp.reject(format('update public.artifact_versions set status=''CURRENT'' where id=%L',v));
end$$;
reset role;

-- Real Personal and Team RLS history: exact reviewer never gains future Draft.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert exists(select 1 from public.artifact_versions where artifact_id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'));end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert not exists(select 1 from public.artifact_versions where artifact_id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'));
 assert not exists(select 1 from public.artifact_versions where id=(select (data->'version'->>'id')::uuid from version_acceptance where key='Latest'));
end$$;
select pg_temp.team_b_private();
reset role;set local role anon;
select pg_temp.reject('select * from public.artifact_versions');
reset role;

-- Archive is not deletion. Currently authorized member retains exact history.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.archive_artifact((select (data->>'artifactId')::uuid from review_acceptance where key='A'));
do $$begin assert (select data from version_acceptance where key='History')=(select jsonb_agg(to_jsonb(v) order by version_number) from public.artifact_versions v where artifact_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'));end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not exists(select 1 from public.artifact_versions where artifact_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'));end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert (select count(*) from public.artifact_versions where artifact_id=(select (data->>'artifactId')::uuid from review_acceptance where key='A'))=4;end$$;
reset role;
\echo M8.17 AT-VER-003 ordered canonical history / latest Draft distinct from current / privacy / archive / references PASS
do $$begin
 assert (select draft_revision from public.artifact_versions where id=(select (data->>'initialVersionId')::uuid from review_acceptance where key='A'))=1;
 assert not exists(select 1 from public.artifact_versions where version_number>1 and draft_revision<>0);
end$$;
rollback;
