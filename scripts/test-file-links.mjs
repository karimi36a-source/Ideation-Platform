import {spawn,spawnSync} from "node:child_process";
import {join} from "node:path";
import {artifactReviewSecurityFixture} from "./artifact-review-security-fixture.mjs";
export async function testFileLinks({run,args,binary,childEnv,root}){
 const database="fici_file_link_operations",children=[];
 run("psql",[...args,"-c",`create database ${database} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?database:v);
 const query=sql=>run("psql",[...db,"-t","-A","-c",sql]).trim();
 function session(actor,relation,hold=false){
  let readySignal;const ready=new Promise(resolve=>readySignal=resolve);let child;
  const done=new Promise((resolve,reject)=>{
   child=spawn(binary("psql"),[...db,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("File Link race timeout"));},45000);
   child.stdout.on("data",data=>{out+=data;if(out.includes("READY"))readySignal();});child.stderr.on("data",data=>err+=data);
   child.on("error",reject);child.on("exit",code=>{clearTimeout(timer);if(code===0)resolve(out);else reject(new Error(`File Link race failed: ${err}`));});
   child.stdin.write(`begin;set local application_name='file_link_race_${actor}';set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000600${actor}',true);select 'LINK='||(public.link_file(jsonb_build_object('fileId',(select file_id from file_link_test_context),'entityType','DEVELOPMENT_OBJECT','entityId',(select target from file_link_test_context),'relationshipType','${relation}'))->>'id');select 'READY';\n`);
   if(!hold)child.stdin.end("commit;\n");
  });return {ready,done,finish:(terminal="commit")=>child.stdin.end(`${terminal};\n`)};
 }
 try{
 run("psql",[...db,"-f","-"],artifactReviewSecurityFixture(root)+`
 reset role;
 select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 create table public.file_link_test_context(file_id uuid,target uuid);
 grant select on public.file_link_test_context to authenticated;
 do $$declare r jsonb;f jsonb;target uuid;p public.development_projects;begin
 select p0.* into p from public.development_projects p0 where id=(select (payload->>'id')::uuid from logged_projects where label='Team');
 r:=public.request_file_upload(p.primary_workspace_id,p.id,'link-race.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',r->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((r->>'id')::uuid);
 target:=(public.create_development_object(p.id,p.primary_workspace_id,'GAP','File Link target','Unchanged','User')->>'id')::uuid;
 insert into public.file_link_test_context values((f->>'id')::uuid,target);
 end$$;
 commit;`);
 const fileBefore=query("select to_jsonb(f)::text from public.files f where id=(select file_id from public.file_link_test_context)");
 const objectBefore=query("select to_jsonb(o)::text from public.development_objects o where id=(select target from public.file_link_test_context)");
 const service=spawnSync(process.execPath,[join(root,"node_modules/vitest/vitest.mjs"),"run","--config","vitest.file-links.config.mts"],{cwd:root,encoding:"utf8",windowsHide:true,timeout:90000,env:{...childEnv,FICI_FILE_LINK_TEST_PORT:String(args[args.indexOf("-p")+1])}});
 if(service.error||service.status!==0)throw new Error(`File Link public service failed: ${service.error?.message??service.stderr}\n${service.stdout}`);
 console.log(service.stdout);
 for(const rollback of [false,true]){
  const relation=rollback?"ATTACHMENT":"REFERENCE";
  const first=session(4,relation,true);await first.ready;
  const second=session(5,relation);let blocked=false;
  for(let n=0;n<100;n++){
   if(query("select count(*) from pg_stat_activity where application_name='file_link_race_5' and wait_event_type='Lock'")==="1"){blocked=true;break;}
   await new Promise(resolve=>setTimeout(resolve,20));
  }
  if(!blocked)throw new Error("File duplicate did not serialize");
  first.finish(rollback?"rollback":"commit");
  const [a,b]=await Promise.all([first.done,second.done]);const ids=[a,b].map(out=>out.split(/\r?\n/).find(line=>line.startsWith("LINK="))?.slice(5));
  if(ids.some(id=>!id)||(!rollback&&ids[0]!==ids[1]))throw new Error("File canonical duplicate changed");
  if(query(`select count(*) from public.file_links where relationship_type='${relation}' and archived_at is null`)!=="1")throw new Error("Duplicate or missing File link");
  if(rollback&&query(`select created_by from public.file_links where relationship_type='${relation}'`)!=="00000000-0000-4000-8000-000000006005")throw new Error("Rolled-back File link survived");
 }
 if(query("select to_jsonb(f)::text from public.files f where id=(select file_id from public.file_link_test_context)")!==fileBefore||query("select to_jsonb(o)::text from public.development_objects o where id=(select target from public.file_link_test_context)")!==objectBefore)throw new Error("Link mutated endpoint");
 console.log("M12.8 actual linkFile service + blocked duplicate race + rollback winner + unchanged endpoints PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${database} with (force)`]);}
}
