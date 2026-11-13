import {artifactReviewSecurityFixture} from "./artifact-review-security-fixture.mjs";
// Isolated curriculum only; never modify approved Professional Course seed.
export function brainstormSchemaFixture(root){
 const setup=`
insert into public.curriculum_versions(id,program_id,version_label) values('00000000-0000-4000-8000-000000950602','00000000-0000-4000-8000-000000000601','M9.5 isolated fixture');
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence) values('00000000-0000-4000-8000-000000950702','00000000-0000-4000-8000-000000950602',1,'Test only','Isolated fixture','Isolated fixture',1);
insert into public.activity_definitions(id,session_definition_id,name,method_type,sequence) values
('00000000-0000-4000-8000-000000950801','00000000-0000-4000-8000-000000950702','Fixture','brainstorming',1),
('00000000-0000-4000-8000-000000950802','00000000-0000-4000-8000-000000950702','Brainstorming misleading name','custom',2);
update public.curriculum_versions set status='approved' where id='00000000-0000-4000-8000-000000950602';
`;
 return artifactReviewSecurityFixture(root).replaceAll('00000000-0000-4000-8000-000000000602','00000000-0000-4000-8000-000000950602').replaceAll('00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000950801').replace('begin;','begin;'+setup);
}
