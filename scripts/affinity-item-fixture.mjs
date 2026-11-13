import {affinityOperationFixture} from "./affinity-operation-fixture.mjs";
import {readFileSync} from "node:fs";
import {join} from "node:path";
export function affinityItemFixture(root){
 const defs=`insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,configuration) values
 ('00000000-0000-4000-8000-000001113801','00000000-0000-4000-8000-000000950702','Earlier Team Brainstorm','brainstorming','Team Workspace',103,'{"brainstorming":{"visibility_mode":"private_before_reveal","reveal_authority":"team_lead_or_scoped_master"}}'),
 ('00000000-0000-4000-8000-000001113802','00000000-0000-4000-8000-000000950702','Earlier Personal Brainstorm','brainstorming','Personal Workspace',104,'{"brainstorming":{"visibility_mode":"private_before_reveal"}}'),
 ('00000000-0000-4000-8000-000001113803','00000000-0000-4000-8000-000000950702','Other Affinity execution','affinity','Team Workspace',105,'{}'),
 ('00000000-0000-4000-8000-000001113804','00000000-0000-4000-8000-000000950702','Missing reveal authority fixture','brainstorming','Team Workspace',106,'{"brainstorming":{"visibility_mode":"private_before_reveal"}}');`;
 return affinityOperationFixture(root).replace("update public.curriculum_versions set status='approved'",defs+"update public.curriculum_versions set status='approved'")
 +readFileSync(join(root,"tests/integration/affinity-items.sql"),"utf8").split("-- Assertions")[0];
}
