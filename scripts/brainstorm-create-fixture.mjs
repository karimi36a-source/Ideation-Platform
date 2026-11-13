import {brainstormSchemaFixture} from "./brainstorm-schema-fixture.mjs";
export function brainstormCreateFixture(root){
 const definitions=`
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,configuration)
select ('00000000-0000-4000-8000-'||lpad((960800+n)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000950702','M9.6 test only',
case when n=5 then 'custom'::public.activity_method_type else 'brainstorming'::public.activity_method_type end,
case when n=1 then 'Personal Workspace' else 'Team Workspace' end,10+n,
case when n in (1,2,5) then '{"brainstorming":{"visibility_mode":"private_before_reveal"}}'::jsonb
when n=3 then '{}'::jsonb when n=4 then '{"brainstorming":{"visibility_mode":"shared"}}'::jsonb
when n=6 then '{"brainstorming":{}}'::jsonb else '{"brainstorming":"private_before_reveal"}'::jsonb end
from generate_series(1,7) n;
`;
 return brainstormSchemaFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
}
