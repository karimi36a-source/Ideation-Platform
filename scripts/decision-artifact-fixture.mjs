import {readFileSync} from "node:fs";
import {join} from "node:path";
import {votingCreationFixture} from "./voting-creation-fixture.mjs";
export function decisionArtifactFixture(root){
 // Configure the Definition BEFORE canonical start; never patch started history.
 let base=votingCreationFixture(root).replaceAll('"session_creation_authority":"scoped_master_or_team_lead"}}','"session_creation_authority":"scoped_master_or_team_lead"},"outputs":{"artifact_types":["TEAM_DECISION_RECORD","PROBLEM_BANK"]}}');
 const definitions=`
 update public.activity_definitions set requires_review=true,requires_approval=true where id='00000000-0000-4000-8000-000001020802';
 insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,configuration)
 select ('00000000-0000-4000-8000-'||lpad((1013000+n)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000950702','M10.13 configuration fixture','voting','Team Workspace',1300+n,
 case n when 1 then '{}'::jsonb when 2 then '{"outputs":{}}'::jsonb when 3 then '{"outputs":{"artifact_types":null}}'::jsonb
 when 4 then '{"outputs":{"artifact_types":"TEAM_DECISION_RECORD"}}'::jsonb when 5 then '{"outputs":{"artifact_types":["PROBLEM_BANK"]}}'::jsonb
 when 6 then '{"outputs":{"artifact_types":["TEAM_DECISION_RECORD","CUSTOM"]}}'::jsonb
 else '{"outputs":{"artifact_types":["TEAM_DECISION_RECORD"]}}'::jsonb end from generate_series(1,11) n;
 insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory)
 values('00000000-0000-4000-8000-000001013010','00000000-0000-4000-8000-000001020802','approved_output','TEAM_DECISION_RECORD',true),
 ('00000000-0000-4000-8000-000001013011','00000000-0000-4000-8000-000001020802','artifact_available','TEAM_DECISION_RECORD',true);
 `;
 base=base.replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
 return base+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0]
 +readFileSync(join(root,"tests/integration/decision-finalization-setup.sql"),"utf8")
 +readFileSync(join(root,"tests/integration/decision-artifact-setup.sql"),"utf8");
}
