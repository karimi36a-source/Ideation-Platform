import {brainstormCreateFixture} from "./brainstorm-create-fixture.mjs";
export function brainstormRevealFixture(root){
 const definitions=`
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,configuration)
select ('00000000-0000-4000-8000-'||lpad((970800+n)::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000950702','M9.8 test only','brainstorming',
case when n=4 then 'Personal Workspace' else 'Team Workspace' end,30+n,
case when n in (1,4,5) then '{"brainstorming":{"visibility_mode":"private_before_reveal","reveal_authority":"team_lead_or_scoped_master"}}'::jsonb
when n=2 then '{"brainstorming":{"visibility_mode":"private_before_reveal"}}'::jsonb
else '{"brainstorming":{"visibility_mode":"private_before_reveal","reveal_authority":"everyone"}}'::jsonb end
from generate_series(1,5) n;
`;
 return brainstormCreateFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
}
