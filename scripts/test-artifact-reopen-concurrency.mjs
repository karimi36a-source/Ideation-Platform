import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";

/** Independent PostgreSQL sessions prove Artifact-lock serialization. */
export async function testArtifactReopenConcurrency({run,args,binary,childEnv,root}){
 const name="fici_artifact_reopen_concurrency";const children=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((value,index)=>args[index-1]==="-d"?name:value);
 const owner="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);";
 const reviewer="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);";
 function request(sql){let signal;const ready=new Promise(resolve=>signal=resolve);const promise=new Promise((resolve,reject)=>{const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";const timer=setTimeout(()=>{child.kill();reject(new Error("Reopen race timeout"));},60000);child.stdout.on("data",chunk=>{out+=chunk;if(out.includes("RACE_READY"))signal();});child.stderr.on("data",chunk=>err+=chunk);child.on("error",error=>{clearTimeout(timer);signal();reject(error);});child.on("close",code=>{clearTimeout(timer);signal();if(code===0)resolve(out);else reject(new Error("Reopen race failed: "+err));});child.stdin.end(sql);});return {ready,promise};}
 const value=(out,prefix)=>{const line=out.split(/\r?\n/).find(item=>item.startsWith(prefix));if(!line)throw new Error("Missing "+prefix);return JSON.parse(line.slice(prefix.length));};
 try{
  const prefix=readFileSync(join(root,"tests/integration/approve-artifact.sql"),"utf8").split("-- All normal-client approval writes")[0];
  const setup=prefix+`
  ${owner}
  create temporary table race_review(data jsonb);grant select,insert,update on race_review to authenticated;
  insert into race_review select public.create_artifact_version((payload->>'artifactId')::uuid,'{"approvalRace":1}','Race') from submitted_fixtures where label='Personal';
  update race_review set data=public.submit_artifact((data->>'artifact_id')::uuid,(data->>'id')::uuid,(select id from instances where label='Individual'));
  ${reviewer}select public.start_review((select (data->>'id')::uuid from race_review));reset role;
  create temporary table archive_fixture(label text,data jsonb);grant select,insert on archive_fixture to authenticated;
  ${owner}
  insert into archive_fixture values('first',public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'PROBLEM_BANK','Archive first',null,false,false)),('reopen',public.create_artifact((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'PROBLEM_BANK','Reopen first',null,false,false));reset role;
  update public.artifact_versions v set status='CURRENT',approved_by='00000000-0000-4000-8000-000000006002',approved_at=clock_timestamp() from archive_fixture f where v.id=(f.data->>'initialVersionId')::uuid;
  update public.artifacts a set current_version_id=(f.data->>'initialVersionId')::uuid from archive_fixture f where a.id=(f.data->>'artifactId')::uuid;
  select 'REOPEN_FIXTURE='||jsonb_build_object('artifact',(select payload->>'artifactId' from submitted_fixtures where label='Personal'),'activity',(select id from instances where label='Individual'),'current',(select current_version_id from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal')),'submission',(select data->>'id' from race_review),'reviewVersion',(select data->>'artifact_version_id' from race_review),'archiveFirst',(select data->>'artifactId' from archive_fixture where label='first'),'reopenFirst',(select data->>'artifactId' from archive_fixture where label='reopen'))::text;commit;`;
  const ctx=value(run("psql",[...dbArgs,"-t","-A","-f","-"],setup),"REOPEN_FIXTURE=");
  for(const id of Object.values(ctx))if(!/^[0-9a-f-]{36}$/.test(id))throw new Error("Invalid reopen fixture");

  const first=request(`begin;${owner}select 'REOPEN_RESULT='||public.reopen_approved_artifact('${ctx.artifact}')::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);await first.ready;
  const second=request(`begin;${owner}select 'REOPEN_RESULT='||public.reopen_approved_artifact('${ctx.artifact}')::text;commit;`);
  const reopened=(await Promise.all([first.promise,second.promise])).map(out=>value(out,"REOPEN_RESULT="));
  if(new Set(reopened.map(r=>r.version.version_number)).size!==2||reopened.some(r=>r.sourceVersionId!==ctx.current||r.version.previous_version_id!==ctx.current))throw new Error("Concurrent reopen lineage/numbering failed");

  const approvalFirst=request(`begin;${reviewer}select public.approve_artifact('${ctx.submission}');select 'RACE_READY';select pg_sleep(0.7);commit;`);await approvalFirst.ready;
  const reopenAfter=request(`begin;${owner}select 'AFTER_APPROVAL='||public.reopen_approved_artifact('${ctx.artifact}')::text;commit;`);
  const [,afterOut]=await Promise.all([approvalFirst.promise,reopenAfter.promise]);const after=value(afterOut,"AFTER_APPROVAL=");
  if(after.sourceVersionId!==ctx.reviewVersion||after.version.previous_version_id!==ctx.reviewVersion)throw new Error("Approval-first reopen used stale current pointer");

  const cycle2=value(run("psql",[...dbArgs,"-t","-A","-f","-"],`begin;${owner}create temporary table c(data jsonb);insert into c values(public.create_artifact_version('${ctx.artifact}','{"approvalRace":2}','Race two'));update c set data=public.submit_artifact('${ctx.artifact}',(data->>'id')::uuid,'${ctx.activity}');${reviewer}select public.start_review((select (data->>'id')::uuid from c));select 'CYCLE2='||data::text from c;commit;`),"CYCLE2=");
  const reopenBefore=request(`begin;${owner}select 'BEFORE_APPROVAL='||public.reopen_approved_artifact('${ctx.artifact}')::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);await reopenBefore.ready;
  const approvalAfter=request(`begin;${reviewer}select public.approve_artifact('${cycle2.id}');commit;`);
  const [beforeOut]=await Promise.all([reopenBefore.promise,approvalAfter.promise]);const before=value(beforeOut,"BEFORE_APPROVAL=");
  if(before.sourceVersionId!==ctx.reviewVersion||before.version.previous_version_id!==ctx.reviewVersion)throw new Error("Reopen-first transaction did not use locked current pointer");

  const archiveFirst=request(`begin;${owner}select public.archive_artifact('${ctx.archiveFirst}');select 'RACE_READY';select pg_sleep(0.7);commit;`);await archiveFirst.ready;
  const denied=request(`begin;${owner}do $$begin begin perform public.reopen_approved_artifact('${ctx.archiveFirst}');raise exception 'archive bypass';exception when insufficient_privilege then null;end;end$$;commit;`);await Promise.all([archiveFirst.promise,denied.promise]);
  const reopenFirst=request(`begin;${owner}select public.reopen_approved_artifact('${ctx.reopenFirst}');select 'RACE_READY';select pg_sleep(0.7);commit;`);await reopenFirst.ready;
  const archiveAfter=request(`begin;${owner}select public.archive_artifact('${ctx.reopenFirst}');commit;`);await Promise.all([reopenFirst.promise,archiveAfter.promise]);
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('duplicates',(select count(*) from (select artifact_id,version_number from public.artifact_versions group by 1,2 having count(*)>1)x),'multiCurrent',(select count(*) from (select artifact_id from public.artifact_versions where status='CURRENT' group by 1 having count(*)>1)x),'pointer',(select current_version_id from public.artifacts where id='${ctx.artifact}'),'archiveFirstVersions',(select count(*) from public.artifact_versions where artifact_id='${ctx.archiveFirst}'),'reopenFirstVersions',(select count(*) from public.artifact_versions where artifact_id='${ctx.reopenFirst}'),'reopenFirstArchived',(select count(*) from public.artifacts where id='${ctx.reopenFirst}' and status='ARCHIVED'),'badPointer',(select count(*) from public.artifacts a join public.artifact_versions v on v.id=a.current_version_id where v.artifact_id<>a.id or v.status<>'CURRENT'));`]).trim());
  if(stats.duplicates!==0||stats.multiCurrent!==0||stats.pointer!==cycle2.artifact_version_id||stats.archiveFirstVersions!==1||stats.reopenFirstVersions!==2||stats.reopenFirstArchived!==1||stats.badPointer!==0)throw new Error("Reopen race final integrity failed");
  console.log("M8.12 concurrent reopen / both approval-reopen winners / both archive orders PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
