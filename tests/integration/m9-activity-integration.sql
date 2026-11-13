-- Actual canonical PostgreSQL promotion/output/resume integration.
do $$declare v record;a public.activity_instances;o public.development_objects;res jsonb;begin
 for v in select * from m914_activities order by n loop
  select * into a from public.activity_instances where id=(v.payload#>>'{activity,id}')::uuid;
  select * into o from public.development_objects where id=(select (payload->>'id')::uuid from m914_ideas where n=v.n);
  assert a.project_id=o.project_id and a.workspace_id=o.workspace_id;
  assert (select count(*) from public.activity_outputs where activity_instance_id=a.id and development_object_id=o.id)=case when v.n in(3,6,7,8) then 1 else 0 end,'Snapshot opt-in mismatch';
  assert (select count(*) from public.development_objects where origin_reference_id=(select (payload->>'id')::uuid from m914_entries where n=v.n))=1;
  assert a.configuration_snapshot=v.payload#>'{activity,configuration_snapshot}','Historical snapshot changed';
 end loop;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare v record;idea jsonb;res jsonb;begin
 for v in select * from m914_entries order by n loop
  idea:=case when v.n in(1,2,3,7) then public.promote_scamper_entry_to_idea((v.payload->>'id')::uuid) else public.promote_brainstorm_entry_to_idea((v.payload->>'id')::uuid) end;
  assert idea=(select payload from m914_ideas where n=v.n),'Retry changed canonical IDEA';
  res:=public.resume_activity((select (payload#>>'{activity,id}')::uuid from m914_activities where n=v.n));
  assert (select array_agg(key order by key) from jsonb_object_keys(res) key)=array['activity','definition','inputs','outputs','participants'],'Generic resume contract expanded';
  assert jsonb_array_length(res->'outputs')=case when v.n in(3,6,7,8) then 1 else 0 end;
  assert res=public.resume_activity((res#>>'{activity,id}')::uuid),'Read-only reuse changed state';
  if v.n in(1,2,3,7) then
   assert public.get_scamper_entry((v.payload->>'id')::uuid)->>'idea_object_id'=idea->>'id';
   assert exists(select 1 from jsonb_array_elements(public.list_scamper_entries((res#>>'{activity,id}')::uuid)) x where x->>'id'=v.payload->>'id');
  else
   assert exists(select 1 from public.brainstorm_entries where id=(v.payload->>'id')::uuid and (revealed_at is null)=(v.n<>8) and development_object_id=(idea->>'id')::uuid);
  end if;
 end loop;
end $$;
reset role;
-- Force the required output insertion to fail inside promotion, not afterward.
create function pg_temp.m914_fail_output() returns trigger language plpgsql as $$begin raise exception 'M9.14 injected output failure' using errcode='P0001';end $$;
create trigger m914_fail_output before insert on public.activity_outputs for each row execute function pg_temp.m914_fail_output();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare n0 int;entry jsonb;obj_count bigint;log_count bigint;begin
 foreach n0 in array array[3,6] loop
  entry:=case when n0=3 then public.create_scamper_entry((select (payload#>>'{activity,id}')::uuid from m914_activities where n=n0),'COMBINE','Rollback','Rollback','Rollback') else public.create_brainstorm_entry((select (payload#>>'{activity,id}')::uuid from m914_activities where n=n0),'Rollback','private') end;
  select count(*) into obj_count from public.development_objects;
  select count(*) into log_count from public.change_log;
  begin
   if n0=3 then perform public.promote_scamper_entry_to_idea((entry->>'id')::uuid);else perform public.promote_brainstorm_entry_to_idea((entry->>'id')::uuid);end if;
   raise exception 'Output failure did not roll back' using errcode='XX000';
  exception when sqlstate 'P0001' then null;end;
  assert (select count(*) from public.development_objects)=obj_count;
  assert (select count(*) from public.change_log)=log_count;
  if n0=3 then assert public.get_scamper_entry((entry->>'id')::uuid)->>'idea_object_id' is null;
  else assert (select development_object_id is null from public.brainstorm_entries where id=(entry->>'id')::uuid);end if;
 end loop;
end $$;
reset role;
drop trigger m914_fail_output on public.activity_outputs;
-- Peer and unrelated Master cannot recover Personal methodology by exact ID.
set local role authenticated;
do $$declare actor uuid;v record;begin
 foreach actor in array array['00000000-0000-4000-8000-000000006005'::uuid,'00000000-0000-4000-8000-000000006003'::uuid] loop
  perform set_config('request.jwt.claim.sub',actor::text,true);
  for v in select * from m914_activities where n<=6 loop
   assert public.resume_activity((v.payload#>>'{activity,id}')::uuid) is null;
   begin perform public.list_scamper_entries((v.payload#>>'{activity,id}')::uuid);raise exception 'Activity source discovery leaked' using errcode='XX000';exception when insufficient_privilege then assert sqlerrm='Resource unavailable';end;
   begin perform 1 from public.scamper_entries where activity_instance_id=(v.payload#>>'{activity,id}')::uuid;raise exception 'Direct SCAMPER table grant' using errcode='XX000';exception when insufficient_privilege then null;end;
   assert not exists(select 1 from public.brainstorm_entries where activity_instance_id=(v.payload#>>'{activity,id}')::uuid);
   assert not exists(select 1 from public.activity_outputs where activity_instance_id=(v.payload#>>'{activity,id}')::uuid);
  end loop;
 end loop;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert exists(select 1 from jsonb_array_elements(public.list_scamper_entries((select (payload#>>'{activity,id}')::uuid from m914_activities where n=1))) s where s->>'proposed_change'='Unpromoted persisted source' and s->>'idea_object_id' is null),'Unpromoted source cannot be reconstructed after resume';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$declare v record;begin for v in select * from m914_activities where n in(7,8) loop
 assert public.resume_activity((v.payload#>>'{activity,id}')::uuid) is null;
 begin perform public.list_scamper_entries((v.payload#>>'{activity,id}')::uuid);raise exception 'Team B discovery bypass' using errcode='XX000';exception when insufficient_privilege then null;end;
end loop;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare v record;begin for v in select * from m914_activities where n in(7,8) loop
 assert public.resume_activity((v.payload#>>'{activity,id}')::uuid) is null;
 begin perform public.list_scamper_entries((v.payload#>>'{activity,id}')::uuid);raise exception 'Removed source reload bypass' using errcode='XX000';exception when insufficient_privilege then null;end;
 assert not exists(select 1 from public.brainstorm_entries where activity_instance_id=(v.payload#>>'{activity,id}')::uuid);
 assert not exists(select 1 from public.activity_outputs where activity_instance_id=(v.payload#>>'{activity,id}')::uuid);
end loop;
 assert public.resume_activity((select (payload#>>'{activity,id}')::uuid from m914_activities where n=1)) is not null;
end $$;
reset role;
do $$begin
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.list_scamper_entries(uuid)'::regprocedure);
 assert has_function_privilege('authenticated','public.list_scamper_entries(uuid)','EXECUTE');
 assert not has_function_privilege('anon','public.list_scamper_entries(uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.list_scamper_entries(uuid)','EXECUTE');
 assert not has_table_privilege('authenticated','public.scamper_entries','SELECT');
end $$;
select 'M9.14 unpromoted source discovery + Team/removed revocation + fixed grants PASS';
select 'M9.14 snapshot IDEA matrix/retry/atomic rollback/generic resume/Personal exact-ID PASS';
rollback;
