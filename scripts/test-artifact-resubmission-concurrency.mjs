import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Local independent sessions prove serialization and revocation winners. */
export async function testArtifactResubmissionConcurrency({run,args,binary,childEnv,root}){
 const name="fici_artifact_resubmission_concurrency";const children=[];
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


  const setup=readFileSync(join(root,"tests/integration/start-review-feedback.sql"),"utf8").split('create temporary table review_before')[0].split(/\r?\n/).filter(line=>!line.includes("select 'Future',public.create_artifact_version")).join('\n');
  const out=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`\nselect 'REVIEW_FIXTURE='||jsonb_build_object('submission',(select payload->>'id' from review_fixtures where label='Personal'),'artifact',(select payload->>'artifactId' from submitted_fixtures where label='Personal'),'version',(select payload->>'initialVersionId' from submitted_fixtures where label='Personal'),'cohort',(select id from acceptance_cohorts where label='Test'))::text;commit;`);
  const line=out.split(/\r?\n/).find(x=>x.startsWith("REVIEW_FIXTURE="));if(!line)throw new Error("Missing review fixture");const ctx=JSON.parse(line.slice(15));
  for(const id of Object.values(ctx))if(!/^[a-f0-9-]{36}$/.test(id))throw new Error("Invalid fixture UUID");
  const reviewer="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);";

  run("psql",[...dbArgs,"-c",`begin;${reviewer}select public.start_review('${ctx.submission}');select public.request_revision('${ctx.submission}','Revise');commit;`]);
  const owner="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);";
  const create=`public.create_revision_draft('${ctx.submission}','{"revised":true}','Concurrent revision')`;
  const first=request(`begin;${owner}select ${create};select 'RACE_READY';select pg_sleep(0.7);commit;`);await first.ready;
  const second=request(`begin;${owner}do $$begin begin perform ${create};raise exception 'Competing revision accepted';exception when invalid_parameter_value then null;end;end$$;commit;`);
  await Promise.all([first.promise,second.promise]);
  const draft=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select row_to_json(v) from public.artifact_versions v where artifact_id='${ctx.artifact}' and version_number=2;`]).trim());
  if(draft.previous_version_id!==ctx.version||draft.status!=="DRAFT")throw new Error("Wrong formal lineage");
  const activity=run("psql",[...dbArgs,"-t","-A","-c",`select activity_instance_id from public.submissions where id='${ctx.submission}';`]).trim();
  const submit=`public.submit_artifact('${ctx.artifact}','${draft.id}','${activity}')`;
  const submitFirst=request(`begin;${owner}select ${submit};select 'RACE_READY';select pg_sleep(0.7);commit;`);await submitFirst.ready;
  const submitSecond=request(`begin;${owner}do $$begin begin perform ${submit};raise exception 'Duplicate resubmission accepted';exception when unique_violation then null;end;end$$;commit;`);
  await Promise.all([submitFirst.promise,submitSecond.promise]);
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('versions',(select count(*) from public.artifact_versions where artifact_id='${ctx.artifact}'),'submissions',(select count(*) from public.submissions where artifact_id='${ctx.artifact}'),'source',(select status from public.submissions where id='${ctx.submission}'),'draft',(select status from public.artifact_versions where id='${draft.id}'));`]).trim());
  if(stats.versions!==2||stats.submissions!==2||stats.source!=="REVISION_REQUESTED"||stats.draft!=="SUBMITTED")throw new Error("Duplicate revision or resubmission");
  console.log("M8.10 concurrent formal child and resubmission conflicts PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
