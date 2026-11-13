import {readFileSync} from "node:fs";
import {join} from "node:path";
import {brainstormSchemaFixture} from "./brainstorm-schema-fixture.mjs";

export function testSession5Integration({run,args,root}) {
 const name="fici_session5_acceptance";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((value,index)=>args[index-1]==="-d"?name:value);
 const read=file=>readFileSync(join(root,"tests/integration",file),"utf8");
 const definitions=read("session4-definitions.sql")+read("session5-definitions.sql");
 const fixture=brainstormSchemaFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
 try {
  console.log(run("psql",[...dbArgs,"-f","-"],fixture+read("session4-flow.sql")));
  // The Session 4 reviewer exception is not general Project access. Establish
  // the same independent Master participation fixture used by M10 voting tests.
  console.log(run("psql",[...dbArgs,"-f","-"],`begin;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
select id,'00000000-0000-4000-8000-000000006002','participant','active' from public.cohorts where id=(select cohort_id from public.teams where id=(select (payload->>'teamId')::uuid from public.m919_fixture where label='Team'));
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from public.m919_fixture where label='Team'),'00000000-0000-4000-8000-000000006002','member');
reset role;insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006002' from public.m919_fixture where label='Project';commit;`));
  console.log(run("psql",[...dbArgs,"-f","-"],read("session5-flow.sql")));
  const state=()=>run("psql",[...dbArgs,"-t","-A","-f","-"],read("session5-reconnect.sql")).split(/\r?\n/).filter(value=>value.startsWith("M1018_STATE="));
  const first=state(),second=state();
  if(first.length!==1||JSON.stringify(first)!==JSON.stringify(second))throw new Error("Session 5 reconnect changed canonical history");
  console.log(run("psql",[...dbArgs,"-f","-"],read("session5-security.sql")));
  if(JSON.stringify(first)!==JSON.stringify(state()))throw new Error("Removal changed Session 5 history or remaining-member access");
  console.log("M10.18 independent-request reload/removal/history/remaining-Team continuity PASS");
 } finally {run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
