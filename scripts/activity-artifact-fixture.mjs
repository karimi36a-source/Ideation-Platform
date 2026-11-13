import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Isolated curriculum only; production seed and approved Definitions unchanged. */
export function activityArtifactFixture(root){
 let prefix=readFileSync(join(root,"tests/integration/activity-output-handoff-acceptance.sql"),"utf8").split("-- AT-ACT-004 generic foundation")[0];
 const sessions=` insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence,status) values
 ('00000000-0000-4000-8000-000000814704','00000000-0000-4000-8000-000000740602',4,'Session 4 test context','Isolated test only','Output reuse test',4,'active'),
 ('00000000-0000-4000-8000-000000814705','00000000-0000-4000-8000-000000740602',5,'Session 5 test context','Isolated test only','Output reuse test',5,'active');
`;
 prefix=prefix.replace("insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,status)",sessions+"insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,status)");
 prefix=prefix.replace("::uuid,'00000000-0000-4000-8000-000000740702','Isolated availability '", "::uuid,case when n=1 then '00000000-0000-4000-8000-000000814704'::uuid when n=3 then '00000000-0000-4000-8000-000000814705'::uuid else '00000000-0000-4000-8000-000000740702'::uuid end,'Isolated availability '");
 const addition=`
 update public.activity_dependencies set required_artifact_type='PROBLEM_BANK' where activity_definition_id in ('00000000-0000-4000-8000-000000740803','00000000-0000-4000-8000-000000750805');
 insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,status)
 values('00000000-0000-4000-8000-000000814802','00000000-0000-4000-8000-000000740702','Personal downstream fixture','custom','Personal Workspace',98,'active');
 insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory)
 values('00000000-0000-4000-8000-000000814802','00000000-0000-4000-8000-000000740806','artifact_available',true);
 `;
 return prefix.replace("update public.curriculum_versions set status='approved'",addition+"\nupdate public.curriculum_versions set status='approved'");
}
