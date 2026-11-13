begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into public.revoke_test_context values('EvidenceSource',jsonb_build_object('id',pg_temp.research_source('Evidence'))),('ObjectSource',jsonb_build_object('id',pg_temp.research_source('Gap')));
do $$declare p jsonb;s uuid;begin select payload into p from logged_projects where label='Individual';
 insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
 select id,(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,public.current_platform_user_id(),'SUBSTITUTE','Private original','Private proposed','Private result' from instances where label='Individual' returning id into s;
 insert into public.revoke_test_context values('ScamperSource',jsonb_build_object('id',s));end$$;
insert into public.revoke_test_context select 'MasterAssignment',jsonb_build_object('id',ra.id) from public.role_assignments ra join public.roles r on r.id=ra.role_id where r.code='MASTER' and ra.user_id='00000000-0000-4000-8000-000000006002' and ra.cohort_id=(select cohort_id from public.teams where id=(select (payload->>'teamId')::uuid from public.revoke_test_context where label='TeamA'));
insert into public.revoke_test_context select 'MasterShare',public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',(select payload->>'id' from public.revoke_test_context where label='MainArtifact'),'sourceVersionId',(select payload->>'id' from public.revoke_test_context where label='MainVersion'),'destinationType','MASTER','destinationId',(select payload->>'id' from public.revoke_test_context where label='MasterAssignment'),'permissionLevel','VIEW','shareMode','SNAPSHOT'));
insert into public.revoke_test_context select 'UnsharedV3',public.create_artifact_version((select (payload->>'id')::uuid from public.revoke_test_context where label='MainArtifact'),'{"notes":"Private unshared V3"}','V3');
commit;
