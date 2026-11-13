import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Independent sessions in a local disposable database; no hosted credentials. */
export async function testArtifactCreationConcurrency({run,args,binary,childEnv,root}){
 const name="fici_artifact_creation_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const setup=readFileSync(join(root,"tests/integration/create-artifact.sql"),"utf8").split("-- M8.4 TEST CASES")[0];
  const out=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+"\nselect 'CREATION_CONTEXT='||payload::text from logged_projects where label='Individual';\ncommit;");
  const line=out.split(/\r?\n/).find(x=>x.startsWith("CREATION_CONTEXT="));if(!line)throw new Error("Missing Artifact race fixture");
  const ctx=JSON.parse(line.slice("CREATION_CONTEXT=".length));
  for(const key of ["id","primary_workspace_id"])if(!/^[a-f0-9-]{36}$/.test(ctx[key]))throw new Error("Invalid fixture UUID");
  const sql=`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select 'ARTIFACT_RESULT='||public.create_artifact('${ctx.id}','${ctx.primary_workspace_id}','PROBLEM_BANK','Concurrent Artifact',null,true,true)::text;select pg_sleep(0.5);commit;`;
  const call=()=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Artifact concurrency timeout"));},60000);
   child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Artifact concurrency failed: "+err));try{const line=out.split(/\r?\n/).find(x=>x.startsWith("ARTIFACT_RESULT="));if(!line)throw new Error("Missing Artifact result");resolve(JSON.parse(line.slice(16)));}catch(e){reject(e);}});child.stdin.end(sql);
  });
  const result=await Promise.all([call(),call()]);
  if(result[0].artifactId===result[1].artifactId||result[0].initialVersionId===result[1].initialVersionId)throw new Error("Distinct calls must not deduplicate");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('artifacts',(select count(*) from public.artifacts),'versions',(select count(*) from public.artifact_versions),'bad',(select count(*) from public.artifacts a where a.current_version_id is not null or a.status<>'ACTIVE' or (select count(*) from public.artifact_versions v where v.artifact_id=a.id and v.version_number=1 and v.status='DRAFT' and v.content_snapshot='{}')<>1));`]).trim());
  if(stats.artifacts!==2||stats.versions!==2||stats.bad!==0)throw new Error("Concurrent Artifact/V1 transaction integrity failed");
  console.log("M8.4 independent-session distinct Artifact + single V1 concurrency PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
