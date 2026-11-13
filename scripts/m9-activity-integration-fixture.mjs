import {brainstormSchemaFixture} from "./brainstorm-schema-fixture.mjs";
export function m9ActivityIntegrationFixture(root){
 const definitions=`
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,configuration)
select ('00000000-0000-4000-8000-'||lpad((914800+n)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000950702','M9.14 integration fixture',
case when n in(1,2,3,7) then 'scamper'::public.activity_method_type else 'brainstorming'::public.activity_method_type end,
case when n<=6 then 'Personal Workspace' else 'Team Workspace' end,80+n,
(case when n in(1,2,3,7) then '{}'::jsonb else '{"brainstorming":{"visibility_mode":"private_before_reveal","reveal_authority":"team_lead_or_scoped_master"}}'::jsonb end)||
case when n in(1,4) then '{}'::jsonb when n in(2,5) then '{"output_registration":{"promoted_ideas":false}}'::jsonb else '{"output_registration":{"promoted_ideas":true}}'::jsonb end
from generate_series(1,8) n;
`;
 return brainstormSchemaFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
}
