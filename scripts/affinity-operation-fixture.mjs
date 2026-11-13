import {brainstormSchemaFixture} from "./brainstorm-schema-fixture.mjs";
import {readFileSync} from "node:fs";
import {join} from "node:path";
export function affinityOperationFixture(root){
 const definitions=`insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence)
 values('00000000-0000-4000-8000-000001112801','00000000-0000-4000-8000-000000950702','Isolated Affinity Team','affinity','Team Workspace',101),
 ('00000000-0000-4000-8000-000001112802','00000000-0000-4000-8000-000000950702','Isolated Affinity Personal','affinity','Personal Workspace',102);`;
 return brainstormSchemaFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'")
 +readFileSync(join(root,"tests/integration/affinity-operations.sql"),"utf8").split("-- Assertions")[0];
}
