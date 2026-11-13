-- Prepended accepted M8 Project fixture; these privileged writes test storage,
-- not a new public Evidence creation/verification operation.
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into public.project_memberships(project_id,user_id)
 select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects p where label='Team'
 and not exists(select 1 from public.project_memberships m where m.project_id=(p.payload->>'id')::uuid
  and m.user_id='00000000-0000-4000-8000-000000006005' and m.status='active'
  and m.starts_at<=statement_timestamp() and (m.ends_at is null or m.ends_at>statement_timestamp()));
create temporary table ev_scope as select label,(payload->>'id')::uuid project_id,(payload->>'primary_workspace_id')::uuid workspace_id from logged_projects;
grant select on ev_scope to authenticated;
create function pg_temp.ev_insert(kind public.evidence_type,creator uuid default public.current_platform_user_id(),state public.evidence_verification_status default 'UNVERIFIED',verifier uuid default null,verified timestamptz default null) returns uuid language sql as $$
 insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name,source_url,created_by,verification_status,verified_by,verified_at,claim_locator)
 select project_id,workspace_id,kind,'Source-backed record','Recorded source information','Named source / capture notes',
 case when kind in ('CUSTOMER_INTERVIEW','MEASUREMENT','CALCULATION','TEST_RESULT','OTHER') then null else 'https://example.test/source' end,
 creator,state,verifier,verified,case when kind='PATENT_CLAIM' then 'Claim 1' else null end from ev_scope where label='Team' returning id
$$;
select pg_temp.ev_insert(kind) from unnest(enum_range(null::public.evidence_type)) kind;
insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name)
 select project_id,workspace_id,'CUSTOMER_INTERVIEW','Private interview','Personal source notes','Interview P1, recorded offline' from ev_scope where label='Individual';

do $$declare v public.evidence_verification_status;e uuid;bad text;begin
 assert (select count(*) from public.evidence where project_id=(select project_id from ev_scope where label='Team'))=12;
 assert (select count(distinct evidence_type) from public.evidence)=12;
 assert not exists(select 1 from public.evidence where verification_status<>'UNVERIFIED' or verified_by is not null or verified_at is not null or created_by<>public.current_platform_user_id());
 assert exists(select 1 from public.evidence where evidence_type='MEASUREMENT' and source_url is null and file_id is null and length(source_name)>0);
 assert exists(select 1 from public.evidence where evidence_type='PATENT' and source_url='https://example.test/source');
 assert not exists(select 1 from public.evidence where captured_at is null or archived_at is not null);
 begin perform 'AI_ANALYSIS'::public.evidence_type;raise exception 'Extra type accepted';exception when invalid_text_representation then null;end;
 begin perform 'APPROVED'::public.evidence_verification_status;raise exception 'Extra state accepted';exception when invalid_text_representation then null;end;
 begin perform pg_temp.ev_insert('OTHER','00000000-0000-4000-8000-000000006005');raise exception 'Creator spoof accepted';exception when insufficient_privilege then null;end;
 foreach v in array array['PARTIALLY_VERIFIED','VERIFIED','CONTRADICTED','NEEDS_REVIEW']::public.evidence_verification_status[] loop
  begin perform pg_temp.ev_insert('OTHER',public.current_platform_user_id(),v);raise exception 'Initial verification accepted';exception when insufficient_privilege then null;end;
 end loop;
 begin perform pg_temp.ev_insert('OTHER',public.current_platform_user_id(),'UNVERIFIED',public.current_platform_user_id());raise exception 'Verifier spoof accepted';exception when insufficient_privilege then null;end;
 begin perform pg_temp.ev_insert('OTHER',public.current_platform_user_id(),'UNVERIFIED',null,now());raise exception 'Time spoof accepted';exception when insufficient_privilege then null;end;
 select id into e from public.evidence where evidence_type='PATENT';
 begin update public.evidence set verified_by=public.current_platform_user_id() where id=e;raise exception 'UNVERIFIED verifier accepted';exception when check_violation then null;end;
 begin update public.evidence set verified_at=now() where id=e;raise exception 'UNVERIFIED time accepted';exception when check_violation then null;end;
 -- Only vocabulary/consistency is tested here; no verification authority/API.
 foreach v in array enum_range(null::public.evidence_verification_status) loop
  update public.evidence set verification_status=v,verified_by=null,verified_at=null where id=e;
 end loop;
 update public.evidence set verification_status='NEEDS_REVIEW',verified_by=public.current_platform_user_id(),verified_at=null where id=e;
 update public.evidence set verification_status='UNVERIFIED',verified_by=null,verified_at=null where id=e;
 begin update public.evidence set source_name=null where id=e;raise exception 'Missing source accepted';exception when not_null_violation then null;end;
 begin update public.evidence set source_name='  ',metadata='{"source_name":"metadata cannot replace source"}' where id=e;raise exception 'Blank source accepted';exception when check_violation then null;end;
 foreach bad in array array['javascript:alert(1)','file:///private','https://','https://example.test/a b'] loop
  begin update public.evidence set source_url=bad where id=e;raise exception 'Bad URL accepted';exception when check_violation then null;end;
 end loop;
 begin update public.evidence set metadata='[]' where id=e;raise exception 'Non-object metadata accepted';exception when check_violation then null;end;
 begin insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name)
  select t.project_id,p.workspace_id,'OTHER','Mismatch','Description','Source' from ev_scope t cross join ev_scope p where t.label='Team' and p.label='Individual';raise exception 'Cross-scope accepted';exception when foreign_key_violation then null;end;
 begin update public.evidence set created_by='00000000-0000-4000-8000-000000006005' where id=e;raise exception 'Creator rewritten';exception when check_violation then null;end;
 begin update public.evidence set captured_at=now()+interval '1 day' where id=e;raise exception 'Capture rewritten';exception when check_violation then null;end;
 update public.evidence set archived_at=clock_timestamp() where id=e;
 assert exists(select 1 from public.evidence where id=e and archived_at is not null and source_name='Named source / capture notes');
 begin update public.evidence set archived_at=null where id=e;raise exception 'Restore accepted';exception when object_not_in_prerequisite_state then null;end;
 begin delete from public.evidence where id=e;raise exception 'History deleted';exception when object_not_in_prerequisite_state then null;end;
end $$;

create temporary table ev_before as select * from public.evidence;
grant select(id) on ev_before to authenticated;
set local role authenticated;
do $$declare actor uuid;command text;begin
 foreach actor in array array['00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006008']::uuid[] loop
  perform set_config('request.jwt.claim.sub',actor::text,true);
  assert not exists(select 1 from public.evidence);
  assert not exists(select 1 from public.evidence where id=(select id from ev_before limit 1));
  assert not exists(select 1 from public.evidence e join public.development_projects p on p.id=e.project_id);
  foreach command in array array[
   'insert into public.evidence default values',
   'insert into public.evidence(created_by,verification_status) values(''00000000-0000-4000-8000-000000006004'',''VERIFIED'')',
   'update public.evidence set verified_by=created_by,verified_at=now(),verification_status=''VERIFIED''',
   'update public.evidence set archived_at=now() where id=(select id from ev_before limit 1)',
   'delete from public.evidence where id=(select id from ev_before limit 1)'
  ] loop begin execute command;raise exception 'Client mutation accepted';exception when insufficient_privilege then null;end;end loop;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert (select count(*) from public.evidence)=13;begin insert into public.evidence default values;raise exception 'Owner direct INSERT accepted';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert (select count(*) from public.evidence)=12;assert not exists(select 1 from public.evidence where project_id=(select project_id from ev_scope where label='Individual'));end $$;
reset role;
set local role anon;
do $$begin begin perform * from public.evidence;raise exception 'Anonymous read accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.evidence where project_id=(select project_id from ev_scope where label='Team'));
 assert (select count(*) from public.evidence)=1,'Personal Evidence remains owner-private';
 begin update public.evidence set archived_at=now();raise exception 'Removed user mutation accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert (select count(*) from public.evidence)=12;end $$;
reset role;
do $$begin
 assert (select jsonb_agg(to_jsonb(e) order by id) from public.evidence e)=(select jsonb_agg(to_jsonb(e) order by id) from ev_before e),'Removal rewrote Evidence';
 assert not has_table_privilege('authenticated','public.evidence','INSERT');
 assert not has_table_privilege('authenticated','public.evidence','UPDATE');
 assert not has_table_privilege('authenticated','public.evidence','DELETE');
 assert not has_table_privilege('anon','public.evidence','SELECT');
 assert not has_function_privilege('authenticated','private.preserve_evidence_history()','EXECUTE');
 assert exists(select 1 from pg_class where oid='public.evidence'::regclass and relrowsecurity);
 assert not exists(select 1 from pg_constraint where conrelid='public.evidence'::regclass and contype='f' and confdeltype<>'r');
 -- M12.6 resolves the deferred FK; the explicit capture workflow still rejects
 -- non-null File input until secure upload/registration is implemented.
 assert exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey) where c.conrelid='public.evidence'::regclass and contype='f' and a.attname='file_id' and c.confrelid='public.files'::regclass and c.confdeltype='r');
end $$;
select 'EVIDENCE_SCHEMA_ROW='||to_jsonb(e)::text from public.evidence e where project_id=(select project_id from ev_scope where label='Individual');
select 'M12.1 Evidence types/default-UNVERIFIED/one-way-consistency/offline-source/creator-and-verification-spoof/scope/RLS/TeamB/role-only/removal/history/Personal/deferred-file PASS';
rollback;
