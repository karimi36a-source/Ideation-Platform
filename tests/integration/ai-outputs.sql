reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create temporary table ai_cases(label text primary key,row_data jsonb);
grant select on ai_cases to authenticated;
create temporary table ai_before as select (select count(*) from public.evidence) evidence_count,(select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p) projects;
create function pg_temp.ai_bad(statement text,expected text) returns void language plpgsql as $$begin
 execute statement;raise exception 'AI boundary bypass';
exception when others then if sqlstate<>expected then raise;end if;end$$;
do $$declare p record;r public.ai_outputs;k public.ai_output_type;begin
 for p in select label,payload from logged_projects where label in ('Individual','Team') loop
  foreach k in array enum_range(null::public.ai_output_type) loop
   insert into public.ai_outputs(project_id,workspace_id,activity_instance_id,ai_role,task_type,prompt_text,response_text,output_type,metadata)
   values((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(select id from instances where label=p.label),
    'CRITICAL_REVIEWER','SCHEMA_FIXTURE','Explicit fixture prompt','Generated fixture response',k,'{"prompt_template_reference":"fixture-only","model_profile_reference":"fixture-only"}') returning * into r;
   assert r.requested_by='00000000-0000-4000-8000-000000006004' and r.verification_status='UNVERIFIED' and r.disposition='KEEP_FOR_REVIEW';
   assert r.created_at is not null and r.model_provider_reference is null;
   insert into ai_cases values(p.label||'/'||k,to_jsonb(r));
  end loop;
 end loop;
end$$;
do $$declare base text;pid uuid;wid uuid;other_workspace uuid;other_activity uuid;col text;before_time timestamptz:=clock_timestamp();r public.ai_outputs;begin
 select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid into pid,wid from logged_projects where label='Team';
 select (payload->>'primary_workspace_id')::uuid into other_workspace from logged_projects where label='Individual';
 select id into other_activity from instances where label='Individual';
 base:=format('insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type) values(%L,%L,''CRITICAL_REVIEWER'',''SCHEMA_FIXTURE'',''Prompt'',''Response'',',pid,wid);
 perform pg_temp.ai_bad(base||'null)','23502');
 perform pg_temp.ai_bad(base||'''INVALID'')','22P02');
 perform pg_temp.ai_bad(format('insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type,requested_by) values(%L,%L,''role'',''task'',''prompt'',''response'',''DRAFT'',''00000000-0000-4000-8000-000000006005'')',pid,wid),'42501');
 perform pg_temp.ai_bad(format('insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type) values(%L,%L,''role'',''task'',''prompt'',''response'',''DRAFT'')',pid,other_workspace),'42501');
 perform pg_temp.ai_bad(format('insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type) values(%L,%L,''role'',''task'',''prompt'',''response'',''DRAFT'')',pid,(select (payload->>'workspaceId')::uuid from acceptance_teams where label='B')),'42501');
 perform pg_temp.ai_bad(format('insert into public.ai_outputs(project_id,workspace_id,activity_instance_id,ai_role,task_type,prompt_text,response_text,output_type) values(%L,%L,%L,''role'',''task'',''prompt'',''response'',''DRAFT'')',pid,wid,other_activity),'23514');
 perform pg_temp.ai_bad(format('insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type,verification_status) values(%L,%L,''role'',''task'',''prompt'',''response'',''DRAFT'',''VERIFIED_AGAINST_SOURCES'')',pid,wid),'23514');
 perform pg_temp.ai_bad(format('insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type,metadata) values(%L,%L,''role'',''task'',''prompt'',''response'',''DRAFT'',''{"provider":{"api_key":"fixture-secret"}}'')',pid,wid),'23514');
 perform pg_temp.ai_bad(format('insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type,metadata) values(%L,%L,''role'',''task'',''prompt'',''response'',''DRAFT'',''{"providers":[{"Authorization":"fixture-secret"}]}'')',pid,wid),'23514');
 insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type,created_at,model_provider_reference)
 values(pid,wid,'role','task','prompt','response','DRAFT','2000-01-01','external-fixture-reference') returning * into r;
 assert r.created_at>=before_time and r.id::text<>r.model_provider_reference;
 foreach col in array array['id','requested_by','project_id','workspace_id','activity_instance_id','prompt_text','response_text','ai_role','task_type','output_type','verification_status','disposition','created_at','model_provider_reference','metadata'] loop
  perform pg_temp.ai_bad(format('update public.ai_outputs set %I=%I where id=%L',col,col,r.id),'55000');
 end loop;
 perform pg_temp.ai_bad(format('delete from public.ai_outputs where id=%L',r.id),'55000');
end$$;
set local role authenticated;
do $$begin
 assert (select count(*) from public.ai_outputs)=17;
 perform pg_temp.ai_bad('insert into public.ai_outputs default values','42501');
 perform pg_temp.ai_bad('update public.ai_outputs set response_text=''forged''','42501');
 perform pg_temp.ai_bad('delete from public.ai_outputs','42501');
end$$;
reset role;
do $$declare u text;begin
 foreach u in array array['00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',u,true);
  perform pg_temp.ai_bad(format('insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type) values(%L,%L,''role'',''task'',''prompt'',''response'',''DRAFT'')',(select row_data->>'project_id' from ai_cases where label='Team/ANALYSIS'),(select row_data->>'workspace_id' from ai_cases where label='Team/ANALYSIS')),'42501');
  execute 'set local role authenticated';
  assert not exists(select 1 from public.ai_outputs),'Role/exact-ID/collection bypass';
  perform pg_temp.ai_bad('insert into public.ai_outputs default values','42501');
  execute 'reset role';
 end loop;
end$$;
-- Canonical removal, preserving requester history and denying future reads/writes.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.1 removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin assert (select count(*) from public.ai_outputs)=8;assert not exists(select 1 from public.ai_outputs where id=(select (row_data->>'id')::uuid from ai_cases where label='Team/ANALYSIS'));end$$;
reset role;
do $$begin
 assert (select count(*) from public.ai_outputs)=17;
 assert (select count(*) from public.evidence)=(select evidence_count from ai_before);
 assert (select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p)=(select projects from ai_before);
 assert not has_table_privilege('service_role','public.ai_outputs','SELECT');
 assert not has_table_privilege('anon','public.ai_outputs','SELECT');
 assert not has_table_privilege('authenticated','public.ai_outputs','INSERT,UPDATE,DELETE');
end$$;
select 'AI_OUTPUT_ROW='||row_data::text from ai_cases where label='Team/ANALYSIS';
select 'AI_OUTPUT_VOCABULARY='||jsonb_build_object('types',enum_range(null::public.ai_output_type),'verification',enum_range(null::public.ai_output_verification_status),'dispositions',enum_range(null::public.ai_output_disposition))::text;
select 'M14.1 immutable AI output/types/defaults/server-actor/Personal/Team/Activity/scope/RLS/removal/role-only/no-Evidence/no-Project-mutation PASS';
rollback;
