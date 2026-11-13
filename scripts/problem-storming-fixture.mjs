import {brainstormSchemaFixture} from "./brainstorm-schema-fixture.mjs";
export function problemStormingFixture(root){
 const definitions=`
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence) values('00000000-0000-4000-8000-000000980704','00000000-0000-4000-8000-000000950602',4,'Isolated Session 4','Test fixture','Test fixture',4);
-- Generic definitions explicitly have no required Concept dependency/input.
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence)
select ('00000000-0000-4000-8000-'||lpad((980800+n)::text,12,'0'))::uuid,
case when n in(3,4) then '00000000-0000-4000-8000-000000980704'::uuid else '00000000-0000-4000-8000-000000950702'::uuid end,
'Isolated Problem Storming',case when n=5 then 'custom'::public.activity_method_type else 'problem_storming'::public.activity_method_type end,
case when n in(1,4) then 'Personal Workspace' else 'Team Workspace' end,50+n from generate_series(1,5) n;
`;
 return brainstormSchemaFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
}
