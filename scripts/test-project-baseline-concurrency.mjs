import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";

/** Real independent PostgreSQL sessions; isolated clone, never hosted data. */
export async function testProjectBaselineConcurrency({run,args,binary,childEnv,root}){
 const name="fici_baseline_concurrency";const children=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((value,index)=>args[index-1]==="-d"?name:value);
 const owner="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);";
 const master="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);";
 function request(sql){let signal;const ready=new Promise(resolve=>signal=resolve);const promise=new Promise((resolve,reject)=>{const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";const timer=setTimeout(()=>{child.kill();reject(new Error("Baseline race timeout"));},60000);child.stdout.on("data",chunk=>{out+=chunk;if(out.includes("RACE_READY"))signal();});child.stderr.on("data",chunk=>err+=chunk);child.on("error",error=>{clearTimeout(timer);signal();reject(error);});child.on("close",code=>{clearTimeout(timer);signal();if(code===0)resolve(out);else reject(new Error("Baseline race failed: "+err));});child.stdin.end(sql);});return {ready,promise};}
 const value=(out,prefix)=>{const line=out.split(/\r?\n/).find(x=>x.startsWith(prefix));if(!line)throw new Error("Missing "+prefix);return JSON.parse(line.slice(prefix.length));};
 try{
  const prefix=readFileSync(join(root,"tests/integration/approve-artifact.sql"),"utf8").split("-- All normal-client approval writes")[0];
  const setup=prefix+`
  create temporary table race_artifact(data jsonb);grant all on race_artifact to authenticated;
  ${owner}
  insert into race_artifact select public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'INVENTION_CONCEPT','Other candidate',(select id from instances where label='Individual'),true,true) from logged_projects where label='Individual';
  update race_artifact set data=data||jsonb_build_object('submission',public.submit_artifact((data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,(select id from instances where label='Individual')));
  ${master}select public.start_review((select (data->'submission'->>'id')::uuid from race_artifact));select public.approve_artifact((select (data->'submission'->>'id')::uuid from race_artifact));
  ${owner}
  create temporary table next_review(data jsonb);grant all on next_review to authenticated;
  insert into next_review select public.create_artifact_version((payload->>'artifactId')::uuid,'{"next":true}','Next') from submitted_fixtures where label='Personal';
  update next_review set data=public.submit_artifact((data->>'artifact_id')::uuid,(data->>'id')::uuid,(select id from instances where label='Individual'));
  ${master}select public.start_review((select (data->>'id')::uuid from next_review));reset role;
  select 'BASELINE_FIXTURE='||jsonb_build_object('teamProject',(select payload->>'id' from logged_projects where label='Team'),'teamArtifact',(select payload->>'artifactId' from submitted_fixtures where label='Team'),'teamVersion',(select payload->>'initialVersionId' from submitted_fixtures where label='Team'),'project',(select payload->>'id' from logged_projects where label='Individual'),'artifact',(select payload->>'artifactId' from submitted_fixtures where label='Personal'),'version',(select current_version_id from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal')),'otherArtifact',(select data->>'artifactId' from race_artifact),'otherVersion',(select data->>'initialVersionId' from race_artifact),'submission',(select data->>'id' from next_review),'nextVersion',(select data->>'artifact_version_id' from next_review))::text;commit;`;
  const c=value(run("psql",[...dbArgs,"-t","-A","-f","-"],setup),"BASELINE_FIXTURE=");
  for(const id of Object.values(c))if(!/^[0-9a-f-]{36}$/.test(id))throw new Error("Invalid race fixture");
  const set=(type,artifact=c.artifact,version=c.version)=>`public.set_project_baseline_item('${c.project}','${type}','${artifact}','${version}')`;
  const first=request(`begin;${master}select 'ITEM='||${set("SAME")}::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);await first.ready;
  const retry=request(`begin;${master}select 'ITEM='||${set("SAME")}::text;commit;`);
  const same=(await Promise.all([first.promise,retry.promise])).map(out=>value(out,"ITEM="));if(JSON.stringify(same[0])!==JSON.stringify(same[1]))throw new Error("Concurrent retry rewrote identity");
  const different=request(`begin;${master}select ${set("COMPETING")};select 'RACE_READY';select pg_sleep(0.7);commit;`);await different.ready;
  const replacement=request(`begin;${master}select ${set("COMPETING",c.otherArtifact,c.otherVersion)};commit;`);await Promise.all([different.promise,replacement.promise]);

  // Approval holds the Artifact: a previously valid target must be rechecked
  // after waiting, rather than accepting the now-SUPERSEDED Version.
  const approval=request(`begin;${master}select public.approve_artifact('${c.submission}');select 'RACE_READY';select pg_sleep(0.7);commit;`);await approval.ready;
  const stale=request(`begin;${master}do $$begin begin perform ${set("STALE")};raise exception 'Stale CURRENT bypass';exception when insufficient_privilege then null;end;end$$;commit;`);const uncommitted=request(`begin;${master}do $$begin begin perform ${set("UNCOMMITTED",c.artifact,c.nextVersion)};raise exception 'Uncommitted approval bypass';exception when insufficient_privilege then null;end;end$$;commit;`);await Promise.all([approval.promise,stale.promise,uncommitted.promise]);
  run("psql",[...dbArgs,"-c",`begin;${master}select ${set("AFTER_APPROVAL",c.artifact,c.nextVersion)};commit;`]);
  const setFirst=request(`begin;${master}select ${set("BEFORE_ARCHIVE",c.artifact,c.nextVersion)};select 'RACE_READY';select pg_sleep(0.7);commit;`);await setFirst.ready;
  const archive=request(`begin;${owner}select public.archive_artifact('${c.artifact}');commit;`);await Promise.all([setFirst.promise,archive.promise]);
  const archiveFirst=request(`begin;${owner}select public.archive_artifact('${c.otherArtifact}');select 'RACE_READY';select pg_sleep(0.7);commit;`);await archiveFirst.ready;
  const afterArchive=request(`begin;${master}do $$begin begin perform ${set("ARCHIVED",c.otherArtifact,c.otherVersion)};raise exception 'Archived bypass';exception when insufficient_privilege then null;end;end$$;commit;`);await Promise.all([archiveFirst.promise,afterArchive.promise]);
  const projectArchive=request(`begin;${master}select public.archive_development_project('${c.teamProject}');select 'RACE_READY';select pg_sleep(0.7);commit;`);await projectArchive.ready;
  const projectDenied=request(`begin;${master}do $$begin begin perform public.set_project_baseline_item('${c.teamProject}','PROJECT_ARCHIVED','${c.teamArtifact}','${c.teamVersion}');raise exception 'Archived Project bypass';exception when insufficient_privilege then null;end;end$$;commit;`);await Promise.all([projectArchive.promise,projectDenied.promise]);
  run("psql",[...dbArgs,"-c",`begin;${owner}select public.archive_development_project('${c.project}');commit;`]);
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('same',(select count(*) from public.project_baseline_items where baseline_type='SAME'),'sameAudit',(select count(*) from public.audit_events where event_type='BASELINE_UPDATED'),'competing',(select count(*) from public.project_baseline_items where baseline_type='COMPETING'),'effective',(select count(*) from public.project_baseline_items where baseline_type='COMPETING' and effective_to is null),'bad',(select count(*) from public.project_baseline_items where baseline_type in ('STALE','ARCHIVED','UNCOMMITTED','PROJECT_ARCHIVED')),'history',(select count(*) from public.project_baseline_items));`]).trim());
  if(stats.same!==1||stats.competing!==2||stats.effective!==1||stats.bad!==0||stats.history!==5||stats.sameAudit!==5)throw new Error("Baseline race final state "+JSON.stringify(stats));
  console.log("M8.13 independent-session same/different targets / approval recheck / archive orders PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
