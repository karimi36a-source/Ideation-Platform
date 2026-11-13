reset role;
select set_config('request.jwt.claim.sub','',true);
update public.teams set status='active' where id in(select (payload->>'teamId')::uuid from acceptance_teams);
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects p where label='Team' and not exists(select 1 from public.project_memberships m where m.project_id=(p.payload->>'id')::uuid and m.user_id='00000000-0000-4000-8000-000000006005');
create temporary table af_activities(label text primary key,id uuid);
create temporary table af_groups(label text primary key,payload jsonb);
grant select,insert,update on af_activities,af_groups to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into af_activities select 'Team',(public.start_activity('00000000-0000-4000-8000-000001112801',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,(select (payload->>'teamId')::uuid from acceptance_teams where label='A'))#>>'{activity,id}')::uuid from logged_projects where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into af_activities select 'Personal',(public.start_activity('00000000-0000-4000-8000-000001112802',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid)#>>'{activity,id}')::uuid from logged_projects where label='Individual';
reset role;
select set_config('request.jwt.claim.sub','',true);
-- Assertions
create function pg_temp.af_reject(statement text,expected text) returns void language plpgsql as $$begin
 begin execute statement;exception when others then if sqlstate=expected then return;end if;raise;end;raise exception 'Expected rejection %',expected;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into af_groups select 'Team',public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name',chr(160)||'Natural label'||chr(8192),'description',' Description ')) from af_activities where label='Team';
insert into af_groups select 'Second',public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name','Natural label')) from af_activities where label='Team';
do $$declare a uuid;g uuid;before0 jsonb;after0 jsonb;begin
 select id into a from af_activities where label='Team';select (payload->>'id')::uuid into g from af_groups where label='Team';
 assert (select payload->>'name' from af_groups where label='Team')='Natural label';
 assert (select payload->>'description' from af_groups where label='Team')='Description';
 assert (select payload->>'created_by' from af_groups where label='Team')=public.current_platform_user_id()::text;
 assert (select (payload->>'sequence')::int from af_groups where label='Second')=2;
 perform pg_temp.af_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',a,'name',chr(160)||chr(8192))),'22023');
 foreach before0 in array array[jsonb_build_object('createdBy',public.current_platform_user_id()),jsonb_build_object('sequence',20),jsonb_build_object('role','ADMIN')] loop
  perform pg_temp.af_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',a,'name','Spoof')||before0),'22023');
 end loop;
 before0:=(select payload from af_groups where label='Team');
 after0:=public.rename_affinity_group(jsonb_build_object('affinityGroupId',g,'name',' Renamed ','description',' New description '));
 assert after0->>'name'='Renamed' and after0->>'description'='New description';
 assert after0-'name'-'description'=before0-'name'-'description';
 assert public.rename_affinity_group(jsonb_build_object('affinityGroupId',g,'name','Renamed','description','New description'))=after0;
 assert public.rename_affinity_group(jsonb_build_object('affinityGroupId',g,'name','Renamed'))=after0;
 perform pg_temp.af_reject(format('insert into public.affinity_groups(activity_instance_id,name,sequence,created_by) values(%L,''Forged'',99,%L)',a,public.current_platform_user_id()),'42501');
 perform pg_temp.af_reject(format('update public.affinity_groups set sequence=99,created_by=%L where id=%L',public.current_platform_user_id(),g),'42501');
 perform pg_temp.af_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',(select id from instances where label='Team'),'name','Wrong method')),'22023');
end $$;
reset role;select set_config('request.jwt.claim.sub','',true);
-- Trusted linkage fixture only: no M11.3 client operation.
insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by)
 select (g.payload->>'id')::uuid,(o.payload->>'id')::uuid,1,(g.payload->>'created_by')::uuid from af_groups g cross join logged_objects o where g.label='Team' and o.label='Team Idea';
insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,created_by,content) select i.id,i.project_id,i.workspace_id,i.started_by,'Preserved source' from instances x join public.activity_instances i on i.id=x.id where x.label='Team';
insert into public.affinity_group_items(affinity_group_id,brainstorm_entry_id,position,added_by) select (g.payload->>'id')::uuid,b.id,2,(g.payload->>'created_by')::uuid from af_groups g cross join public.brainstorm_entries b where g.label='Team';
create temporary table af_preserved as select jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'brainstorm',(select jsonb_agg(to_jsonb(x) order by id) from public.brainstorm_entries x),'items',(select jsonb_agg(to_jsonb(x) order by id) from public.affinity_group_items x),'activities',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x),'baselines',(select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x)) payload;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.rename_affinity_group(jsonb_build_object('affinityGroupId',(select payload->>'id' from af_groups where label='Team'),'name','Sources retained'));
do $$declare n int;a uuid;g uuid;begin
 select id into a from af_activities where label='Team';select (payload->>'id')::uuid into g from af_groups where label='Team';
 foreach n in array array[6001,6003,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  perform pg_temp.af_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',a,'name','Unauthorized')),'42501');
  perform pg_temp.af_reject(format('select public.rename_affinity_group(%L::jsonb)',jsonb_build_object('affinityGroupId',g,'name','Unauthorized')),'42501');
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into af_groups select 'Personal',public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name','Owner only')) from af_activities where label='Personal';
select public.rename_affinity_group(jsonb_build_object('affinityGroupId',(select payload->>'id' from af_groups where label='Personal'),'name','Owner rename'));
reset role;select set_config('request.jwt.claim.sub','',true);
create function pg_temp.af_fail() returns trigger language plpgsql as $$begin if new.name='Forced rollback' then raise exception 'Injected failure' using errcode='ZX113';end if;return new;end $$;
create trigger af_failure_fixture after insert on public.affinity_groups for each row execute function pg_temp.af_fail();
create temporary table af_count_before as select count(*) n from public.affinity_groups;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.af_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'name','Forced rollback')),'ZX113');
reset role;select set_config('request.jwt.claim.sub','',true);
do $$begin assert (select count(*) from public.affinity_groups)=(select n from af_count_before);end $$;
drop trigger af_failure_fixture on public.affinity_groups;
do $$declare f regprocedure;begin
 foreach f in array array['public.create_affinity_group(jsonb)'::regprocedure,'public.rename_affinity_group(jsonb)'::regprocedure,'private.require_affinity_write(uuid)'::regprocedure] loop
  assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid=f);
  assert not has_function_privilege('anon',f,'execute');assert not has_function_privilege('service_role',f,'execute');
 end loop;
 assert not has_function_privilege('authenticated','private.require_affinity_write(uuid)','execute');
end $$;
do $$declare status0 public.activity_instance_status;begin
 foreach status0 in array array['completed'::public.activity_instance_status,'archived'::public.activity_instance_status] loop
  begin
   update public.activity_instances set status=status0,completed_at=case when status0='completed' then clock_timestamp() else null end where id=(select id from af_activities where label='Team');
   perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
   perform pg_temp.af_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'name','Closed')),'55000');
   perform pg_temp.af_reject(format('select public.rename_affinity_group(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from af_groups where label='Team'),'name','Closed')),'55000');
   raise exception using errcode='ZX112';
  exception when sqlstate 'ZX112' then null;end;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','',true);
do $$begin assert (select payload from af_preserved)=jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'brainstorm',(select jsonb_agg(to_jsonb(x) order by id) from public.brainstorm_entries x),'items',(select jsonb_agg(to_jsonb(x) order by id) from public.affinity_group_items x),'activities',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x),'baselines',(select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x));end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.af_reject(format('select public.rename_affinity_group(%L::jsonb)',jsonb_build_object('affinityGroupId',(select payload->>'id' from af_groups where label='Team'),'name','Former creator')),'42501');
select pg_temp.af_reject(format('select public.create_affinity_group(%L::jsonb)',jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'name','Removed')),'42501');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.af_reject('select public.create_affinity_group(''{}''::jsonb)','28000');
reset role;
select 'M11.2 authority/strict inputs/Unicode labels/sequence/rename/no-op/source preservation/exact-ID/direct denial/lifecycle/removal PASS';
rollback;
