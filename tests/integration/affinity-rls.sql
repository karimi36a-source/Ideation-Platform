-- Runs after the accepted Affinity item fixture, inside its isolated transaction.
create function pg_temp.rls_reject(statement text,expected text default '42501') returns void language plpgsql as $$
begin begin execute statement;exception when others then if sqlstate=expected then return;end if;raise;end;
 raise exception 'Expected SQLSTATE %',expected;end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
insert into ai_sources select 'Team B Brainstorm Activity',(public.start_activity('00000000-0000-4000-8000-000001113801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='B'))#>>'{activity,id}')::uuid from logged_projects where label='Affinity Team B';
insert into ai_sources select 'Team B Entry',(public.create_brainstorm_entry(id,'B private source','private')->>'id')::uuid from ai_sources where label='Team B Brainstorm Activity';
reset role;
create temporary table ar_items(label text primary key,payload jsonb);grant select,insert,update on ar_items to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ar_items select 'Object',public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',id)) from ai_sources where label='PROBLEM';
insert into ar_items select 'Personal',public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Personal'),'brainstormEntryId',id)) from ai_sources where label='Personal Entry';
do $$begin
 assert (select count(*) from public.affinity_groups where id=(select (payload->>'id')::uuid from ai_groups where label='Team'))=1;
 assert (select count(*) from public.affinity_group_items where id=(select (payload->>'id')::uuid from ar_items where label='Object'))=1;
 assert (select count(*) from public.affinity_group_items where id=(select (payload->>'id')::uuid from ar_items where label='Personal'))=1;
 perform pg_temp.rls_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',(select id from ai_sources where label='Team B Object'))));
 perform pg_temp.rls_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'brainstormEntryId',(select id from ai_sources where label='Peer Entry'))));
 perform pg_temp.rls_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'brainstormEntryId',(select id from ai_sources where label='Team B Entry'))));
end $$;
-- Canonical reveal precedes Team grouping, as required by M11.3.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.reveal_brainstorm_entries((select id from ai_sources where label='Brainstorm Activity'),array[(select id from ai_sources where label='Team Entry')]);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ar_items select 'Revealed',public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'brainstormEntryId',id)) from ai_sources where label='Team Entry';
-- Accepted group and CAS move operations still return verified attribution.
insert into ar_items select 'New Group',public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name','RLS accepted group')) from af_activities where label='Team';
select public.rename_affinity_group(jsonb_build_object('affinityGroupId',payload->>'id','name','Renamed safely')) from ar_items where label='New Group';
update ar_items set payload=public.move_affinity_item(jsonb_build_object('itemId',payload->>'id','targetGroupId',(select payload->>'id' from ai_groups where label='Second'),'position',1,'expectedRevision',0)) where label='Object';
reset role;
-- Malformed trusted historical references must not become source-identity leaks.
insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by)
 select (g.payload->>'id')::uuid,s.id,99,'00000000-0000-4000-8000-000000006004' from ai_groups g cross join ai_sources s where g.label='Team' and s.label='Team B Object';
insert into public.affinity_group_items(affinity_group_id,brainstorm_entry_id,position,added_by)
 select (g.payload->>'id')::uuid,s.id,100,'00000000-0000-4000-8000-000000006004' from ai_groups g cross join ai_sources s where g.label='Team' and s.label='Peer Entry';
create temporary table ar_history as select jsonb_build_object('groups',(select jsonb_agg(to_jsonb(g) order by id) from public.affinity_groups g),'items',(select jsonb_agg(to_jsonb(i) order by id) from public.affinity_group_items i)) payload;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.affinity_group_items where position in (99,100));
 assert (select count(*) from public.affinity_group_items i join public.brainstorm_entries b on b.id=i.brainstorm_entry_id where i.id=(select (payload->>'id')::uuid from ar_items where label='Revealed'))=1;
 assert not exists(select 1 from public.affinity_group_items i join public.development_objects o on o.id=i.development_object_id where o.id=(select id from ai_sources where label='Team B Object'));
end $$;
-- Real normal-client exact-ID, enumeration, CRUD and role/scope spoof attempts.
do $$declare n integer;g uuid:=(select (payload->>'id')::uuid from ai_groups where label='Team');item uuid:=(select (payload->>'id')::uuid from ar_items where label='Object');a uuid:=(select id from af_activities where label='Team');begin
 foreach n in array array[6001,6002,6003,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  perform set_config('request.jwt.claim.role','ADMIN',true);
  assert not exists(select 1 from public.affinity_groups where id=g or activity_instance_id=a);
  assert not exists(select 1 from public.affinity_group_items where id=item or affinity_group_id=g);
  assert not public.can_read_affinity_group(g) and not public.can_read_affinity_item(item);
  assert not public.can_read_affinity_group('00000000-0000-4000-8000-000000999999');
  assert not exists(select 1 from public.affinity_groups where id=(select (payload->>'id')::uuid from ai_groups where label='Personal'));
  perform pg_temp.rls_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',a,'name','Attack')));
  perform pg_temp.rls_reject(format('select public.rename_affinity_group(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'name','Attack')));
  perform pg_temp.rls_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'developmentObjectId',(select id from ai_sources where label='SOLUTION'))));
  perform pg_temp.rls_reject(format('select public.move_affinity_item(%L::jsonb)',jsonb_build_object('itemId',item,'targetGroupId',g,'position',1,'expectedRevision',1)));
  perform pg_temp.rls_reject(format('insert into public.affinity_groups(activity_instance_id,name,sequence,created_by) values(%L,''Attack'',99,%L)',a,'00000000-0000-4000-8000-000000006004'));
  perform pg_temp.rls_reject(format('insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by) values(%L,%L,101,%L)',g,(select id from ai_sources where label='SOLUTION'),'00000000-0000-4000-8000-000000006004'));
  perform pg_temp.rls_reject(format('update public.affinity_groups set created_by=auth.uid(),activity_instance_id=%L where id=%L',a,g));
  perform pg_temp.rls_reject(format('update public.affinity_group_items set added_by=auth.uid(),affinity_group_id=%L,position=1 where id=%L',g,item));
  perform pg_temp.rls_reject(format('delete from public.affinity_groups where id=%L',g));
  perform pg_temp.rls_reject(format('delete from public.affinity_group_items where id=%L',item));
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 perform pg_temp.rls_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',a,'name','Forged','createdBy','00000000-0000-4000-8000-000000006005')),'22023');
 perform pg_temp.rls_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'developmentObjectId',(select id from ai_sources where label='FEATURE'),'addedBy','00000000-0000-4000-8000-000000006005')),'22023');
 perform pg_temp.rls_reject(format('select public.move_affinity_item(%L::jsonb)',jsonb_build_object('itemId',item,'targetGroupId',(select payload->>'id' from ai_groups where label='Team B'),'position',1,'expectedRevision',1)));
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 assert not exists(select 1 from public.affinity_group_items where id=(select (payload->>'id')::uuid from ar_items where label='Personal'));
end $$;
reset role;
-- Demonstrate restrictive guards still protect against an accidental future broad grant/policy.
grant insert,update,delete on public.affinity_groups,public.affinity_group_items to authenticated;
create policy ar_test_broad_group on public.affinity_groups for all to authenticated using(true) with check(true);
create policy ar_test_broad_item on public.affinity_group_items for all to authenticated using(true) with check(true);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$begin assert not exists(select 1 from public.affinity_groups where id=(select (payload->>'id')::uuid from ai_groups where label='Team'));assert not exists(select 1 from public.affinity_group_items where id=(select (payload->>'id')::uuid from ar_items where label='Object'));end $$;
select pg_temp.rls_reject(format('insert into public.affinity_groups(activity_instance_id,name,sequence,created_by) values(%L,''forged'',99,%L)',(select id from af_activities where label='Team'),'00000000-0000-4000-8000-000000006004'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare n integer;begin
 update public.affinity_groups set name='forged';get diagnostics n=row_count;assert n=0;
 delete from public.affinity_group_items;get diagnostics n=row_count;assert n=0;
end $$;
reset role;drop policy ar_test_broad_group on public.affinity_groups;drop policy ar_test_broad_item on public.affinity_group_items;
revoke insert,update,delete on public.affinity_groups,public.affinity_group_items from authenticated;
-- Existing non-editable lifecycle enforcement is unchanged.
do $$declare state public.activity_instance_status;begin
 foreach state in array array['completed'::public.activity_instance_status,'archived'::public.activity_instance_status] loop
  begin
   update public.activity_instances set status=state,completed_at=case when state='completed' then clock_timestamp() else null end where id=(select id from af_activities where label='Team');
   set local role authenticated;perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
   perform pg_temp.rls_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'name','No reopen')),'55000');
   perform pg_temp.rls_reject(format('select public.rename_affinity_group(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'name','No reopen')),'55000');
   perform pg_temp.rls_reject(format('select public.move_affinity_item(%L::jsonb)',jsonb_build_object('itemId',(select payload->>'id' from ar_items where label='Object'),'targetGroupId',(select payload->>'id' from ai_groups where label='Team'),'position',1,'expectedRevision',1)),'55000');
   raise exception using errcode='ZX119';exception when sqlstate 'ZX119' then null;end;
 end loop;
end $$;
reset role;set local role authenticated;select set_config('request.jwt.claim.sub','',true);
do $$begin assert not exists(select 1 from public.affinity_groups);assert not exists(select 1 from public.affinity_group_items);end $$;
reset role;set local role anon;
select pg_temp.rls_reject('select * from public.affinity_groups');select pg_temp.rls_reject('select * from public.affinity_group_items');
reset role;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.affinity_groups where activity_instance_id=(select id from af_activities where label='Team'));
 assert not exists(select 1 from public.affinity_group_items where id=(select (payload->>'id')::uuid from ar_items where label='Object'));
 perform pg_temp.rls_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'name','Removed')));
 perform pg_temp.rls_reject(format('select public.rename_affinity_group(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'name','Removed')));
 perform pg_temp.rls_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',(select id from ai_sources where label='FEATURE'))));
 perform pg_temp.rls_reject(format('select public.move_affinity_item(%L::jsonb)',jsonb_build_object('itemId',(select payload->>'id' from ar_items where label='Object'),'targetGroupId',(select payload->>'id' from ai_groups where label='Team'),'position',1,'expectedRevision',1)));
end $$;
reset role;
do $$begin
 assert (select payload from ar_history)=jsonb_build_object('groups',(select jsonb_agg(to_jsonb(g) order by id) from public.affinity_groups g),'items',(select jsonb_agg(to_jsonb(i) order by id) from public.affinity_group_items i));
 assert (select (payload->>'added_by')::uuid from ar_items where label='Object')='00000000-0000-4000-8000-000000006004';
 assert (select relrowsecurity from pg_class where oid='public.affinity_groups'::regclass);
 assert (select relrowsecurity from pg_class where oid='public.affinity_group_items'::regclass);
 assert not has_table_privilege('authenticated','public.affinity_groups','INSERT,UPDATE,DELETE');
 assert not has_table_privilege('authenticated','public.affinity_group_items','INSERT,UPDATE,DELETE');
 assert (select bool_and(prosecdef and proconfig=array['search_path=""']) from pg_proc where oid in ('public.can_read_affinity_group(uuid)'::regprocedure,'public.can_read_affinity_item(uuid)'::regprocedure));
 assert not has_function_privilege('anon','public.can_read_affinity_group(uuid)','EXECUTE');
 assert not has_function_privilege('authenticated','private.require_affinity_source(public.activity_instances,uuid,uuid)','EXECUTE');
end $$;
select 'M11.19 Affinity RLS exact-ID/source/reveal/CRUD/spoof/Personal/lifecycle/removal/grants/authorized-operations PASS';
rollback;
