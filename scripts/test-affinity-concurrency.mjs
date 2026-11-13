import {spawn} from "node:child_process";
import {affinityOperationFixture} from "./affinity-operation-fixture.mjs";
export async function testAffinityConcurrency({run,args,binary,childEnv,root}){
 const name="fici_affinity_create_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const setup=run("psql",[...dbArgs,"-t","-A","-f","-"],affinityOperationFixture(root)+"select 'TARGET='||id from af_activities where label='Team';commit;");
  const id=setup.split(/\r?\n/).find(x=>x.startsWith("TARGET="))?.slice(7);
  if(!id||!/^[a-f0-9-]{36}$/.test(id))throw new Error("Missing Affinity race target");
  const call=actor=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Affinity race timeout"));},60000);
   child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Affinity race failed: "+err));const row=out.split(/\r?\n/).find(x=>x.startsWith("RESULT="));if(!row)return reject(new Error("Missing Affinity race result"));resolve(JSON.parse(row.slice(7)));});
   child.stdin.end(`begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);select 'RESULT='||public.create_affinity_group(jsonb_build_object('activityInstanceId','${id}','name','Same natural label'))::text;select pg_sleep(0.5);commit;`);
  });
  const results=await Promise.all([call('00000000-0000-4000-8000-000000006004'),call('00000000-0000-4000-8000-000000006005')]);
  if(new Set(results.map(x=>x.sequence)).size!==2||new Set(results.map(x=>x.id)).size!==2||results.some(x=>x.activity_instance_id!==id)||results.map(x=>x.sequence).sort().join()!=="1,2")throw new Error("Invalid Affinity ordering");
  const count=run("psql",[...dbArgs,"-t","-A","-c",`select count(*) from public.affinity_groups where activity_instance_id='${id}';`]).trim();
  if(count!=="2")throw new Error("Unexpected Affinity race rows");
  console.log("M11.2 independent-session two-actor create distinct sequences/no deadlock PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
