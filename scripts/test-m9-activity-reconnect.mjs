import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {m9ActivityIntegrationFixture} from "./m9-activity-integration-fixture.mjs";
// Committed canonical state; each reconnect is a new PostgreSQL process/request.
export async function testM9ActivityReconnect({run,args,root,binary,childEnv}){
 const name="fici_m9_activity_reconnect";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  run("psql",[...dbArgs,"-f","-"],m9ActivityIntegrationFixture(root)+readFileSync(join(root,"tests/integration/m9-activity-integration-setup.sql"),"utf8")+"\ncommit;");
  const request=()=>{
   const out=run("psql",[...dbArgs,"-t","-A","-f","-"],`begin read only;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select 'RESTORED='||jsonb_build_object('resume',public.resume_activity(a.id),'scamper',case when a.configuration_snapshot->>'method_type'='scamper' then public.list_scamper_entries(a.id) else '[]'::jsonb end,
'brainstorm',(select coalesce(jsonb_agg(to_jsonb(b) order by b.id),'[]'::jsonb) from public.brainstorm_entries b where b.activity_instance_id=a.id))::text
from public.activity_instances a where a.activity_definition_id between '00000000-0000-4000-8000-000000914801' and '00000000-0000-4000-8000-000000914806' order by a.activity_definition_id;
select 'SCAMPER='||public.get_scamper_entry(o.origin_reference_id)::text from public.development_objects o where o.origin_type='SCAMPER' and o.title='M9.14 proposal' order by o.id;commit;`);
   return out.split(/\r?\n/).filter(v=>v.startsWith("RESTORED=")||v.startsWith("SCAMPER="));
  };
  const counts=()=>run("psql",[...dbArgs,"-t","-A","-c","select count(*) from public.activity_instances;select count(*) from public.activity_outputs;select count(*) from public.development_objects;select count(*) from public.artifacts;select count(*) from public.scamper_entries;select count(*) from public.brainstorm_entries;"]);
  const before=counts(),first=request(),second=request();
  if(first.length!==9||JSON.stringify(first)!==JSON.stringify(second)||before!==counts())throw new Error("M9 reconnect changed persisted identity/state/counts");
  const state=first.filter(x=>x.startsWith("RESTORED=")).map(x=>JSON.parse(x.slice(9)));
  if(state.some(x=>Object.keys(x.resume).sort().join(",")!=="activity,definition,inputs,outputs,participants"))throw new Error("Generic resume expanded");
  if(state[0].scamper.length!==2||!state[0].scamper.some(x=>x.idea_object_id===null&&x.proposed_change==="Unpromoted persisted source"))throw new Error("Reconnect cannot discover unpromoted SCAMPER state");
  if(state[2].resume.outputs.length!==1||state[5].resume.outputs.length!==1||state.slice(3).some(x=>x.brainstorm.length!==1||x.brainstorm[0].revealed_at!==null))throw new Error("Feature reload lost outputs/privacy");
  console.log("M9.14 committed separate-request reauthentication + canonical feature reload + no clones PASS");
  for(const [definition,create,promote,origin] of [[914803,"create_scamper_entry","promote_scamper_entry_to_idea","SCAMPER"],[914806,"create_brainstorm_entry","promote_brainstorm_entry_to_idea","BRAINSTORM"]]){
   const activity=`(select id from public.activity_instances where activity_definition_id='00000000-0000-4000-8000-${String(definition).padStart(12,"0")}')`;
   const claims="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);";
   const createArgs=origin==="SCAMPER"?`${activity},'SUBSTITUTE','Race original','Race proposal','Race result'`:`${activity},'Race private idea','private'`;
   const created=run("psql",[...dbArgs,"-t","-A","-c",`begin;${claims}select 'ENTRY='||(public.${create}(${createArgs})->>'id');commit;`]);
   const entry=created.split(/\r?\n/).find(x=>x.startsWith("ENTRY="))?.slice(6);
   if(!/^[a-f0-9-]{36}$/.test(entry??""))throw new Error("Missing configured race source");
   const children=[];
   function requestRace(delay){let signal;const ready=new Promise(resolve=>signal=resolve);
    const promise=new Promise((resolve,reject)=>{const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";
     const timer=setTimeout(()=>{child.kill();reject(new Error("Configured promotion race timeout"));},60000);
     child.stdout.on("data",x=>{out+=x;if(out.includes("READY"))signal();});child.stderr.on("data",x=>err+=x);
     child.on("error",e=>{clearTimeout(timer);signal();reject(e);});child.on("close",code=>{clearTimeout(timer);signal();if(code===0)resolve(out);else reject(new Error("Configured promotion race failed: "+err));});
     child.stdin.end(`begin;${claims}select 'IDEA='||(public.${promote}('${entry}')->>'id');select 'READY';${delay?"select pg_sleep(0.5);":""}commit;`);
    });return {promise,ready};
   }
   try{
    const first=requestRace(true);await first.ready;const second=requestRace(false);const results=await Promise.all([first.promise,second.promise]);
    const ids=results.map(x=>x.split(/\r?\n/).find(line=>line.startsWith("IDEA="))?.slice(5));
    if(!ids[0]||ids[0]!==ids[1])throw new Error("Configured promotion duplicated IDEA");
    const stats=run("psql",[...dbArgs,"-t","-A","-c",`select count(*) from public.development_objects where origin_type='${origin}' and origin_reference_id='${entry}';select count(*) from public.activity_outputs where development_object_id='${ids[0]}';select count(*) from public.change_log where entity_id='${ids[0]}' and change_type='OBJECT_CREATED';`]).trim().split(/\r?\n/);
    if(stats.join(",")!=="1,1,1")throw new Error("Configured promotion duplicated output/log");
   }finally{for(const child of children)if(child.exitCode===null)child.kill();}
  }
  console.log("M9.14 opt-in independent-session SCAMPER/Brainstorm promotion one IDEA/output/log PASS");

 }finally{run("psql",[...args,"-c",`drop database ${name}`]);}
}
