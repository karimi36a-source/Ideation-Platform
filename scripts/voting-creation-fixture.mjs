import {readFileSync} from "node:fs";
import {join} from "node:path";
import {brainstormRevealFixture} from "./brainstorm-reveal-fixture.mjs";
export function votingCreationFixture(root){
 const defs=`
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,configuration)
select ('00000000-0000-4000-8000-'||lpad((1020800+n)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000950702','M10.2 isolated voting','voting','Team Workspace',100+n,
case when n=1 then '{"voting":{"enabled":true,"voting_type":"DOT_VOTE","session_creation_authority":"scoped_master_only"}}'::jsonb
when n=2 then '{"voting":{"enabled":true,"voting_type":"DOT_VOTE","session_creation_authority":"scoped_master_or_team_lead"}}'::jsonb
when n=3 then '{}'::jsonb
when n=4 then '{"voting":{"enabled":true,"voting_type":"DOT_VOTE","session_creation_authority":"everyone"}}'::jsonb
when n=5 then '{"voting":{"enabled":true,"voting_type":"FIST_TO_FIVE","session_creation_authority":"scoped_master_only"}}'::jsonb
else '{"voting":{"enabled":false,"voting_type":"DOT_VOTE","session_creation_authority":"scoped_master_only"}}'::jsonb end
from generate_series(1,6) n;
`;
 const base=brainstormRevealFixture(root).replace("update public.curriculum_versions set status='approved'",defs+"update public.curriculum_versions set status='approved'");
 return base+readFileSync(join(root,"tests/integration/brainstorm-create.sql"),"utf8").split("-- A trusted own revealed fixture")[0]
 +readFileSync(join(root,"tests/integration/brainstorm-reveal.sql"),"utf8").split("-- Assertions use trusted fixture IDs")[0];
}
