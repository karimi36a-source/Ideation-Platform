reset role;
create temporary table prompt_rows(label text primary key,payload jsonb);
grant select,insert on prompt_rows to authenticated;
create function pg_temp.prompt_bad(statement text,expected text default '42501') returns void language plpgsql as $$begin
 execute statement;raise exception 'Prompt boundary bypass';exception when others then if sqlstate<>expected then raise;end if;end$$;
create function pg_temp.prompt_input() returns jsonb language sql as $$
 select '{"roleCode":"STRUCTURED_CREATIVITY_ASSISTANT","activityType":"scamper","systemInstruction":"FICI fixture instructions. Require human review.","taskTemplate":"Support the supplied authorized SCAMPER task.","outputSchema":{"type":"object","properties":{"response":{"type":"string"}},"required":["response"],"additionalProperties":false}}'::jsonb
$$;
-- Approved seeds need a real canonical author, never a fabricated bootstrap user.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
set local role authenticated;
do $$begin assert public.seed_ai_prompt_templates()=8;assert public.seed_ai_prompt_templates()=0;end$$;
insert into prompt_rows values('V2',public.create_ai_prompt_template(pg_temp.prompt_input()));
insert into prompt_rows values('V3',public.create_ai_prompt_template(pg_temp.prompt_input()||'{"taskTemplate":"A later safe human-reviewed template."}'));
do $$begin
 assert (select (payload->>'version')::int from prompt_rows where label='V2')=2;
 assert (select (payload->>'version')::int from prompt_rows where label='V3')=3;
 assert (select payload->>'created_by' from prompt_rows where label='V2')='00000000-0000-4000-8000-000000006001';
 assert (select payload->>'status' from prompt_rows where label='V3')='inactive';
 perform pg_temp.prompt_bad('insert into public.ai_prompt_templates default values');
 perform pg_temp.prompt_bad('update public.ai_prompt_templates set system_instruction=''forged''');
 perform pg_temp.prompt_bad('delete from public.ai_prompt_templates');
 perform pg_temp.prompt_bad('select private.resolve_active_ai_prompt_template(''STRUCTURED_CREATIVITY_ASSISTANT'',''scamper'')');
 perform pg_temp.prompt_bad('select public.create_ai_prompt_template(pg_temp.prompt_input()||''{"createdBy":"00000000-0000-4000-8000-000000006004"}'')','22023');
 perform pg_temp.prompt_bad('select public.create_ai_prompt_template(pg_temp.prompt_input()||''{"version":99}'')','22023');
 perform pg_temp.prompt_bad('select public.create_ai_prompt_template(pg_temp.prompt_input()||''{"status":"active"}'')','22023');
 perform pg_temp.prompt_bad('select public.create_ai_prompt_template(pg_temp.prompt_input()||''{"roleCode":"UNKNOWN"}'')','22P02');
 perform pg_temp.prompt_bad('select public.create_ai_prompt_template(pg_temp.prompt_input()||''{"activityType":"patent_research"}'')','23514');
 perform pg_temp.prompt_bad('select public.create_ai_prompt_template(pg_temp.prompt_input()||''{"activityType":"imaginary"}'')','22P02');
end$$;
reset role;
create temporary table prompt_original as select * from public.ai_prompt_templates where version=1;
create temporary table prompt_before as select to_jsonb(t)-'status' body from public.ai_prompt_templates t;
-- Only an exact active row resolves; creating a newer inactive version does not
-- silently switch runtime. Explicit activation changes no prior body/provenance.
do $$declare r jsonb;col text;replacement text;begin
 r:=private.resolve_active_ai_prompt_template('STRUCTURED_CREATIVITY_ASSISTANT','scamper');assert (r->>'version')::int=1;
 perform public.set_ai_prompt_template_active((select (payload->>'id')::uuid from prompt_rows where label='V2'),true);
 r:=private.resolve_active_ai_prompt_template('STRUCTURED_CREATIVITY_ASSISTANT','scamper');assert (r->>'version')::int=2;
 perform public.seed_ai_prompt_templates();assert private.resolve_active_ai_prompt_template('STRUCTURED_CREATIVITY_ASSISTANT','scamper')=r;
 perform public.set_ai_prompt_template_active((r->>'id')::uuid,false);
 perform pg_temp.prompt_bad('select private.resolve_active_ai_prompt_template(''STRUCTURED_CREATIVITY_ASSISTANT'',''scamper'')','55000');
 perform public.set_ai_prompt_template_active((r->>'id')::uuid,true);
 perform pg_temp.prompt_bad('select private.resolve_active_ai_prompt_template(''STRUCTURED_CREATIVITY_ASSISTANT'',''comparison'')','22023');
 foreach col in array array['id','role_code','activity_type','version','system_instruction','task_template','output_schema','created_by','created_at'] loop
  replacement:=case col when 'id' then 'gen_random_uuid()' when 'role_code' then '''BRAINSTORMING_FACILITATOR''' when 'activity_type' then '''brainstorming''' when 'version' then 'version+1'
   when 'system_instruction' then 'system_instruction||'' changed''' when 'task_template' then 'task_template||'' changed'''
   when 'output_schema' then 'output_schema||''{"description":"changed"}''' when 'created_by' then '''00000000-0000-4000-8000-000000006004''' else 'created_at+interval ''1 second''' end;
  perform pg_temp.prompt_bad(format('update public.ai_prompt_templates set %I=%s where id=%L',col,replacement,r->>'id'),'55000');
 end loop;
 perform pg_temp.prompt_bad(format('delete from public.ai_prompt_templates where id=%L',r->>'id'),'55000');
 perform pg_temp.prompt_bad(format('insert into public.ai_prompt_templates(role_code,activity_type,system_instruction,task_template,output_schema,created_by) values(''STRUCTURED_CREATIVITY_ASSISTANT'',''scamper'',''Safe instructions'',''Safe task'',%L,''00000000-0000-4000-8000-000000006004'')',(pg_temp.prompt_input()->'outputSchema')::text));
end$$;
-- The bounded schema rejects malformed/remote/executable configuration.
do $$declare bad jsonb;body text;begin
 for bad in select value from jsonb_array_elements('[null,[],{}, {"type":"array","items":{"type":"string"}}, {"type":"object","properties":{},"additionalProperties":true}, {"type":"object","properties":{"x":{"type":"unknown"}},"additionalProperties":false}, {"type":"object","properties":{},"required":["missing"],"additionalProperties":false}, {"type":"object","properties":{"x":{"type":"array"}},"additionalProperties":false}, {"type":"object","properties":{},"additionalProperties":false,"$ref":"https://example.test/remote"}, {"type":"object","properties":{},"additionalProperties":false,"$schema":null}, {"type":"object","properties":{"x":{"type":"integer","enum":[1.5]}},"additionalProperties":false}, {"type":"object","properties":{"x":{"type":"boolean","const":"true"}},"additionalProperties":false}, {"type":"object","properties":{"x":{"type":"string","enum":[]}},"additionalProperties":false}]'::jsonb) loop
  perform pg_temp.prompt_bad(format('select public.create_ai_prompt_template(pg_temp.prompt_input()||jsonb_build_object(''outputSchema'',%L::jsonb))',bad::text),'23514');
 end loop;
 foreach body in array array['sk-proj-FAKECREDENTIALFIXTURE000000','sb_secret_FAKECREDENTIALFIXTURE000000','-----BEGIN PRIVATE KEY----- fixture only','api_key="FAKECREDENTIALFIXTURE000000"','Bearer FAKECREDENTIALFIXTURE000000'] loop
  perform pg_temp.prompt_bad(format('select public.create_ai_prompt_template(pg_temp.prompt_input()||jsonb_build_object(''systemInstruction'',%L))',body),'23514');
 end loop;
 assert (select count(*) from public.ai_prompt_templates)=10;
 assert not exists(select 1 from public.ai_prompt_templates where private.ai_prompt_contains_credentials(system_instruction||task_template||output_schema::text));
end$$;
-- Existing AI Output provenance is never rewritten by template activation.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table prompt_ai_before as with made as (
 insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type,metadata)
 select (p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,'STRUCTURED_CREATIVITY_ASSISTANT','TEMPLATE_FIXTURE','Fixture prompt','Fixture output','SUGGESTION',
 jsonb_build_object('prompt_template_id',t.payload->>'id','prompt_template_version',2)
 from logged_projects p cross join prompt_rows t where p.label='Individual' and t.label='V2' returning *
) select to_jsonb(made) body from made;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.set_ai_prompt_template_active((select (payload->>'id')::uuid from prompt_rows where label='V3'),true);
do $$begin
 assert (private.resolve_active_ai_prompt_template('STRUCTURED_CREATIVITY_ASSISTANT','scamper')->>'version')::int=3;
 assert not exists((select body from prompt_before) except (select to_jsonb(t)-'status' from public.ai_prompt_templates t));
 assert (select body from prompt_ai_before)=(select to_jsonb(a) from public.ai_outputs a where a.id=((select body from prompt_ai_before)->>'id')::uuid);
 assert (select count(*) from prompt_original)=8;
 assert not exists(select 1 from prompt_original o where not exists(select 1 from public.ai_prompt_templates t where t.id=o.id));
end$$;
-- An ADMIN assignment to an unrelated organization is not FICI authority.
insert into public.organizations(id,name,slug,status) values('00000000-0000-4000-8000-000000094301','M14.3 other organization','m143-other','active');
insert into public.role_assignments(user_id,role_id,organization_id,status,starts_at,assigned_by)
 select '00000000-0000-4000-8000-000000006008',id,'00000000-0000-4000-8000-000000094301','active',clock_timestamp()-interval '1 day','00000000-0000-4000-8000-000000006001' from public.roles where code='ADMIN';
do $$declare u text;begin
 foreach u in array array['00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',u,true);execute 'set local role authenticated';
  perform pg_temp.prompt_bad('select public.create_ai_prompt_template(pg_temp.prompt_input())');
  perform pg_temp.prompt_bad('select public.seed_ai_prompt_templates()');
  perform pg_temp.prompt_bad(format('select public.set_ai_prompt_template_active(%L,true)',(select payload->>'id' from prompt_rows where label='V2')));
  perform pg_temp.prompt_bad('select * from public.ai_prompt_templates');
  perform pg_temp.prompt_bad('insert into public.ai_prompt_templates default values');
  perform pg_temp.prompt_bad('update public.ai_prompt_templates set status=''active''');
  perform pg_temp.prompt_bad('delete from public.ai_prompt_templates');
  perform pg_temp.prompt_bad('select private.resolve_active_ai_prompt_template(''STRUCTURED_CREATIVITY_ASSISTANT'',''scamper'')');
  execute 'reset role';
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
update public.role_assignments set status='inactive' where user_id=public.current_platform_user_id() and role_id=(select id from public.roles where code='ADMIN') and organization_id=(select id from public.organizations where slug='fici');
select pg_temp.prompt_bad('select public.create_ai_prompt_template(pg_temp.prompt_input())');
select pg_temp.prompt_bad(format('select public.set_ai_prompt_template_active(%L,false)',(select payload->>'id' from prompt_rows where label='V3')));
update public.role_assignments set status='active' where user_id=public.current_platform_user_id() and role_id=(select id from public.roles where code='ADMIN') and organization_id=(select id from public.organizations where slug='fici');
do $$begin
 assert not has_table_privilege('authenticated','public.ai_prompt_templates','SELECT,INSERT,UPDATE,DELETE');
 assert not has_function_privilege('anon','public.create_ai_prompt_template(jsonb)','EXECUTE');
 assert not has_function_privilege('authenticated','private.resolve_active_ai_prompt_template(public.ai_prompt_role_code,public.activity_method_type)','EXECUTE');
 assert (select count(*) from public.ai_prompt_templates)=10;
end$$;
-- M14.10: runtime read is service-credential only, never a student RPC.
do $$begin
 assert not has_function_privilege('authenticated','public.read_active_ai_prompt_template(public.ai_prompt_role_code,public.activity_method_type)','EXECUTE');
 assert not has_function_privilege('anon','public.read_active_ai_prompt_template(public.ai_prompt_role_code,public.activity_method_type)','EXECUTE');
 assert has_function_privilege('service_role','public.read_active_ai_prompt_template(public.ai_prompt_role_code,public.activity_method_type)','EXECUTE');
end$$;
set local role service_role;
do $$declare r jsonb;begin
 r:=public.read_active_ai_prompt_template('STRUCTURED_CREATIVITY_ASSISTANT','scamper');
 assert r->>'status'='active' and r->>'version'='3';
 assert r->>'role_code'='STRUCTURED_CREATIVITY_ASSISTANT' and r->>'activity_type'='scamper';
end$$;
reset role;
select 'M14.10 service-only exact-active-template reader/privacy PASS';
select 'AI_PROMPT_ROW='||to_jsonb(t)::text from public.ai_prompt_templates t where id=(select (payload->>'id')::uuid from prompt_rows where label='V3');
select 'M14.3 scoped-FICI-Admin/role-activity/seed/version/active-resolution/schema/immutable-history/creator-spoof/credentials/student-Master-Mentor-otherAdmin-denial/revoked-admin/AI-provenance PASS';
rollback;

