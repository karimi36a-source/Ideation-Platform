begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare p jsonb;s uuid;u jsonb;f jsonb;begin
 select payload into p from logged_projects where label='Team';
 insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
 select id,(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,public.current_platform_user_id(),'SUBSTITUTE','Private original','Private proposed','Private result' from instances where label='Team' returning id into s;
 insert into public.revoke_test_context values('TeamScamper',jsonb_build_object('id',s)),('TeamPatent',jsonb_build_object('id',pg_temp.research_source('Patent')));
 u:=public.request_file_upload((p->>'primary_workspace_id')::uuid,(p->>'id')::uuid,'unshared-sibling.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',u->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((u->>'id')::uuid);
 insert into public.revoke_test_context values('SiblingFile',f);
end$$;
commit;
