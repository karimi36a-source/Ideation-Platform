import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Local independent sessions prove serialization and revocation winners. */
export async function testArtifactVersionConcurrency({run,args,binary,childEnv,root}){
 const name="fici_artifact_version_concurrency";const children=[];
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
  const out=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`\n${claims}select 'RACE_FIXTURE='||jsonb_build_object('personal',public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'PROBLEM_BANK','Number race',null,false,false),'archive',public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'PROBLEM_BANK','Archive race',null,false,false),'team',public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),'PROBLEM_BANK','Removal race',null,false,false),'teamId',(select payload->>'teamId' from acceptance_teams where label='A'))::text;commit;`);
  const line=out.split(/\r?\n/).find(x=>x.startsWith("RACE_FIXTURE="));if(!line)throw new Error("Missing Version race fixture");const ctx=JSON.parse(line.slice(13));
  for(const id of [ctx.personal.artifactId,ctx.archive.artifactId,ctx.team.artifactId,ctx.teamId])if(!/^[a-f0-9-]{36}$/.test(id))throw new Error("Invalid fixture UUID");
  const v1=run("psql",[...dbArgs,"-t","-A","-c",`select to_jsonb(v)::text from public.artifact_versions v where artifact_id='${ctx.personal.artifactId}';`]).trim();
  const call=`public.create_artifact_version('${ctx.personal.artifactId}','{"race":true}','Concurrent')`;
  const first=request(`begin;${claims}select 'VERSION_RESULT='||${call}::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);
  await first.ready;
  const second=request(`begin;${claims}select 'VERSION_RESULT='||${call}::text;commit;`);
  const outputs=await Promise.all([first.promise,second.promise]);
  const versions=outputs.map(out=>JSON.parse(out.split(/\r?\n/).find(x=>x.startsWith("VERSION_RESULT=")).slice(15))).sort((a,b)=>a.version_number-b.version_number);
  if(versions[0].version_number!==2||versions[1].version_number!==3||versions[0].previous_version_id!==ctx.personal.initialVersionId||versions[1].previous_version_id!==versions[0].id)throw new Error("Serialized V2/V3 lineage failed");
  const after=run("psql",[...dbArgs,"-t","-A","-c",`select to_jsonb(v)::text from public.artifact_versions v where id='${ctx.personal.initialVersionId}';`]).trim();if(after!==v1)throw new Error("Concurrent predecessor mutation");
  function denied(id){return `begin;${claims}do $$begin begin perform public.create_artifact_version('${id}','{}','Must deny');raise exception 'Revocation bypass';exception when insufficient_privilege then null;end;end$$;select 'VERSION_DENIED';commit;`;}
  const archive=request(`begin;update public.artifacts set status='ARCHIVED',archived_at=clock_timestamp() where id='${ctx.archive.artifactId}';select 'RACE_READY';select pg_sleep(0.7);commit;`);await archive.ready;
  const archiveAttempt=request(denied(ctx.archive.artifactId));await Promise.all([archive.promise,archiveAttempt.promise]);
  const removal=request(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select public.remove_team_member('${ctx.teamId}','00000000-0000-4000-8000-000000006004');select 'RACE_READY';select pg_sleep(0.7);commit;`);await removal.ready;
  const removedAttempt=request(denied(ctx.team.artifactId));await Promise.all([removal.promise,removedAttempt.promise]);
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('personal',(select count(*) from public.artifact_versions where artifact_id='${ctx.personal.artifactId}'),'archive',(select count(*) from public.artifact_versions where artifact_id='${ctx.archive.artifactId}'),'team',(select count(*) from public.artifact_versions where artifact_id='${ctx.team.artifactId}'),'duplicates',(select count(*) from (select artifact_id,version_number from public.artifact_versions group by artifact_id,version_number having count(*)>1) d));`]).trim());
  if(stats.personal!==3||stats.archive!==1||stats.team!==1||stats.duplicates!==0)throw new Error("Race row count/denial integrity failed");
  console.log("M8.5 concurrent V2/V3 + archive/removal races PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
