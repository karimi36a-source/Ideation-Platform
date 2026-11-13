import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Local independent sessions prove serialization and revocation winners. */
export async function testArtifactRevisionConcurrency({run,args,binary,childEnv,root}){
 const name="fici_artifact_revision_concurrency";const children=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);

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


  const setup=readFileSync(join(root,"tests/integration/start-review-feedback.sql"),"utf8").split('create temporary table review_before')[0];
  const out=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`\nselect 'REVIEW_FIXTURE='||jsonb_build_object('submission',(select payload->>'id' from review_fixtures where label='Personal'),'artifact',(select payload->>'artifactId' from submitted_fixtures where label='Personal'),'version',(select payload->>'initialVersionId' from submitted_fixtures where label='Personal'),'cohort',(select id from acceptance_cohorts where label='Test'))::text;commit;`);
  const line=out.split(/\r?\n/).find(x=>x.startsWith("REVIEW_FIXTURE="));if(!line)throw new Error("Missing review fixture");const ctx=JSON.parse(line.slice(15));
  for(const id of Object.values(ctx))if(!/^[a-f0-9-]{36}$/.test(id))throw new Error("Invalid fixture UUID");
  const reviewer="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);";
  const call=`public.start_review('${ctx.submission}')`;
  const first=request(`begin;${reviewer}select 'REVIEW_RESULT='||${call}::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);await first.ready;
  const second=request(`begin;${reviewer}select 'REVIEW_RESULT='||${call}::text;commit;`);
  const outputs=await Promise.all([first.promise,second.promise]);
  const rows=outputs.map(out=>JSON.parse(out.split(/\r?\n/).find(x=>x.startsWith('REVIEW_RESULT=')).slice(14)));
  if(JSON.stringify(rows[0])!==JSON.stringify(rows[1])||rows[0].status!=="UNDER_REVIEW")throw new Error("Canonical review retry mismatch");
  const comment=`public.request_revision('${ctx.submission}','Concurrent revision')`;
  const revisionFirst=request(`begin;${reviewer}select 'REVISION_RESULT='||${comment}::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);await revisionFirst.ready;
  const revisionSecond=request(`begin;${reviewer}select 'REVISION_RESULT='||${comment}::text;commit;`);
  const revisionOutputs=await Promise.all([revisionFirst.promise,revisionSecond.promise]);
  const revisionRows=revisionOutputs.map(out=>JSON.parse(out.split(/\r?\n/).find(x=>x.startsWith('REVISION_RESULT=')).slice(16)));
  if(JSON.stringify(revisionRows[0])!==JSON.stringify(revisionRows[1])||revisionRows[0].status!=="REVISION_REQUESTED")throw new Error("Canonical revision retry mismatch");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('actions',(select count(*) from public.review_actions where action_type='REQUESTED_REVISION'),'audit',(select count(*) from public.audit_events where event_type='REVISION_REQUESTED'),'feedback',(select count(*) from public.feedback_items),'version',(select status from public.artifact_versions where id='${ctx.version}'),'submission',(select status from public.submissions where id='${ctx.submission}'));`]).trim());
  if(stats.actions!==1||stats.audit!==1||stats.feedback!==1||stats.version!=="REVISION_REQUESTED"||stats.submission!=="REVISION_REQUESTED")throw new Error("Revision race history mismatch");
  const reassign=request(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);select public.assign_master_to_cohort('${ctx.cohort}','00000000-0000-4000-8000-000000006003');select 'RACE_READY';select pg_sleep(0.7);commit;`);await reassign.ready;
  const revoked=request(`begin;${reviewer}do $$begin begin perform ${comment};raise exception 'Revoked reviewer bypass';exception when insufficient_privilege then null;end;end$$;commit;`);await Promise.all([reassign.promise,revoked.promise]);
  const count=run("psql",[...dbArgs,"-t","-A","-c","select count(*) from public.feedback_items;"]).trim();if(count!=="1")throw new Error("Revoked reviewer created Feedback");
  console.log("M8.9 concurrent revision/canonical retry/reassignment revocation PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
