import {spawn} from "node:child_process";
import {artifactReviewSecurityFixture} from "./artifact-review-security-fixture.mjs";
export async function testEvidenceVerificationConcurrency({run,args,binary,childEnv,root}){
 const database="fici_evidence_verification_race",children=[];
 run("psql",[...args,"-c",`create database ${database} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?database:v);
 const query=sql=>run("psql",[...db,"-t","-A","-c",sql]).trim();
 function session(label,status,{hold=false,conflict=false}={}){
  let signal;const ready=new Promise(resolve=>signal=resolve);let child;
  const done=new Promise((resolve,reject)=>{
   child=spawn(binary("psql"),[...db,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Verification race timeout"));},45000);
   child.stdout.on("data",data=>{out+=data;if(out.includes("READY"))signal();});child.stderr.on("data",data=>err+=data);
   child.on("error",reject);child.on("exit",code=>{clearTimeout(timer);if(code===0)resolve(out);else reject(new Error(`Verification race failed: ${err}`));});
   const call=`public.verify_evidence((select id from public.evidence_verification_race where label='${label}'),'${status}','${conflict?"Contender":"Winner"}')`;
   const action=conflict?`do $$begin begin perform ${call};raise exception 'Overlapping verification silently succeeded';exception when serialization_failure then null;end;end $$;`:`select ${call};`;
   child.stdin.write(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);${action}select 'READY';\n`);
   if(!hold)child.stdin.end("commit;\n");
  });
  return {ready,done,finish:(terminal="commit")=>child.stdin.end(`${terminal};\n`)};
 }
 try{
  run("psql",[...db,"-f","-"],artifactReviewSecurityFixture(root)+`
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects p where label='Team' and not exists(select 1 from public.project_memberships m where m.project_id=(p.payload->>'id')::uuid and m.user_id='00000000-0000-4000-8000-000000006005' and status='active');
create table public.evidence_verification_race(label text primary key,id uuid);
grant select on public.evidence_verification_race to authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into public.evidence_verification_race select c.label,(public.create_evidence((p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,'OTHER','Race source','Recorded observations','Named source')->>'id')::uuid from logged_projects p cross join unnest(array['Forward','Reverse','Rollback']) c(label) where p.label='Team';
commit;`);
  for(const [label,firstStatus,secondStatus] of [["Forward","VERIFIED","CONTRADICTED"],["Reverse","CONTRADICTED","VERIFIED"],["Rollback","VERIFIED","NEEDS_REVIEW"]]){
   const first=session(label,firstStatus,{hold:true});await first.ready;
   const contender=session(label,secondStatus,{conflict:true});await contender.done;
   first.finish(label==="Rollback"?"rollback":"commit");await first.done;
   let current=JSON.parse(query(`select to_jsonb(e)::text from public.evidence e where id=(select id from public.evidence_verification_race where label='${label}')`));
   if(current.verification_status!==(label==="Rollback"?"UNVERIFIED":firstStatus))throw new Error("Verification winner/rollback changed");
   const count=()=>query(`select count(*) from public.evidence_verification_history where evidence_id='${current.id}'`);
   if(count()!==(label==="Rollback"?"0":"1"))throw new Error("Lost, duplicated or orphan verification history");
   if(label==="Rollback"){
    await session(label,secondStatus).done;
    current=JSON.parse(query(`select to_jsonb(e)::text from public.evidence e where id='${current.id}'`));
    if(current.verification_status!==secondStatus||count()!=="1")throw new Error("Verification retry after rollback failed");
   }else{
    const before=JSON.stringify(current);await session(label,firstStatus).done;
    if(count()!=="1"||JSON.stringify(JSON.parse(query(`select to_jsonb(e)::text from public.evidence e where id='${current.id}'`)))!==before)throw new Error("Same-status retry mutated history/current row");
   }
   if(query(`select count(*) from public.evidence_verification_history h join public.evidence e on e.id=h.evidence_id where e.id='${current.id}' and h.new_status=e.verification_status and h.verified_by=e.verified_by and h.verified_at=e.verified_at`)!=="1")throw new Error("History/current verification mismatch");
  }
  console.log("M12.4 concurrent verification explicit-conflict/winner/no-op/rollback PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${database} with (force)`]);}
}
