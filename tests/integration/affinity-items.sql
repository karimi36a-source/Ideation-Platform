set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
create temporary table ai_groups(label text primary key,payload jsonb);grant select,insert,update on ai_groups to authenticated;
insert into ai_groups select label,public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name',label)) from af_activities where label='Team';
insert into ai_groups select 'Second',public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name','Second')) from af_activities where label='Team';
create temporary table ai_sources(label text primary key,id uuid);grant select,insert on ai_sources to authenticated;
insert into ai_sources select 'Brainstorm Activity',(public.start_activity('00000000-0000-4000-8000-000001113801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'))#>>'{activity,id}')::uuid from logged_projects where label='Team';
insert into ai_sources select 'Other Activity',(public.start_activity('00000000-0000-4000-8000-000001113803',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'))#>>'{activity,id}')::uuid from logged_projects where label='Team';
insert into ai_groups select 'Other',public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name','Other')) from ai_sources where label='Other Activity';
insert into ai_sources select 'Timestamp-only Activity',(public.start_activity('00000000-0000-4000-8000-000001113804',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'))#>>'{activity,id}')::uuid from logged_projects where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ai_groups select 'Personal',public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name','Personal')) from af_activities where label='Personal';
-- Canonical Problems/Solutions exist before grouping; grouping must not recreate them.
insert into ai_sources select kind,(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,kind::public.development_object_type,'Earlier '||kind,'Canonical source',null)->>'id')::uuid from logged_projects cross join unnest(array['PROBLEM','SOLUTION','FEATURE']) kind where label='Team';
insert into ai_sources select 'Personal Brainstorm Activity',(public.start_activity('00000000-0000-4000-8000-000001113802',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid)#>>'{activity,id}')::uuid from logged_projects where label='Individual';
insert into ai_sources select 'Personal Entry',(public.create_brainstorm_entry(id,'Private owner source','private')->>'id')::uuid from ai_sources where label='Personal Brainstorm Activity';
insert into ai_sources select 'Team Entry',(public.create_brainstorm_entry(id,'A1 private source','private')->>'id')::uuid from ai_sources where label='Brainstorm Activity';
insert into ai_sources select 'Timestamp-only Entry',(public.create_brainstorm_entry(id,'Unsupported reveal provenance fixture','private')->>'id')::uuid from ai_sources where label='Timestamp-only Activity';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into ai_sources select 'Peer Entry',(public.create_brainstorm_entry(id,'A2 private source','private')->>'id')::uuid from ai_sources where label='Brainstorm Activity';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('Affinity Team B',public.create_development_project('Affinity B source','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='B'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='B')));
reset role;select set_config('request.jwt.claim.sub','',true);
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006007' from logged_projects where label='Affinity Team B';
insert into public.project_program_links(project_id,program_id,cohort_id) select (p.payload->>'id')::uuid,l.program_id,l.cohort_id from logged_projects p cross join public.project_program_links l where p.label='Affinity Team B' and l.project_id=(select (payload->>'id')::uuid from logged_projects where label='Team') and l.completed_at is null;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
insert into ai_sources select 'Team B Activity',(public.start_activity('00000000-0000-4000-8000-000001112801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='B'))#>>'{activity,id}')::uuid from logged_projects where label='Affinity Team B';
insert into ai_groups select 'Team B',public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name','B')) from ai_sources where label='Team B Activity';
insert into ai_sources select 'Team B Object',(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM','B private','B content',null)->>'id')::uuid from logged_projects where label='Affinity Team B';
reset role;select set_config('request.jwt.claim.sub','',true);
-- Trusted fixture adapter supplies current revisions for pre-CAS ordering regressions only.
create function pg_temp.ai_move(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare rev integer;result jsonb;
begin
 select move_revision into rev from public.affinity_group_items where id=(input->>'itemId')::uuid;
 result:=public.move_affinity_item(input||jsonb_build_object('expectedRevision',coalesce(rev,0)));
 return result;
end $$;
-- Assertions
-- Trusted malformed-history fixture: timestamp alone is NOT canonical Team visibility. No snapshot is rewritten.
update public.brainstorm_entries set revealed_at=clock_timestamp() where id=(select id from ai_sources where label='Timestamp-only Entry');
create temporary table ai_items(label text primary key,payload jsonb);grant select,insert,update on ai_items to authenticated;
create function pg_temp.ai_reject(statement text,expected text) returns void language plpgsql as $$begin begin execute statement;exception when others then if sqlstate=expected then return;end if;raise;end;raise exception 'Expected rejection %',expected;end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare g uuid:= (select (payload->>'id')::uuid from ai_groups where label='Team');e uuid:=(select id from ai_sources where label='Team Entry');begin
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'brainstormEntryId',e)),'42501');
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'brainstormEntryId',(select id from ai_sources where label='Timestamp-only Entry'))),'42501');
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'brainstormEntryId',(select id from ai_sources where label='Peer Entry'))),'42501');
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g)),'22023');
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'brainstormEntryId',e,'developmentObjectId',(select id from ai_sources where label='PROBLEM'))),'22023');
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'developmentObjectId',(select id from ai_sources where label='PROBLEM'),'addedBy',public.current_platform_user_id())),'22023');
end $$;
reset role;do $$begin assert not exists(select 1 from public.brainstorm_entries where id in(select id from ai_sources where label in('Team Entry','Peer Entry')) and revealed_at is not null);end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.reveal_brainstorm_entries((select id from ai_sources where label='Brainstorm Activity'),array[(select id from ai_sources where label='Team Entry'),(select id from ai_sources where label='Peer Entry')]);
reset role;select set_config('request.jwt.claim.sub','',true);
update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=(select id from ai_sources where label='Brainstorm Activity');
create temporary table ai_before as select jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'brainstorm',(select jsonb_agg(to_jsonb(x) order by id) from public.brainstorm_entries x),'activities',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x),'baselines',(select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x)) payload;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into ai_items select label,public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',id)) from ai_sources where label in('PROBLEM','SOLUTION') order by label;
insert into ai_items select 'Entry',public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'brainstormEntryId',id,'position',1)) from ai_sources where label='Peer Entry';
do $$declare g uuid:=(select (payload->>'id')::uuid from ai_groups where label='Team');p uuid:=(select id from ai_sources where label='PROBLEM');item uuid:=(select (payload->>'id')::uuid from ai_items where label='SOLUTION');r jsonb;begin
 assert (select (payload->>'position')::int from ai_items where label='Entry')=1;
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'developmentObjectId',p)),'23505');
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'developmentObjectId',(select id from ai_sources where label='FEATURE'),'position',99)),'22023');
 r:=pg_temp.ai_move(jsonb_build_object('itemId',item,'targetGroupId',g,'position',1));
 assert r->>'id'=item::text and (r->>'position')::int=1;
 assert pg_temp.ai_move(jsonb_build_object('itemId',item,'targetGroupId',g,'position',1))=r;
 perform pg_temp.ai_reject(format('select pg_temp.ai_move(%L::jsonb)',jsonb_build_object('itemId',item,'targetGroupId',(select payload->>'id' from ai_groups where label='Other'),'position',1)),'42501');
 r:=pg_temp.ai_move(jsonb_build_object('itemId',item,'targetGroupId',(select payload->>'id' from ai_groups where label='Second'),'position',1));
 assert r-'affinity_group_id'-'position'-'move_revision'=(select payload-'affinity_group_id'-'position'-'move_revision' from ai_items where label='SOLUTION');
end $$;
insert into ai_items select 'Duplicate other group',public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Second'),'developmentObjectId',id)) from ai_sources where label='PROBLEM';
select pg_temp.ai_reject(format('select pg_temp.ai_move(%L::jsonb)',jsonb_build_object('itemId',(select payload->>'id' from ai_items where label='PROBLEM'),'targetGroupId',(select payload->>'id' from ai_groups where label='Second'),'position',1)),'23505');
insert into ai_items select 'Own revealed Entry',public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Second'),'brainstormEntryId',id)) from ai_sources where label='Team Entry';
select pg_temp.ai_move(jsonb_build_object('itemId',(select payload->>'id' from ai_items where label='Entry'),'targetGroupId',(select payload->>'id' from ai_groups where label='Second'),'position',1));
select pg_temp.ai_move(jsonb_build_object('itemId',(select payload->>'id' from ai_items where label='Entry'),'targetGroupId',(select payload->>'id' from ai_groups where label='Team'),'position',1));
insert into ai_items select 'Personal Entry',public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Personal'),'brainstormEntryId',id)) from ai_sources where label='Personal Entry';
select pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Personal'),'brainstormEntryId',(select id from ai_sources where label='Team Entry'))),'42501');
select pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',(select (payload->>'id')::uuid from logged_objects where label='Problem'))),'42501');
do $$declare n int;g uuid:=(select (payload->>'id')::uuid from ai_groups where label='Team');begin
 foreach n in array array[6001,6003,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'developmentObjectId',(select id from ai_sources where label='PROBLEM'))),'42501');
  perform pg_temp.ai_reject(format('select pg_temp.ai_move(%L::jsonb)',jsonb_build_object('itemId',(select payload->>'id' from ai_items where label='PROBLEM'),'targetGroupId',g,'position',1)),'42501');
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team B'),'developmentObjectId',(select id from ai_sources where label='PROBLEM'))),'42501');
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 perform pg_temp.ai_reject(format('insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by) values(%L,%L,20,%L)',g,(select id from ai_sources where label='FEATURE'),public.current_platform_user_id()),'42501');
 perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'developmentObjectId',(select id from ai_sources where label='Team B Object'))),'42501');
 perform pg_temp.ai_reject('update public.affinity_group_items set position=20,development_object_id=null,added_by=auth.uid()','42501');
end $$;
reset role;select set_config('request.jwt.claim.sub','',true);
create temporary table ai_order_before as select jsonb_agg(to_jsonb(x) order by id) payload from public.affinity_group_items x;
create function pg_temp.ai_fail() returns trigger language plpgsql as $$begin if tg_op='INSERT' then raise exception 'Injected add failure' using errcode='ZX115';end if;if new.affinity_group_id<>old.affinity_group_id then raise exception 'Injected move failure' using errcode='ZX113';end if;return new;end $$;
create trigger ai_insert_failure_fixture after insert on public.affinity_group_items for each row execute function pg_temp.ai_fail();
create trigger ai_failure_fixture after update on public.affinity_group_items for each row execute function pg_temp.ai_fail();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.ai_reject(format('select pg_temp.ai_move(%L::jsonb)',jsonb_build_object('itemId',(select payload->>'id' from ai_items where label='Entry'),'targetGroupId',(select payload->>'id' from ai_groups where label='Second'),'position',1)),'ZX113');
select pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',(select id from ai_sources where label='FEATURE'),'position',1)),'ZX115');
reset role;select set_config('request.jwt.claim.sub','',true);
drop trigger ai_insert_failure_fixture on public.affinity_group_items;
drop trigger ai_failure_fixture on public.affinity_group_items;
do $$declare state public.activity_instance_status;begin
 assert (select jsonb_agg(to_jsonb(x) order by id) from public.affinity_group_items x)=(select payload from ai_order_before);
 foreach state in array array['completed'::public.activity_instance_status,'archived'::public.activity_instance_status] loop
  begin
   update public.activity_instances set status=state,completed_at=case when state='completed' then clock_timestamp() else null end where id=(select id from af_activities where label='Team');
   perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
   perform pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',(select id from ai_sources where label='FEATURE'))),'55000');
   perform pg_temp.ai_reject(format('select pg_temp.ai_move(%L::jsonb)',jsonb_build_object('itemId',(select payload->>'id' from ai_items where label='Entry'),'targetGroupId',(select payload->>'id' from ai_groups where label='Team'),'position',1)),'55000');
   raise exception using errcode='ZX114';exception when sqlstate 'ZX114' then null;end;
 end loop;
 assert (select payload from ai_before)=jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'brainstorm',(select jsonb_agg(to_jsonb(x) order by id) from public.brainstorm_entries x),'activities',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x),'baselines',(select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x));
 assert not exists(select 1 from (select position,row_number() over(partition by affinity_group_id order by position) n from public.affinity_group_items) x where position<>n);
 assert (select revealed_at from public.brainstorm_entries where id=(select id from ai_sources where label='Personal Entry')) is null;
 assert (select development_object_id from public.affinity_group_items where id=(select (payload->>'id')::uuid from ai_items where label='PROBLEM'))=(select id from ai_sources where label='PROBLEM');
 assert (select development_object_id from public.affinity_group_items where id=(select (payload->>'id')::uuid from ai_items where label='SOLUTION'))=(select id from ai_sources where label='SOLUTION');
 assert (select brainstorm_entry_id from public.affinity_group_items where id=(select (payload->>'id')::uuid from ai_items where label='Entry'))=(select id from ai_sources where label='Peer Entry');
 assert not has_function_privilege('authenticated','private.require_affinity_source(public.activity_instances,uuid,uuid)','execute');
 assert not has_function_privilege('authenticated','private.normalize_affinity_positions(uuid)','execute');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.add_affinity_item(jsonb)'::regprocedure);
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.move_affinity_item(jsonb)'::regprocedure);

end $$;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.ai_reject(format('select public.add_affinity_item(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',(select id from ai_sources where label='FEATURE'))),'42501');
select pg_temp.ai_reject(format('select pg_temp.ai_move(%L::jsonb)',jsonb_build_object('itemId',(select payload->>'id' from ai_items where label='Entry'),'targetGroupId',(select payload->>'id' from ai_groups where label='Second'),'position',1)),'42501');
reset role;
do $$begin assert (select jsonb_agg(to_jsonb(x) order by id) from public.affinity_group_items x)=(select payload from ai_order_before);end $$;
select 'M11.3 AT-AFF-001 canonical objects/Brainstorm privacy/history/ordering/identity/duplicate/scope/rollback/direct denial/removal PASS';
select 'M11.3 directly-team-visible source sub-check DEFERRED: no accepted M9 runtime/configuration value';
rollback;
