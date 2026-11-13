import {problemStormingFixture} from "./problem-storming-fixture.mjs";
export function problemBankFixture(root){
 const definitions=`
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence) values('00000000-0000-4000-8000-000000980808','00000000-0000-4000-8000-000000950702','Bank rollback fixture','problem_storming','Personal Workspace',58);
update public.activity_definitions set requires_review=true,requires_approval=true where id='00000000-0000-4000-8000-000000980802';
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence)
select ('00000000-0000-4000-8000-'||lpad((980800+n)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000950702','Bank dependency fixture','custom','Team Workspace',50+n from generate_series(6,7) n;
insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory)
values('00000000-0000-4000-8000-000000980806','00000000-0000-4000-8000-000000980802','approved_output','PROBLEM_BANK',true),
('00000000-0000-4000-8000-000000980807','00000000-0000-4000-8000-000000980802','artifact_available','PROBLEM_BANK',true);
`;
 return problemStormingFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
}
