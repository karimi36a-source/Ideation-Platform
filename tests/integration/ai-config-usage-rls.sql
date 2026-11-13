-- M14.23: canonical M14.3/M14.4 fixtures precede this rolled-back matrix.
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into usage_cases(label,input) values('Peer',pg_temp.usage_input());
update usage_cases set payload=private.record_ai_usage_event(input) where label='Peer';
create temporary table config_usage_before as select
 (select jsonb_agg(to_jsonb(t) order by id) from public.ai_prompt_templates t) templates,
 (select jsonb_agg(to_jsonb(e) order by id) from public.ai_usage_events e) usage;
grant select on config_usage_before to authenticated;
-- A current Team Lead may read their own event, never another user's details.
set local role authenticated;
do $$begin
 assert public.can_read_development_project((select (payload->>'id')::uuid from logged_projects where label='Team'));
 assert (select count(*) from public.ai_usage_events)=1;
 assert exists(select 1 from public.ai_usage_events where id=(select (payload->>'id')::uuid from usage_cases where label='Peer'));
 assert not exists(select 1 from public.ai_usage_events where id in(select (payload->>'id')::uuid from usage_cases where label in ('TeamSuccess','TeamFailure','PersonalSuccess')));
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_usage_events)=4;
 assert not exists(select 1 from public.ai_usage_events where id=(select (payload->>'id')::uuid from usage_cases where label='Peer'));
end$$;
reset role;
-- Exact template IDs cannot expose instructions/admin metadata, even to a
-- scoped Admin using a normal authenticated connection. Admin RPCs remain valid.
do $$declare actor0 text;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);execute 'set local role authenticated';
  perform pg_temp.prompt_bad(format('select * from public.ai_prompt_templates where id=%L',(select payload->>'id' from prompt_rows where label='V2')));
  perform pg_temp.prompt_bad('select * from public.ai_prompt_templates where id=''ffffffff-ffff-4fff-8fff-ffffffffffff''');
  perform pg_temp.prompt_bad('select public.read_active_ai_prompt_template(''STRUCTURED_CREATIVITY_ASSISTANT'',''scamper'')');
  perform pg_temp.usage_bad('insert into public.ai_usage_events default values');
  perform pg_temp.usage_bad('update public.ai_usage_events set success_failure=''SUCCESS''');
  perform pg_temp.usage_bad('delete from public.ai_usage_events');
  if actor0 not in ('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005') then
   assert not exists(select 1 from public.ai_usage_events);
   assert not exists(select 1 from public.ai_usage_events where id in(select (payload->>'id')::uuid from usage_cases));
  end if;
  assert not exists(select 1 from public.ai_usage_events where id='ffffffff-ffff-4fff-8fff-ffffffffffff');
  execute 'reset role';
 end loop;
end$$;
-- Temporary grants prove RLS itself, independently of the real denied grants.
-- These grants are revoked below and the entire fixture rolls back.
grant select,insert,update,delete on public.ai_prompt_templates to authenticated;
grant insert,update,delete on public.ai_usage_events to authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$declare col text;n bigint;begin
 assert not exists(select 1 from public.ai_prompt_templates),'Default-deny template read bypass';
 foreach col in array array['id','role_code','activity_type','version','system_instruction','task_template','output_schema','status','created_by','created_at'] loop
  execute format('update public.ai_prompt_templates set %I=%I',col,col);get diagnostics n=row_count;assert n=0,'Template RLS update bypass';
 end loop;
 update public.ai_prompt_templates set status='active';get diagnostics n=row_count;assert n=0;
 delete from public.ai_prompt_templates;get diagnostics n=row_count;assert n=0;
 perform pg_temp.prompt_bad('insert into public.ai_prompt_templates default values');
 foreach col in array array['id','user_id','project_id','workspace_id','activity_instance_id','task_type','model_profile','input_usage','output_usage','estimated_cost','latency_ms','success_failure','created_at'] loop
  execute format('update public.ai_usage_events set %I=%I',col,col);get diagnostics n=row_count;assert n=0,'Usage RLS update bypass';
 end loop;
 update public.ai_usage_events set user_id='00000000-0000-4000-8000-000000006005',input_usage=999,success_failure='SUCCESS';get diagnostics n=row_count;assert n=0;
 delete from public.ai_usage_events;get diagnostics n=row_count;assert n=0;
 perform pg_temp.usage_bad(format('insert into public.ai_usage_events(project_id,workspace_id,task_type,model_profile,latency_ms,success_failure) values(%L,%L,''FORGED_ATTEMPT'',''AI_STANDARD'',0,''SUCCESS'')',(select payload->>'project_id' from usage_cases where label='TeamSuccess'),(select payload->>'workspace_id' from usage_cases where label='TeamSuccess')));
end$$;
reset role;
revoke select,insert,update,delete on public.ai_prompt_templates from authenticated;
revoke insert,update,delete on public.ai_usage_events from authenticated;
do $$begin
 assert (select templates from config_usage_before)=(select jsonb_agg(to_jsonb(t) order by id) from public.ai_prompt_templates t);
 assert (select usage from config_usage_before)=(select jsonb_agg(to_jsonb(e) order by id) from public.ai_usage_events e);
 assert (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='ai_usage_events')=
 array['id','user_id','project_id','workspace_id','activity_instance_id','task_type','model_profile','input_usage','output_usage','estimated_cost','latency_ms','success_failure','created_at'];
end$$;
-- Only the server credential reads the canonical active template; inactive V3
-- cannot be selected by an ID override because no such runtime input exists.
set local role service_role;
do $$declare t jsonb;begin
 t:=public.read_active_ai_prompt_template('STRUCTURED_CREATIVITY_ASSISTANT','scamper');
 assert t->>'version'='2' and t->>'status'='active';
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.23 removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_usage_events)=1;
 assert exists(select 1 from public.ai_usage_events where id=(select (payload->>'id')::uuid from usage_cases where label='PersonalSuccess'));
 assert not exists(select 1 from public.ai_usage_events where id in(select (payload->>'id')::uuid from usage_cases where label in ('TeamSuccess','TeamFailure','ServerTimestamp','Peer')));
end$$;
reset role;
do $$begin
 assert (select templates from config_usage_before)=(select jsonb_agg(to_jsonb(t) order by id) from public.ai_prompt_templates t);
 assert (select usage from config_usage_before)=(select jsonb_agg(to_jsonb(e) order by id) from public.ai_usage_events e);
 assert not has_table_privilege('authenticated','public.ai_prompt_templates','SELECT,INSERT,UPDATE,DELETE');
 assert not has_table_privilege('authenticated','public.ai_usage_events','INSERT,UPDATE,DELETE');
 assert not has_table_privilege('anon','public.ai_usage_events','SELECT');
 assert not has_function_privilege('authenticated','private.record_ai_usage_event(jsonb)','EXECUTE');
 assert not has_function_privilege('authenticated','public.read_active_ai_prompt_template(public.ai_prompt_role_code,public.activity_method_type)','EXECUTE');
end$$;
select 'M14.23 configuration/usage RLS server-only-template/self-only-current-scope/direct-ID/no-client-mutation/history/minimization PASS';
rollback;
