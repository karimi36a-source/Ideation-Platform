import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Separate psql processes reconnect to a committed synthetic test database. */
export function testActivityResumeReconnect({run,args,root}){
 const name="fici_activity_resume_reconnect";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const setup=readFileSync(join(root,"tests/integration/activity-resume.sql"),"utf8").split("-- M7.7 TEST CASES")[0];
  run("psql",[...dbArgs,"-f","-"],setup+"\ncommit;");
  const request=()=>{
   const out=run("psql",[...dbArgs,"-t","-A","-f","-"],`begin read only;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select 'RESUMED='||public.resume_activity(id)::text from public.activity_instances where team_id is null;commit;`);
   const line=out.split(/\r?\n/).find(v=>v.startsWith("RESUMED="));
   if(!line)throw new Error("Missing persisted resume response");return JSON.parse(line.slice(8));
  };
  const before=run("psql",[...dbArgs,"-t","-A","-c","select count(*) from public.activity_instances;select count(*) from public.activity_participants;select count(*) from public.activity_inputs;select count(*) from public.activity_outputs;"]);
  const first=request(),second=request();
  if(JSON.stringify(first)!==JSON.stringify(second)||first.inputs.length!==1||first.outputs.length!==1||first.participants.length!==1)throw new Error("Reconnect changed canonical state");
  const after=run("psql",[...dbArgs,"-t","-A","-c","select count(*) from public.activity_instances;select count(*) from public.activity_participants;select count(*) from public.activity_inputs;select count(*) from public.activity_outputs;"]);
  if(before!==after)throw new Error("Resume created duplicate canonical rows");
  console.log("M7.7 committed state/separate-process reconnect/read-only transaction PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name}`]);}
}
