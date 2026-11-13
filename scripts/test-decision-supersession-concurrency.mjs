import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {votingCreationFixture} from "./voting-creation-fixture.mjs";
export async function testDecisionSupersessionConcurrency({run,args,binary,childEnv,root}) {
 const name="fici_decision_supersession_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try {
  const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0]+readFileSync(join(root,"tests/integration/decision-finalization-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/decision-supersession-setup.sql"),"utf8");
  const out=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+"select 'RACE_IDS='||json_object_agg(label,id)::text from sd_cases where label like 'Race%';commit;");
  const line=out.split(/\r?\n/).find(x=>x.startsWith("RACE_IDS="));if(!line)throw new Error("Missing supersession fixtures");
  const ids=JSON.parse(line.slice(9));
  if(Object.values(ids).some(x=>! /^[a-f0-9-]{36}$/.test(x)))throw new Error("Invalid race fixture UUID");
  const before=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_object_agg(id,to_jsonb(d)) from public.decisions d where id in (${Object.values(ids).map(id=>`'${id}'`).join(",")});`]).trim());
  const call=(older,newer,actor="000000006009")=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let output="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Supersession concurrency timeout"));},60000);
   child.stdout.on("data",x=>output+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Supersession worker failed: "+err));const item=output.split(/\r?\n/).find(x=>x.startsWith("RACE_RESULT="));if(!item)return reject(new Error("Missing race result"));resolve(JSON.parse(item.slice(12)));});
   // Catch only the approved conflict; all unexpected SQL errors fail the worker.
   child.stdin.end(`begin;set local application_name='m1019_supersede';set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-${actor}',true);create function pg_temp.race_call() returns jsonb language plpgsql as $$begin return public.supersede_decision(jsonb_build_object('oldDecisionId','${ids[older]}','newDecisionId','${ids[newer]}'));exception when serialization_failure then return jsonb_build_object('conflict',true);end $$;select 'RACE_RESULT='||pg_temp.race_call()::text;select pg_sleep(0.5);commit;`);
  });
  const same=await Promise.all([call("Race1Old","Race1New"),call("Race1Old","Race1New","000000006002")]);
  if(same[0].conflict||JSON.stringify(same[0])!==JSON.stringify(same[1]))throw new Error("Identical supersessions diverged");
  for(const pair of [[["Race2Old","Race2NewA"],["Race2Old","Race2NewB"]],[["Race3OldA","Race3New"],["Race3OldB","Race3New"]]]) {
   const result=await Promise.all(pair.map(([a,b],index)=>call(a,b,index===0?"000000006009":"000000006002")));
   if(result.filter(x=>x.conflict).length!==1||result.filter(x=>x.relationship_type==="SUPERSEDES").length!==1)throw new Error("Competing supersessions did not produce one success/one conflict");
  }
  const after=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_object_agg(id,to_jsonb(d)) from public.decisions d where id in (${Object.values(ids).map(id=>`'${id}'`).join(",")});`]).trim());
  for(const id of Object.values(ids)) {
   const expected={...before[id],status:after[id].status};
   if(JSON.stringify(expected)!==JSON.stringify(after[id])||!["FINALIZED","SUPERSEDED"].includes(after[id].status))throw new Error("Supersession rewrote history");
  }
  const broken=Number(run("psql",[...dbArgs,"-t","-A","-c",`select count(*) from public.decision_links l join public.decisions old on old.id=l.linked_entity_id join public.decisions newer on newer.id=l.decision_id where l.relationship_type='SUPERSEDES' and (old.status<>'SUPERSEDED' or newer.status<>'FINALIZED' or (select count(*) from public.change_log c where c.entity_id=old.id and c.related_decision_id=newer.id and c.change_type='DECISION_SUPERSEDED')<>1);`]).trim());
  if(broken!==0)throw new Error("Supersession winning relationship/status/event mismatch");
  const clean=Number(run("psql",[...dbArgs,"-t","-A","-c","select count(*) from pg_stat_activity where application_name='m1019_supersede';"]).trim());
  if(clean!==0)throw new Error("Supersession connection leak");
  console.log("M10.19 cross-actor supersession loser/history/timestamps/no connections PASS");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c","select json_build_object('links',(select count(*) from public.decision_links where linked_entity_type='DECISION'),'events',(select count(*) from public.change_log where change_type='DECISION_SUPERSEDED'),'superseded',(select count(*) from public.decisions where status='SUPERSEDED')); "]).trim());
  if(stats.links!==3||stats.events!==3||stats.superseded!==3)throw new Error("Race corrupted linear history");
  console.log("M10.12 independent-session identical/competing-successor/competing-predecessor PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
