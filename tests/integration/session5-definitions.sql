-- Isolated definitions configured before approval/start; production seed unchanged.
-- Retain the existing Session 5 fixture's optional review/approval flags.
update public.activity_definitions set name='Session 5 Dot Voting fixture',method_type='voting',
 configuration='{"voting":{"enabled":true,"voting_type":"DOT_VOTE","session_creation_authority":"scoped_master_only"},"outputs":{"artifact_types":["TEAM_DECISION_RECORD"]}}'
where id='00000000-0000-4000-8000-000000919803';
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence)
values('00000000-0000-4000-8000-000001018706','00000000-0000-4000-8000-000000950602',6,'Affinity Diagram','Isolated dependency fixture only','Verify canonical Session 5 output handoff',6);
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence)
values('00000000-0000-4000-8000-000001018801','00000000-0000-4000-8000-000001018706','Available output dependency fixture','custom','Team Workspace',1),
('00000000-0000-4000-8000-000001018802','00000000-0000-4000-8000-000001018706','Approved output dependency fixture','custom','Team Workspace',2);
insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory)
values('00000000-0000-4000-8000-000001018801','00000000-0000-4000-8000-000000919803','artifact_available','TEAM_DECISION_RECORD',true),
('00000000-0000-4000-8000-000001018802','00000000-0000-4000-8000-000000919803','approved_output','TEAM_DECISION_RECORD',true);
