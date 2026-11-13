import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {problemBankFixture} from "./problem-bank-fixture.mjs";
export async function testProblemBankConcurrency({run,args,binary,childEnv,root}){
 const name="fici_problem_bank_race",children=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const claims="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);";
 function request(sql){let signal;const ready=new Promise(resolve=>signal=resolve);
  const promise=new Promise((resolve,reject)=>{const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Problem Bank race timeout"));},60000);
   child.stdout.on("data",x=>{out+=x;if(out.includes("RACE_READY"))signal();});child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);signal();reject(e);});child.on("close",code=>{clearTimeout(timer);signal();if(code===0)resolve(out);else reject(new Error("Bank race failed: "+err));});child.stdin.end(sql);
  });return {promise,ready};
 }
 try{
  const setup=run("psql",[...dbArgs,"-t","-A","-f","-"],problemBankFixture(root)+readFileSync(join(root,"tests/integration/problem-bank-setup.sql"),"utf8")+`select 'BANK_CONTEXT='||json_build_object('activity',pg_temp.pb_activity('Personal'),'problems',pg_temp.pb_ids('P'))::text;commit;`);
  const context=JSON.parse(setup.split(/\r?\n/).find(x=>x.startsWith("BANK_CONTEXT=")).slice(13));
  if(![context.activity,...context.problems].every(x=>/^[a-f0-9-]{36}$/.test(x)))throw new Error("Invalid Bank fixture");
  const call=`public.compose_problem_bank('${context.activity}',array[${context.problems.map(x=>`'${x}'::uuid`).join(",")}])`;
  const first=request(`begin;${claims}select 'BANK_RESULT='||${call}::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);await first.ready;
  const second=request(`begin;${claims}select 'BANK_RESULT='||${call}::text;commit;`);
  const results=await Promise.all([first.promise,second.promise]);
  const banks=results.map(out=>JSON.parse(out.split(/\r?\n/).find(x=>x.startsWith("BANK_RESULT=")).slice(12)));
  if(banks[0].artifact.id!==banks[1].artifact.id||banks[0].version.version_number!==1||banks[1].version.version_number!==2||banks[1].version.previous_version_id!==banks[0].version.id)throw new Error("Concurrent Bank identity/lineage mismatch");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('artifacts',(select count(*) from public.artifacts where activity_instance_id='${context.activity}' and artifact_type='PROBLEM_BANK'),'versions',(select count(*) from public.artifact_versions where artifact_id='${banks[0].artifact.id}'),'links',(select count(*) from public.artifact_object_links where artifact_id='${banks[0].artifact.id}'),'outputs',(select count(*) from public.activity_outputs where artifact_id='${banks[0].artifact.id}'),'audit',(select count(*) from public.audit_events where entity_id='${banks[0].artifact.id}' and event_type='PROBLEM_BANK_COMPOSED'));`]).trim());
  if(stats.artifacts!==1||stats.versions!==2||stats.links!==6||stats.outputs!==1||stats.audit!==2)throw new Error("Bank race counts mismatch");
  console.log("M9.11 independent-session Bank concurrency one Artifact/two Versions/ordered lineage/one output PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
