import {spawn} from "node:child_process";
import {artifactReviewSecurityFixture} from "./artifact-review-security-fixture.mjs";
export async function testEvidenceLinkConcurrency({run,args,binary,childEnv,root}){
 const database="fici_evidence_link_race",children=[];
 run("psql",[...args,"-c",`create database ${database} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?database:v);
 const query=sql=>run("psql",[...db,"-t","-A","-c",sql]).trim();
 function session(actor,relation,hold=false){
  let readySignal;const ready=new Promise(resolve=>readySignal=resolve);let child;
  const done=new Promise((resolve,reject)=>{
   child=spawn(binary("psql"),[...db,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Evidence duplicate race timeout"));},45000);
   child.stdout.on("data",data=>{out+=data;if(out.includes("READY"))readySignal();});child.stderr.on("data",data=>err+=data);
   child.on("error",reject);child.on("exit",code=>{clearTimeout(timer);if(code===0)resolve(out);else reject(new Error(`Evidence race failed: ${err}`));});
   child.stdin.write(`begin;set local application_name='evidence_race_${actor}';set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000600${actor}',true);select 'LINK='||(public.link_evidence(jsonb_build_object('evidenceId',(select evidence from evidence_race),'entityType','GAP','entityId',(select target from evidence_race),'relationshipType','${relation}'))->>'id');select 'READY';\n`);
   if(!hold)child.stdin.end("commit;\n");
  });
  return {ready,done,finish:(terminal="commit")=>child.stdin.end(`${terminal};\n`)};
 }
 try{
  const setup=artifactReviewSecurityFixture(root)+`
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects p where label='Team' and not exists(select 1 from public.project_memberships m where m.project_id=(p.payload->>'id')::uuid and m.user_id='00000000-0000-4000-8000-000000006005' and status='active');
create table public.evidence_race(evidence uuid,target uuid);
grant select on public.evidence_race to authenticated;
with e as(insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name) select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'OTHER','Race','Race source','Recorded observation' from logged_projects where label='Team' returning id)
insert into public.evidence_race select id,(public.create_development_object((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),'GAP','Race Gap','Unchanged','User')->>'id')::uuid from e;
commit;`;
  run("psql",[...db,"-f","-"],setup);
  for(const rollback of [false,true]){
   const relation=rollback?"VALIDATES":"SUPPORTS";
   const first=session(4,relation,true);await first.ready;
   const second=session(5,relation);
   let blocked=false;
   for(let n=0;n<100;n++){
    if(query("select count(*) from pg_stat_activity where application_name='evidence_race_5' and wait_event_type='Lock'")==="1"){blocked=true;break;}
    await new Promise(resolve=>setTimeout(resolve,20));
   }
   if(!blocked)throw new Error("Evidence duplicate did not serialize");
   first.finish(rollback?"rollback":"commit");
   const [a,b]=await Promise.all([first.done,second.done]);
   const ids=[a,b].map(out=>out.split(/\r?\n/).find(line=>line.startsWith("LINK="))?.slice(5));
   if(ids.some(id=>!id)||(!rollback&&ids[0]!==ids[1]))throw new Error("Canonical duplicate result changed");
   if(query(`select count(*) from public.evidence_links where relationship_type='${relation}' and archived_at is null`)!=="1")throw new Error("Duplicate or missing active link");
   if(rollback&&query(`select created_by from public.evidence_links where relationship_type='${relation}'`)!=="00000000-0000-4000-8000-000000006005")throw new Error("Rolled-back actor survived");
  }
  console.log("M12.2 duplicate concurrent Evidence Link PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${database} with (force)`]);}
}
