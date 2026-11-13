reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table share_ids(label text primary key,id uuid);
grant select on share_ids to authenticated,anon;
create function pg_temp.share_bad(statement text,expected text default '23514') returns void language plpgsql as $$begin execute statement;raise exception 'Share attack succeeded';exception when others then if sqlstate<>expected then raise;end if;end$$;
do $$begin
 assert (select relrowsecurity from pg_class where oid='public.shares'::regclass);
 assert not has_table_privilege('authenticated','public.shares','INSERT');
 assert not has_table_privilege('anon','public.shares','SELECT');
 assert not has_function_privilege('authenticated','private.validate_share_structure()','EXECUTE');
 assert exists(select 1 from pg_proc where oid='private.validate_share_structure()'::regprocedure and not prosecdef and proconfig=array['search_path=""']);
 assert (select count(*) from pg_indexes where schemaname='public' and tablename='shares')=6;
 assert exists(select 1 from pg_indexes where schemaname='public' and indexname='shares_source_workspace_lookup' and indexdef not like '%WHERE%');
 assert exists(select 1 from pg_indexes where schemaname='public' and indexname='shares_identical_active_unique' and indexdef like '%WHERE (revoked_at IS NULL)%');
end $$;
-- Trusted schema fixtures are not a public Share creation operation.
insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 select 'PATENT_RECORD',pg_temp.research_source('PersonalPatent'),'TEAM',(payload->>'teamId')::uuid,'VIEW','SNAPSHOT' from acceptance_teams where label='A';
insert into share_ids select 'Personal',id from public.shares where shared_entity_id=pg_temp.research_source('PersonalPatent');
insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 select 'PATENT_RECORD',pg_temp.research_source('Patent'),'MASTER',ra.id,'VIEW','SNAPSHOT' from public.role_assignments ra join public.roles r on r.id=ra.role_id
 where r.code='MASTER' and ra.user_id='00000000-0000-4000-8000-000000006002' and ra.cohort_id=(select id from acceptance_cohorts where label='Test');
insert into share_ids select 'Master',id from public.shares where destination_type='MASTER';
insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 select 'EVIDENCE',pg_temp.research_source('Evidence'),'TEAM',(payload->>'teamId')::uuid,'VIEW','SNAPSHOT' from acceptance_teams where label='B';
insert into share_ids select 'Team',id from public.shares where shared_entity_type='EVIDENCE';
do $$declare s public.shares;bad uuid:='ffffffff-ffff-4fff-8fff-ffffffffffff';assignment uuid;begin
 assert (select count(*) from public.shares)=3;
 assert (select count(*) from share_ids)=3;
 select * into s from public.shares where id=(select id from share_ids where label='Team');
 assert s.source_workspace_id=(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team');
 assert s.shared_by=public.current_platform_user_id() and s.revoked_at is null and s.revoked_by is null;
 perform pg_temp.share_bad(format('insert into public.shares select (jsonb_populate_record(null::public.shares,%L::jsonb)).*',to_jsonb(s)||jsonb_build_object('id',gen_random_uuid())),'23505');
 perform pg_temp.share_bad(format('insert into public.shares select (jsonb_populate_record(null::public.shares,%L::jsonb)).*',to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'source_workspace_id',(select payload->>'primary_workspace_id' from logged_projects where label='Individual'))));
 perform pg_temp.share_bad(format('insert into public.shares select (jsonb_populate_record(null::public.shares,%L::jsonb)).*',to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'shared_entity_id',bad)));
 perform pg_temp.share_bad(format('insert into public.shares select (jsonb_populate_record(null::public.shares,%L::jsonb)).*',to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'destination_id',bad)));
 perform pg_temp.share_bad(format('insert into public.shares select (jsonb_populate_record(null::public.shares,%L::jsonb)).*',to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'shared_by',bad)),'42501');
 perform pg_temp.share_bad(format('insert into public.shares select (jsonb_populate_record(null::public.shares,%L::jsonb)).*',to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'revoked_at',clock_timestamp(),'revoked_by',s.shared_by)),'42501');
 perform pg_temp.share_bad($q$select 'SEARCH_LOG'::public.share_entity_type$q$,'22P02');
 select id into assignment from public.role_assignments where user_id='00000000-0000-4000-8000-000000006008' limit 1;
 perform pg_temp.share_bad(format('insert into public.shares select (jsonb_populate_record(null::public.shares,%L::jsonb)).*',to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'destination_type','MASTER','destination_id',assignment)));
 select destination_id into assignment from public.shares where id=(select id from share_ids where label='Master');
 update public.role_assignments set status='inactive' where id=assignment;
 perform pg_temp.share_bad(format('insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values (%L,%L,%L,%L,%L,%L)','PATENT_RECORD',pg_temp.research_source('Patent'),'MASTER',assignment,'COMMENT','SNAPSHOT'));
 update public.role_assignments set status='active',starts_at=statement_timestamp()-interval '2 days',ends_at=statement_timestamp()-interval '1 day' where id=assignment;
 perform pg_temp.share_bad(format('insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values (%L,%L,%L,%L,%L,%L)','PATENT_RECORD',pg_temp.research_source('Patent'),'MASTER',assignment,'COMMENT','SNAPSHOT'));
  update public.role_assignments set starts_at=statement_timestamp()-interval '1 day',ends_at=null where id=assignment;
 update public.role_assignments set starts_at=statement_timestamp()+interval '1 day' where id=assignment;
 perform pg_temp.share_bad(format('insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values (%L,%L,%L,%L,%L,%L)','PATENT_RECORD',pg_temp.research_source('Patent'),'MASTER',assignment,'COMMENT','SNAPSHOT'));
 update public.role_assignments set starts_at=statement_timestamp()-interval '1 day' where id=assignment;
 insert into public.shares select (jsonb_populate_record(null::public.shares,to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'permission_level','COMMENT'))).*;
 -- Vocabulary and uniqueness retain both modes; M13.2 enables only SNAPSHOT.
 perform 'LIVE_REFERENCE'::public.share_mode;
 assert exists(select 1 from pg_indexes where indexname='shares_identical_active_unique' and indexdef like '%permission_level, share_mode)%');
 perform pg_temp.share_bad(format('insert into public.shares select (jsonb_populate_record(null::public.shares,%L::jsonb)).*',to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'share_mode','LIVE_REFERENCE')),'0A000');
 update public.shares set revoked_at=clock_timestamp(),revoked_by=public.current_platform_user_id() where id=s.id;
 insert into public.shares select (jsonb_populate_record(null::public.shares,to_jsonb(s)||jsonb_build_object('id',gen_random_uuid()))).*;
 assert exists(select 1 from public.shares where id=s.id and revoked_at is not null);
 perform pg_temp.share_bad(format('delete from public.shares where id=%L',s.id));
 perform pg_temp.share_bad(format('update public.shares set revoked_at=null,revoked_by=null where id=%L',s.id));
end $$;
-- Every approved canonical source table, plus every structural destination.
do $$declare p jsonb;r jsonb;f jsonb;entry uuid;begin
 select payload into p from logged_projects where label='Individual';
 insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
 select id,(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,public.current_platform_user_id(),'SUBSTITUTE','Original','Proposed','Result' from instances where label='Individual' returning id into entry;
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('SCAMPER_ENTRY',entry,'USER','00000000-0000-4000-8000-000000006006','VIEW','SNAPSHOT');
 r:=public.request_file_upload((p->>'primary_workspace_id')::uuid,(p->>'id')::uuid,'share.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',r->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((r->>'id')::uuid);
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('FILE',(f->>'id')::uuid,'WORKSPACE',(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),'VIEW','SNAPSHOT');
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('ARTIFACT',pg_temp.research_source('Landscape'),'COHORT',(select id from acceptance_cohorts where label='Test'),'VIEW','SNAPSHOT');
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values('DEVELOPMENT_OBJECT',pg_temp.research_source('Gap'),'USER','00000000-0000-4000-8000-000000006006','COLLABORATE','SNAPSHOT');
 assert (select count(distinct shared_entity_type) from public.shares)=6;
 assert (select count(distinct destination_type) from public.shares)=5;
end $$;
select 'SHARE_SCHEMA_ROW='||to_jsonb(s)::text from public.shares s where id=(select id from share_ids where label='Team');
select 'SHARE_VOCABULARY='||jsonb_build_object('entities',enum_range(null::public.share_entity_type),'destinations',enum_range(null::public.share_destination_type),'permissions',enum_range(null::public.share_permission_level),'modes',enum_range(null::public.share_mode))::text;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M13.1 access revocation regression');
-- No Share or source access bridge, including if SELECT/DML grants are accidentally added.
grant select,insert,update,delete on public.shares to authenticated;
set local role authenticated;
do $$declare n integer;begin
 foreach n in array array[6001,6002,6003,6004,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  assert not exists(select 1 from public.shares),'Shares remain inert under RLS';
  assert not exists(select 1 from public.patent_records where id=pg_temp.research_source('Patent'));
  assert not exists(select 1 from public.evidence where id=pg_temp.research_source('Evidence'));
  assert not exists(select 1 from public.shares s join public.evidence e on e.id=s.shared_entity_id);
  perform pg_temp.share_bad(format('insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values (%L,%L,%L,%L,%L,%L)','EVIDENCE',pg_temp.research_source('Evidence'),'USER','00000000-0000-4000-8000-000000006006','VIEW','SNAPSHOT'),'42501');
 end loop;
end $$;
reset role;
revoke all on public.shares from authenticated;
select 'M13.1 shares canonical-source/scoped-MASTER/uniqueness/history/spoof/default-deny/privacy PASS';
rollback;
