import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Local independent sessions prove serialization and revocation winners. */
export async function testArtifactArchiveConcurrency({run,args,binary,childEnv,root}){
 const name="fici_artifact_archive_concurrency";const children=[];
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
  const call=(id)=>`public.archive_artifact('${id}')`;
  const first=request(`begin;${claims}select 'ARCHIVE_RESULT='||${call(ctx.personal.artifactId)}::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);await first.ready;
  const second=request(`begin;${claims}select 'ARCHIVE_RESULT='||${call(ctx.personal.artifactId)}::text;commit;`);
  const outputs=await Promise.all([first.promise,second.promise]);
  const rows=outputs.map(out=>JSON.parse(out.split(/\r?\n/).find(x=>x.startsWith("ARCHIVE_RESULT=")).slice(15)));
  if(JSON.stringify(rows[0])!==JSON.stringify(rows[1])||rows[0].status!=="ARCHIVED"||!rows[0].archived_at)throw new Error("Double archive timestamp/identity mismatch");
  const archiveFirst=request(`begin;${claims}select ${call(ctx.archive.artifactId)};select 'RACE_READY';select pg_sleep(0.7);commit;`);await archiveFirst.ready;
  const blockedVersion=request(`begin;${claims}do $$begin begin perform public.create_artifact_version('${ctx.archive.artifactId}','{}','Denied');raise exception 'Archive race bypass';exception when insufficient_privilege then null;end;end$$;commit;`);await Promise.all([archiveFirst.promise,blockedVersion.promise]);
  const versionFirst=request(`begin;${claims}select public.create_artifact_version('${ctx.team.artifactId}','{"preserved":true}','Version first');select 'RACE_READY';select pg_sleep(0.7);commit;`);await versionFirst.ready;
  const laterArchive=request(`begin;${claims}select ${call(ctx.team.artifactId)};commit;`);await Promise.all([versionFirst.promise,laterArchive.promise]);
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('double',(select count(*) from public.artifact_versions where artifact_id='${ctx.personal.artifactId}'),'archiveFirst',(select count(*) from public.artifact_versions where artifact_id='${ctx.archive.artifactId}'),'versionFirst',(select count(*) from public.artifact_versions where artifact_id='${ctx.team.artifactId}'),'active',(select count(*) from public.artifacts where status<>'ARCHIVED'),'preserved',(select count(*) from public.artifact_versions where artifact_id='${ctx.team.artifactId}' and version_number=2 and content_snapshot='{"preserved":true}' and status='DRAFT'));`]).trim());
  if(stats.double!==1||stats.archiveFirst!==1||stats.versionFirst!==2||stats.active!==0||stats.preserved!==1)throw new Error("Archive race history/state integrity failed");
  console.log("M8.6 double archive + both Version/archive serialization orders PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
