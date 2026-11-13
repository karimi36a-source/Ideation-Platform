-- Appended to canonical M9.6 creation fixture before removal. All identities are disposable.
set local role authenticated;
do $$declare actor integer; own_id uuid; hidden_id uuid; a uuid; w uuid; actual jsonb; absent jsonb; err text; missing_err text;begin
 foreach actor in array array[6004,6005] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor::text,12,'0'),true);
 select (payload->>'id')::uuid into own_id from bc_entries where label=case actor when 6004 then 'A1' else 'A2' end;
 select (payload->>'id')::uuid into hidden_id from bc_entries where label=case actor when 6004 then 'A2' else 'A1' end;
 select (payload->>'activity_instance_id')::uuid,(payload->>'workspace_id')::uuid into a,w from bc_entries where label='A1';
 assert exists(select 1 from public.brainstorm_entries where id=own_id and revealed_at is null and status='active');
 assert public.resume_activity(a) is not null and public.resume_activity(a)=public.resume_activity(a),'Resume lost canonical Activity';
 select coalesce(jsonb_agg(to_jsonb(b)),'[]') into actual from public.brainstorm_entries b where id=hidden_id;
 select coalesce(jsonb_agg(to_jsonb(b)),'[]') into absent from public.brainstorm_entries b where id='ffffffff-ffff-4fff-8fff-ffffffffffff';
 assert actual=absent and actual='[]'::jsonb,'Exact ID existence oracle';
 assert not exists(select 1 from public.brainstorm_entries where created_by<>auth.uid()),'Unfiltered enumeration';
 assert not exists(select 1 from public.brainstorm_entries where activity_instance_id=a and created_by<>auth.uid()),'Activity enumeration';
 assert not exists(select 1 from public.brainstorm_entries where workspace_id=w and created_by<>auth.uid()),'Workspace enumeration';
 assert (select count(*) from public.brainstorm_entries where id=hidden_id)=0,'Hidden count';
 assert (select count(*) from public.brainstorm_entries where created_by=case actor when 6004 then '00000000-0000-4000-8000-000000006005'::uuid else '00000000-0000-4000-8000-000000006004'::uuid end)=0,'Creator filter';
 begin perform public.create_brainstorm_entry(a,'Peer parent attack','private',hidden_id);raise exception 'Peer parent accepted';exception when insufficient_privilege then get stacked diagnostics err=message_text;end;
 begin perform public.create_brainstorm_entry(a,'Absent parent attack','private','ffffffff-ffff-4fff-8fff-ffffffffffff');raise exception 'Absent parent accepted';exception when insufficient_privilege then get stacked diagnostics missing_err=message_text;end;
 assert err=missing_err and err='Resource unavailable';
 begin update public.brainstorm_entries set content='Peer overwrite' where id=hidden_id;raise exception 'Peer update';exception when insufficient_privilege then null;end;
 begin update public.brainstorm_entries set revealed_at=clock_timestamp() where id=own_id;raise exception 'Reveal spoof';exception when insufficient_privilege then null;end;
 begin delete from public.brainstorm_entries where id=hidden_id;raise exception 'Peer delete';exception when insufficient_privilege then null;end;
 end loop;
 -- Same-cohort Team B, operational roles and contextual Mentor have no creator override.
 foreach actor in array array[6001,6002,6003,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor::text,12,'0'),true);
 assert not exists(select 1 from public.brainstorm_entries where id in(select (payload->>'id')::uuid from bc_entries where label in('A1','A2','Personal'))),'Role/Team/Personal bypass';
 assert not exists(select 1 from public.brainstorm_entries where activity_instance_id=a),'Team list bypass';
 end loop;
 -- Real Team B actor attempts a Team A parent in their own authorized Activity.
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
 begin perform public.create_brainstorm_entry((select (payload->>'activity_instance_id')::uuid from bc_entries where label='Team B'),'Team B parent attack','private',own_id);raise exception 'Team B parent';exception when insufficient_privilege then assert sqlerrm='Resource unavailable';end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
update public.brainstorm_entries set status='archived',archived_at=clock_timestamp() where id=(select (payload->>'id')::uuid from bc_entries where label='Child');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert not exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='Child')),'Archive leaked';end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.brainstorm_entries where activity_instance_id=(select (payload->>'activity_instance_id')::uuid from bc_entries where label='A1')),'Removed list bypass';
 assert not exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='A1')),'Removed exact bypass';
 assert public.resume_activity((select (payload->>'activity_instance_id')::uuid from bc_entries where label='A1')) is null,'Removed resume bypass';
 begin perform public.create_brainstorm_entry((select (payload->>'activity_instance_id')::uuid from bc_entries where label='A1'),'Removed parent attack','private',(select (payload->>'id')::uuid from bc_entries where label='A1'));raise exception 'Removed parent';exception when insufficient_privilege then null;end;
 assert exists(select 1 from public.brainstorm_entries where id=(select (payload->>'id')::uuid from bc_entries where label='Personal')),'Personal owner revoked';
end $$;
reset role;
do $$begin
 assert not exists(select 1 from pg_publication_tables where schemaname='public' and tablename='brainstorm_entries'),'Brainstorm realtime publication';
 assert not exists(select 1 from pg_trigger where tgrelid='public.brainstorm_entries'::regclass and not tgisinternal and tgfoid in(select oid from pg_proc where proname ilike '%broadcast%' or proname ilike '%realtime%')),'Brainstorm broadcast trigger';
 assert (select relrowsecurity from pg_class where oid='public.brainstorm_entries'::regclass);
 assert not has_table_privilege('authenticated','public.brainstorm_entries','UPDATE');
 assert not has_table_privilege('authenticated','public.brainstorm_entries','INSERT');
 assert not has_table_privilege('authenticated','public.brainstorm_entries','DELETE');
 assert not has_function_privilege('service_role','public.create_brainstorm_entry(uuid,text,text,uuid)','EXECUTE');
 assert not has_function_privilege('authenticated','private.require_brainstorm_write(uuid)','EXECUTE');
 assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.create_brainstorm_entry(uuid,text,text,uuid)'::regprocedure);
 assert (select count(*) from public.brainstorm_entries where id in(select (payload->>'id')::uuid from bc_entries where label in('A1','A2','Personal')))=3,'History lost';
 assert not exists(select 1 from public.brainstorm_entries where content in('Peer overwrite','Peer parent attack','Team B parent attack','Removed parent attack'));
end $$;
select 'AT-BRAIN-002 PASS: creator-only queries / enumeration / parent / mutation / removal / Personal';
select 'Realtime/subscription attack surface: NOT PRESENT';
rollback;
