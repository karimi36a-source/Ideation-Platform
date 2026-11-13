import {spawn} from "node:child_process";
import {affinityItemFixture} from "./affinity-item-fixture.mjs";
export async function testAffinityItemConcurrency({run,args,binary,childEnv,root}){
 const name="fici_affinity_item_concurrency";run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const output=run("psql",[...dbArgs,"-t","-A","-f","-"],affinityItemFixture(root)+"select 'TARGET='||jsonb_build_object('g1',(select payload->>'id' from ai_groups where label='Team'),'g2',(select payload->>'id' from ai_groups where label='Second'),'o1',(select id from ai_sources where label='PROBLEM'),'o2',(select id from ai_sources where label='SOLUTION'))::text;commit;");
  const target=JSON.parse(output.split(/\r?\n/).find(x=>x.startsWith("TARGET=")).slice(7));
  for(const id of Object.values(target))if(!/^[a-f0-9-]{36}$/.test(id))throw new Error("Invalid race fixture");
  const call=(actor,operation,input)=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Affinity item race timeout"));},60000);
   child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Affinity item race failed: "+err));const row=out.split(/\r?\n/).find(x=>x.startsWith("RESULT="));if(!row)return reject(new Error("Missing item result"));resolve(JSON.parse(row.slice(7)));});
   child.stdin.end(`begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);select 'RESULT='||public.${operation}('${JSON.stringify(input)}'::jsonb)::text;select pg_sleep(0.5);commit;`);
  });
  const actors=['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005'];
  const added=await Promise.all([call(actors[0],'add_affinity_item',{affinityGroupId:target.g1,developmentObjectId:target.o1}),call(actors[1],'add_affinity_item',{affinityGroupId:target.g2,developmentObjectId:target.o2})]);
  const moved=await Promise.all([call(actors[0],'move_affinity_item',{itemId:added[0].id,targetGroupId:target.g2,position:1,expectedRevision:0}),call(actors[1],'move_affinity_item',{itemId:added[1].id,targetGroupId:target.g1,position:1,expectedRevision:0})]);
  for(let n=0;n<2;n++)if(JSON.stringify({...moved[n],affinity_group_id:added[n].affinity_group_id,position:added[n].position,move_revision:added[n].move_revision})!==JSON.stringify(added[n]))throw new Error("Item/source identity changed");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('count',count(*),'ordered',bool_and(position=1)) from public.affinity_group_items where affinity_group_id in('${target.g1}','${target.g2}');`]).trim());
  if(stats.count!==2||!stats.ordered)throw new Error("Corrupt concurrent item ordering");
  console.log("M11.3 independent adds/different-item moves/order/source identity PASS; AT-AFF-002 not claimed");
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
