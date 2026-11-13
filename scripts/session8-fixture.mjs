import {activityArtifactFixture} from './activity-artifact-fixture.mjs';
/** Isolated approved Session 8/9 context; production curriculum is untouched. */
export function session8Fixture(root){
 const setup=`
 insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence,status) values
 ('00000000-0000-4000-8000-000001226708','00000000-0000-4000-8000-000000740602',8,'Patent Document & Reading Basics','Isolated Session 8 acceptance','Read source patents',8,'active'),
 ('00000000-0000-4000-8000-000001226709','00000000-0000-4000-8000-000000740602',9,'Framework handoff context','Session 9 input resolution only','Reuse canonical framework',9,'active');
 insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,status,configuration) values
 ('00000000-0000-4000-8000-000001226808','00000000-0000-4000-8000-000001226708','Structured Patent Reading','patent_research','Team Workspace',1,'active','{"outputs":{"artifact_types":["PATENT_READING_FRAMEWORK"]}}'),
 ('00000000-0000-4000-8000-000001226809','00000000-0000-4000-8000-000001226709','Framework consumer','patent_research','Team Workspace',1,'active','{}'),
 ('00000000-0000-4000-8000-000001226810','00000000-0000-4000-8000-000001226708','Personal Patent Reading','patent_research','Personal Workspace',2,'active','{}');
 insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory) values
 ('00000000-0000-4000-8000-000001226808','00000000-0000-4000-8000-000000740801','artifact_available','INVENTION_CONCEPT',true),
 ('00000000-0000-4000-8000-000001226809','00000000-0000-4000-8000-000001226808','artifact_available','PATENT_READING_FRAMEWORK',true);
 `;
 return activityArtifactFixture(root).replace("update public.curriculum_versions set status='approved'",setup+"\nupdate public.curriculum_versions set status='approved'");
}
