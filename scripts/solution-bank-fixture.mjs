import {solutionPromotionFixture} from "./solution-promotion-fixture.mjs";
export function solutionBankFixture(root){
 const definitions=`
update public.activity_definitions set requires_review=true,requires_approval=true where id='00000000-0000-4000-8000-000000970801';
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence)
select ('00000000-0000-4000-8000-'||lpad((991800+n)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000950702','Solution Bank dependency fixture','custom','Team Workspace',70+n from generate_series(6,7)n;
insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory)
values('00000000-0000-4000-8000-000000991806','00000000-0000-4000-8000-000000970801','approved_output','SOLUTION_BANK',true),
('00000000-0000-4000-8000-000000991807','00000000-0000-4000-8000-000000970801','artifact_available','SOLUTION_BANK',true);
`;
 return solutionPromotionFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
}
