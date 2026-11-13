import {spawn} from "node:child_process";
import {brainstormPromotionFixture} from "./brainstorm-promotion-fixture.mjs";
export async function testBrainstormPromotionConcurrency({run,args,binary,childEnv,root}){
 const name="fici_brainstorm_promotion_race",children=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const claims="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);";
 function request(sql){let signal;const ready=new Promise(resolve=>signal=resolve);
  const promise=new Promise((resolve,reject)=>{const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("BRAINSTORM promotion race timeout"));},60000);
   child.stdout.on("data",x=>{out+=x;if(out.includes("RACE_READY"))signal();});child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);signal();reject(e);});child.on("close",code=>{clearTimeout(timer);signal();if(code===0)resolve(out);else reject(new Error("Promotion race failed: "+err));});child.stdin.end(sql);
  });return {promise,ready};
 }
 try{
  const setup=run("psql",[...dbArgs,"-t","-A","-f","-"],brainstormPromotionFixture(root)+`${claims}select 'PROMOTION_SOURCE='||(public.create_brainstorm_entry((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Personal'),'Race source','private')->>'id');commit;`);
  const entry=setup.split(/\r?\n/).find(x=>x.startsWith("PROMOTION_SOURCE="))?.slice(17);
  if(!/^[a-f0-9-]{36}$/.test(entry??""))throw new Error("Missing promotion race fixture");
  const call=`public.promote_brainstorm_entry_to_idea('${entry}')`;
  const first=request(`begin;${claims}select 'PROMOTION_RESULT='||${call}::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);await first.ready;
  const second=request(`begin;${claims}select 'PROMOTION_RESULT='||${call}::text;commit;`);
  const results=await Promise.all([first.promise,second.promise]);
  const objects=results.map(out=>JSON.parse(out.split(/\r?\n/).find(x=>x.startsWith("PROMOTION_RESULT=")).slice(17)));
  if(objects[0].id!==objects[1].id)throw new Error("Duplicate concurrent Idea");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('objects',(select count(*) from public.development_objects where origin_type='BRAINSTORM' and origin_reference_id='${entry}'),'linked',(select development_object_id::text from public.brainstorm_entries where id='${entry}'),'logs',(select count(*) from public.change_log where entity_id='${objects[0].id}' and change_type='OBJECT_CREATED'));`]).trim());
  if(stats.objects!==1||stats.logs!==1||stats.linked!==objects[0].id)throw new Error("Promotion race identity/history mismatch");
  console.log("M9.9 independent-session promotion concurrency one Idea/one source link/one log PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
