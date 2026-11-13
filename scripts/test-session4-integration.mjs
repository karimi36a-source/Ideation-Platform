import {readFileSync} from "node:fs";
import {join} from "node:path";
import {brainstormSchemaFixture} from "./brainstorm-schema-fixture.mjs";

// One committed disposable scenario; reconnects use separate PostgreSQL requests.
export function testSession4Integration({run,args,root}) {
 const name="fici_session4_acceptance";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const definitions=readFileSync(join(root,"tests/integration/session4-definitions.sql"),"utf8");
 const fixture=brainstormSchemaFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
 try {
  console.log(run("psql",[...dbArgs,"-f","-"],fixture+readFileSync(join(root,"tests/integration/session4-flow.sql"),"utf8")));
  const state=()=>run("psql",[...dbArgs,"-t","-A","-f","-"],readFileSync(join(root,"tests/integration/session4-reconnect.sql"),"utf8")).split(/\r?\n/).filter(x=>x.startsWith("M919_STATE="));
  const first=state(),second=state();
  if(first.length!==1||JSON.stringify(first)!==JSON.stringify(second))throw new Error("Session 4 reconnect changed identity/history/counts");
  console.log("M9.19 committed logout/reauthentication canonical reload/no duplicates PASS");
  console.log(run("psql",[...dbArgs,"-f","-"],readFileSync(join(root,"tests/integration/session4-security.sql"),"utf8")));
  console.log(run("psql",[...dbArgs,"-f","-"],readFileSync(join(root,"tests/integration/m9-methodology-leakage.sql"),"utf8")));
 } finally {run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
