-- Isolated curriculum fixtures only; approved course seed is never rewritten.
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence) values
('00000000-0000-4000-8000-000000919704','00000000-0000-4000-8000-000000950602',4,'Brainstorming & Problem Storming','Isolated Session 4 acceptance fixture','Expand the concept before evaluation',4),
('00000000-0000-4000-8000-000000919705','00000000-0000-4000-8000-000000950602',5,'Idea Evaluation & Voting','Isolated downstream input fixture','Validate Bank handoff only',5);
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,requires_review,requires_approval,configuration) values
('00000000-0000-4000-8000-000000919800','00000000-0000-4000-8000-000000950702','Concept preparation fixture','custom','Team Workspace',99,true,true,'{}'),
('00000000-0000-4000-8000-000000919801','00000000-0000-4000-8000-000000919704','Session 4 Problem Storming fixture','problem_storming','Team Workspace',1,true,true,'{}'),
('00000000-0000-4000-8000-000000919802','00000000-0000-4000-8000-000000919704','Session 4 Solutions fixture','brainstorming','Team Workspace',2,true,true,'{"brainstorming":{"visibility_mode":"private_before_reveal","reveal_authority":"team_lead_or_scoped_master"}}'),
('00000000-0000-4000-8000-000000919803','00000000-0000-4000-8000-000000919705','Session 5 input-only fixture','custom','Team Workspace',1,false,false,'{}');
insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory) values
('00000000-0000-4000-8000-000000919803','00000000-0000-4000-8000-000000919801','approved_output','PROBLEM_BANK',true),
('00000000-0000-4000-8000-000000919803','00000000-0000-4000-8000-000000919802','approved_output','SOLUTION_BANK',true);

insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence) values('00000000-0000-4000-8000-000000919804','00000000-0000-4000-8000-000000919705','Bank availability-only fixture','custom','Team Workspace',2);
insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory) select '00000000-0000-4000-8000-000000919804',required_activity_definition_id,'artifact_available',required_artifact_type,true from public.activity_dependencies where activity_definition_id='00000000-0000-4000-8000-000000919803';
