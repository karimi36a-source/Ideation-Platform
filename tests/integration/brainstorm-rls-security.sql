-- M9.16 BEFORE REVEAL: inserted before the existing canonical reveal command.
set local role authenticated;
do $$declare actor0 integer; hidden0 uuid; missing0 uuid:='ffffffff-ffff-4fff-8fff-ffffffffffff';begin
 select (payload->>'id')::uuid into hidden0 from bc_entries where label='R1';
 foreach actor0 in array array[6004,6005,6009,6002,6001,6003,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor0::text,12,'0'),true);
  assert public.can_read_brainstorm_entry(hidden0)=(actor0=6004),'Hidden predicate';
  assert (select count(*) from public.brainstorm_entries where id=hidden0)=case when actor0=6004 then 1 else 0 end,'Hidden exact ID/count';
  if actor0<>6004 then
   assert (select coalesce(jsonb_agg(to_jsonb(b)),'[]'::jsonb) from public.brainstorm_entries b where id=hidden0)
    =(select coalesce(jsonb_agg(to_jsonb(b)),'[]'::jsonb) from public.brainstorm_entries b where id=missing0),'Existence oracle';
   assert not exists(select 1 from public.brainstorm_entries b join public.activity_instances a on a.id=b.activity_instance_id where b.id=hidden0),'Hidden join leak';
  end if;
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
-- M9.16 AFTER REVEAL AND REMOVAL
-- Ordinary ACLs deny mutations. Then exercise restrictive policies independently
-- with hostile grants/catch-all policy, all rolled back in this disposable DB.
reset role;
select set_config('request.jwt.claim.sub','',true);
create temporary table m916_before as select * from public.brainstorm_entries;
grant select on m916_before to authenticated;
grant select,insert,update,delete on public.brainstorm_entries to authenticated;
create policy m916_hostile on public.brainstorm_entries for all to authenticated using(true) with check(true);
set local role authenticated;
do $$declare actor0 integer; entry0 uuid; field0 text; affected0 integer; a0 uuid; w0 uuid;begin
 foreach actor0 in array array[6004,6005,6002,6009,6001,6003,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor0::text,12,'0'),true);
  select (payload->>'activity_instance_id')::uuid,(payload->>'workspace_id')::uuid into a0,w0 from bc_entries where label='R1';
  assert (select count(*) from public.brainstorm_entries where activity_instance_id=a0 and revealed_at is not null)=case when actor0 in(6005,6002) then 3 else 0 end,'Revealed pool/removed scope';
  assert not exists(select 1 from public.brainstorm_entries where activity_instance_id=a0 and revealed_at is null and created_by<>auth.uid()),'Hidden list leak';
  assert not exists(select 1 from public.brainstorm_entries b join public.activity_instances a on a.id=b.activity_instance_id where b.activity_instance_id=a0 and b.revealed_at is null and b.created_by<>auth.uid()),'Hidden join leak';
  if actor0 not in(6005,6002) then
   assert (select count(*) from public.brainstorm_entries where workspace_id=w0)=0,'Foreign/removed Workspace filter';
  end if;
  foreach entry0 in array array[(select (payload->>'id')::uuid from bc_entries where label='R1'),(select (payload->>'id')::uuid from bc_entries where label='R5'),(select (payload->>'id')::uuid from bc_entries where label='Personal'),(select (payload->>'id')::uuid from bc_entries where label='A2')] loop
   update public.brainstorm_entries set content='M9.16 unauthorized content' where id=entry0;assert not found,'Direct source edit';
   foreach field0 in array array['id','created_by','activity_instance_id','project_id','workspace_id','parent_entry_id','development_object_id'] loop
    execute format('update public.brainstorm_entries set %I=$1 where id=$2',field0) using 'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid,entry0;
    get diagnostics affected0=row_count;assert affected0=0,'Direct identity/scope/parent/Object mutation';
   end loop;
   update public.brainstorm_entries set revealed_at=clock_timestamp() where id=entry0;assert not found,'Direct reveal/replacement';
   update public.brainstorm_entries set revealed_at=null where id=entry0;assert not found,'Direct unreveal';
   update public.brainstorm_entries set revealed_at='2000-01-01' where id=entry0;assert not found,'Backdated reveal';
   update public.brainstorm_entries set status='active',archived_at=null where id=entry0;assert not found,'Direct restore';
   delete from public.brainstorm_entries where id=entry0;assert not found,'Direct history deletion';
  end loop;
  begin
   insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,created_by,updated_by,content,parent_entry_id,development_object_id,revealed_at)
   select activity_instance_id,project_id,workspace_id,created_by,created_by,'M9.16 forged entry','ffffffff-ffff-4fff-8fff-ffffffffffff','ffffffff-ffff-4fff-8fff-ffffffffffff',clock_timestamp() from m916_before limit 1;
   raise exception 'Client forged creation';
  exception when insufficient_privilege or check_violation then null;end;
 end loop;
 -- Removed creator cannot promote own historically revealed source.
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 begin perform public.promote_brainstorm_entry_to_idea((select (payload->>'id')::uuid from bc_entries where label='R1'));raise exception 'Removed IDEA promotion';exception when insufficient_privilege then null;end;
 begin perform public.promote_brainstorm_entry_to_solution((select (payload->>'id')::uuid from bc_entries where label='R1'),(select (payload->>'id')::uuid from logged_objects where label='Team'));raise exception 'Removed SOLUTION promotion';exception when insufficient_privilege then null;end;
 assert exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='Personal')),'Personal creator access lost';
end $$;
reset role;
do $$declare f regprocedure;begin
 assert not exists((select * from public.brainstorm_entries except select * from m916_before) union all (select * from m916_before except select * from public.brainstorm_entries)),'History rewritten by attacks';
 foreach f in array array['public.can_read_brainstorm_entry(uuid)'::regprocedure,'public.create_brainstorm_entry(uuid,text,text,uuid)'::regprocedure,'public.reveal_brainstorm_entries(uuid,uuid[])'::regprocedure,'public.promote_brainstorm_entry_to_idea(uuid)'::regprocedure,'public.promote_brainstorm_entry_to_solution(uuid,uuid)'::regprocedure] loop
  assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid=f),'RPC search path';
  assert has_function_privilege('authenticated',f,'EXECUTE');
  assert not has_function_privilege('anon',f,'EXECUTE') and not has_function_privilege('service_role',f,'EXECUTE');
  assert not exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) x where p.oid=f and x.grantee=0 and x.privilege_type='EXECUTE'),'PUBLIC execute';
 end loop;
 assert not has_function_privilege('authenticated','private.require_brainstorm_write(uuid)','EXECUTE');
 assert not has_function_privilege('authenticated','private.require_brainstorm_reveal(uuid)','EXECUTE');
 assert (select count(*) from pg_policy where polrelid='public.brainstorm_entries'::regclass and not polpermissive and polcmd in('a','w','d'))=3,'Mutation guards missing';
end $$;
select 'M9.16 AT-BRAIN-002 RLS pre/post reveal/exact-ID/count/join/removal/Personal/hostile mutation/grants/history PASS';
