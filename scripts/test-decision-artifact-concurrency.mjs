import {spawn} from "node:child_process";
import {decisionArtifactFixture} from "./decision-artifact-fixture.mjs";
export async function testDecisionArtifactConcurrency({run,args,binary,childEnv,root}){
 const name="fici_decision_artifact_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const setup=run("psql",[...dbArgs,"-t","-A","-f","-"],decisionArtifactFixture(root)+"select 'DA_ID='||pg_temp.da_id('Same race')::text;commit;");
  const id=setup.split(/\r?\n/).find(x=>x.startsWith("DA_ID="))?.slice(6);
  if(!id||! /^[a-f0-9-]{36}$/.test(id))throw new Error("Missing valid Decision race fixture");
  const call=actor=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Decision Artifact race timeout"));},60000);
   child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Decision Artifact worker failed: "+err));const line=out.split(/\r?\n/).find(x=>x.startsWith("DA_RESULT="));if(!line)return reject(new Error("Missing canonical race result"));resolve(JSON.parse(line.slice(10)));});
   child.stdin.end(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);select 'DA_RESULT='||public.create_team_decision_record_artifact('${id}')::text;select pg_sleep(0.5);commit;`);
  });
  const results=await Promise.all([call("00000000-0000-4000-8000-000000006009"),call("00000000-0000-4000-8000-000000006002")]);
  if(JSON.stringify(results[0])!==JSON.stringify(results[1]))throw new Error("Concurrent compositions diverged");
  const counts=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('artifacts',(select count(*) from public.artifacts where artifact_type='TEAM_DECISION_RECORD'),'versions',(select count(*) from public.artifact_versions v join public.artifacts a on a.id=v.artifact_id where a.artifact_type='TEAM_DECISION_RECORD'),'sources',(select count(*) from public.artifact_decision_sources),'links',(select count(*) from public.artifact_object_links l join public.artifacts a on a.id=l.artifact_id where a.artifact_type='TEAM_DECISION_RECORD'),'outputs',(select count(*) from public.activity_outputs o join public.artifacts a on a.id=o.artifact_id where a.artifact_type='TEAM_DECISION_RECORD'),'events',(select count(*) from public.audit_events where event_type='TEAM_DECISION_RECORD_COMPOSED'));`]).trim());
  if(Object.values(counts).some(x=>x!==1))throw new Error("Concurrency duplicated composition rows or side effects");
  console.log("M10.13 independent-session Lead/Master composition convergence PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
