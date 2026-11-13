-- Prepended canonical disposable fixture; trusted writes validate schema only.
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table scamper_context as select i.id activity,i.project_id,i.workspace_id,
 (select (payload->>'id')::uuid from logged_objects where label='Individual Idea') idea,
 (select (payload->>'id')::uuid from logged_objects where label='Problem') problem,
 (select (payload->>'id')::uuid from logged_objects where label='Team Idea') foreign_idea,
 (select (payload->>'id')::uuid from logged_projects where label='Team') foreign_project,
 (select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team') foreign_workspace
 from public.activity_instances i join instances x on x.id=i.id where x.label='Individual';
create function pg_temp.scamper_insert(a uuid,p uuid,w uuid,creator uuid,lens public.scamper_lens,idea uuid default null) returns uuid
 language sql as $$insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text,idea_object_id)
 values(a,p,w,creator,lens,'Original','Proposed','Result',idea) returning id$$;
select pg_temp.scamper_insert(activity,project_id,workspace_id,'00000000-0000-4000-8000-000000006004',lens,idea)
 from scamper_context cross join unnest(enum_range(null::public.scamper_lens)) lens;
create temporary table scamper_before as select * from public.scamper_entries;
do $$declare c record;entry uuid;begin
 select * into strict c from scamper_context;
 assert (select count(*) from public.scamper_entries)=7;
 assert (select count(distinct scamper_type) from public.scamper_entries)=7;
 assert not exists(select 1 from public.scamper_entries where status<>'active' or archived_at is not null or updated_by<>created_by);
 begin perform 'CUSTOM'::public.scamper_lens;raise exception 'Invalid lens accepted';exception when invalid_text_representation then null;end;
 begin perform 'approved'::public.scamper_entry_status;raise exception 'Invalid status accepted';exception when invalid_text_representation then null;end;
 begin perform pg_temp.scamper_insert(c.activity,c.foreign_project,c.workspace_id,'00000000-0000-4000-8000-000000006004','SUBSTITUTE');raise exception 'Project mismatch';exception when check_violation then null;end;
 begin perform pg_temp.scamper_insert(c.activity,c.project_id,c.foreign_workspace,'00000000-0000-4000-8000-000000006004','SUBSTITUTE');raise exception 'Workspace mismatch';exception when check_violation then null;end;
 begin perform pg_temp.scamper_insert(c.activity,c.project_id,c.workspace_id,'00000000-0000-4000-8000-000000006005','SUBSTITUTE');raise exception 'Creator spoof';exception when insufficient_privilege then null;end;
 begin perform pg_temp.scamper_insert(c.activity,c.project_id,c.workspace_id,'00000000-0000-4000-8000-000000006004','SUBSTITUTE',c.problem);raise exception 'Non IDEA';exception when check_violation then null;end;
 begin perform pg_temp.scamper_insert(c.activity,c.project_id,c.workspace_id,'00000000-0000-4000-8000-000000006004','SUBSTITUTE',c.foreign_idea);raise exception 'Foreign IDEA';exception when check_violation then null;end;
 select id into entry from public.scamper_entries where scamper_type='SUBSTITUTE';
 begin update public.scamper_entries set id=gen_random_uuid() where id=entry;raise exception 'Identity rewritten';exception when check_violation then null;end;
 begin update public.scamper_entries set created_by='00000000-0000-4000-8000-000000006005' where id=entry;raise exception 'Creator rewritten';exception when check_violation then null;end;
 begin update public.scamper_entries set status='archived' where id=entry;raise exception 'Missing archive time';exception when check_violation then null;end;
 begin update public.scamper_entries set archived_at=now() where id=entry;raise exception 'Active archive time';exception when check_violation then null;end;
 update public.scamper_entries set status='archived',archived_at=now() where id=entry;
 assert exists(select 1 from public.scamper_entries s join scamper_before b using(id) where s.id=entry and s.status='archived' and s.archived_at is not null and s.created_at=b.created_at and s.created_by=b.created_by and s.idea_object_id=b.idea_object_id and s.result_text=b.result_text);
 begin update public.scamper_entries set status='active',archived_at=null where id=entry;raise exception 'Restore';exception when check_violation then null;end;
 begin delete from public.scamper_entries where id=entry;raise exception 'History deleted';exception when check_violation then null;end;
 assert (select count(*) from public.scamper_entries)=7;
 assert (select relrowsecurity from pg_class where oid='public.scamper_entries'::regclass);
 assert not exists(select 1 from pg_proc where oid='public.validate_scamper_entry()'::regprocedure and prosecdef);
 assert (select proconfig=array['search_path=""'] from pg_proc where oid='public.validate_scamper_entry()'::regprocedure);
 assert not has_function_privilege('authenticated','public.validate_scamper_entry()','EXECUTE');
end $$;
grant select on scamper_context,scamper_before to authenticated,anon;
set local role authenticated;
do $$begin
 begin perform * from public.scamper_entries;raise exception 'Client read';exception when insufficient_privilege then null;end;
 begin insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
 select activity,project_id,workspace_id,'00000000-0000-4000-8000-000000006005','SUBSTITUTE','','','' from scamper_context;
 raise exception 'Client insert';exception when insufficient_privilege then null;end;
 begin update public.scamper_entries set status='active',archived_at=null;raise exception 'Client update';exception when insufficient_privilege then null;end;
 begin delete from public.scamper_entries;raise exception 'Client delete';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Hostile accidental grants and a catch-all policy must not bypass restrictive RLS.
grant select,insert,update,delete on public.scamper_entries to authenticated,anon;
create policy scamper_hostile_test on public.scamper_entries for all to authenticated,anon using(true) with check(true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert not exists(select 1 from public.scamper_entries);
 assert not exists(select 1 from public.scamper_entries where id=(select id from scamper_before limit 1));
 update public.scamper_entries set status='archived',archived_at=now();assert not found;
 delete from public.scamper_entries;assert not found;
 begin insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,scamper_type,original_element,proposed_change,result_text)
 select activity,project_id,workspace_id,'SUBSTITUTE','','','' from scamper_context;
 raise exception 'Hostile policy bypass';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert not exists(select 1 from public.scamper_entries);end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
do $$begin assert not exists(select 1 from public.scamper_entries);end $$;
set local role anon;
do $$begin assert not exists(select 1 from public.scamper_entries);end $$;
reset role;
do $$begin assert (select count(*) from public.scamper_entries)=7;end $$;
select 'M91_LENSES='||json_agg(enumlabel order by enumsortorder)::text from pg_enum where enumtypid='public.scamper_lens'::regtype;
select 'M91_COLUMNS='||json_agg(attname order by attname)::text from pg_attribute where attrelid='public.scamper_entries'::regclass and attnum>0 and not attisdropped;
rollback;
\echo M9.1 seven lenses / provenance / IDEA / creator / archive history / hostile RLS PASS
