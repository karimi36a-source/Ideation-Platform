import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Local independent sessions prove serialization and revocation winners. */
export async function testArtifactSubmissionConcurrency({run,args,binary,childEnv,root}){
 const name="fici_artifact_submission_concurrency";const children=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const claims="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);";
 function request(sql){
  let signal;const ready=new Promise(resolve=>signal=resolve);
  const promise=new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Version race timeout"));},60000);
   child.stdout.on("data",x=>{out+=x;if(out.includes("RACE_READY"))signal();});child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);signal();reject(e);});child.on("close",code=>{clearTimeout(timer);signal();if(code===0){resolve(out);}else{reject(new Error("Version race failed: "+err));}});child.stdin.end(sql);
  });return {promise,ready};
 }
 try{

  const setup=readFileSync(join(root,"tests/integration/create-artifact.sql"),"utf8").split("-- M8.4 TEST CASES")[0];
  const out=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`\n${claims}select 'SUBMIT_FIXTURE='||jsonb_build_object('artifact',public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'PROBLEM_BANK','Submission race',(select id from instances where label='Individual'),false,false),'activity',(select id from instances where label='Individual'))::text;commit;`);
  const line=out.split(/\r?\n/).find(x=>x.startsWith("SUBMIT_FIXTURE="));if(!line)throw new Error("Missing submission fixture");const ctx=JSON.parse(line.slice(15));
  for(const id of [ctx.artifact.artifactId,ctx.artifact.initialVersionId,ctx.activity])if(!/^[a-f0-9-]{36}$/.test(id))throw new Error("Invalid fixture UUID");
  const call=`public.submit_artifact('${ctx.artifact.artifactId}','${ctx.artifact.initialVersionId}','${ctx.activity}')`;
  const first=request(`begin;${claims}select ${call};select 'RACE_READY';select pg_sleep(0.7);commit;`);await first.ready;
  // Uncommitted review entitlement must remain invisible in another auth session.
  const before=run("psql",[...dbArgs,"-t","-A","-c",`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select 'VISIBILITY='||count(*) from public.artifact_versions where id='${ctx.artifact.initialVersionId}';rollback;`]);
  if(!before.includes("VISIBILITY=0"))throw new Error("Uncommitted review entitlement leaked");
  const second=request(`begin;${claims}do $$begin begin perform ${call};raise exception 'Duplicate submission bypass';exception when unique_violation then null;end;end$$;commit;`);
  await Promise.all([first.promise,second.promise]);
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('submissions',(select count(*) from public.submissions),'submitted',(select count(*) from public.artifact_versions where status='SUBMITTED'),'active',(select count(*) from public.artifacts where status='ACTIVE'),'pointer',(select count(*) from public.artifacts where current_version_id is not null));`]).trim());
  if(stats.submissions!==1||stats.submitted!==1||stats.active!==1||stats.pointer!==0)throw new Error("Submission race state failed");
  console.log("M8.7 concurrent submit + commit visibility PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
