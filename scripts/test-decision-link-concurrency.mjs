import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {votingCreationFixture} from "./voting-creation-fixture.mjs";
export async function testDecisionLinkConcurrency({run,args,binary,childEnv,root}) {
 const name="fici_decision_link_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try {
  const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0]+readFileSync(join(root,"tests/integration/decision-finalization-setup.sql"),"utf8");
  const output=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+"select 'RACE_TARGET='||label||'='||(payload#>>'{decision,id}') from df_drafts where label in ('Same race','Conflict race');commit;");
  const ids=Object.fromEntries(output.split(/\r?\n/).filter(x=>x.startsWith("RACE_TARGET=")).map(x=>x.slice(12).split("=")));
  if(Object.keys(ids).length!==2||Object.values(ids).some(x=>! /^[a-f0-9-]{36}$/.test(x)))throw new Error("Missing Decision race fixtures");
  const targets=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_object_agg(d.id,json_build_object('option',(select id from public.decision_options where decision_id=d.id and label='Human alternative'),'artifact',(select id from public.artifacts where project_id=d.project_id and title='Considered'),'object',(select id from public.development_objects where project_id=d.project_id and object_type='SOLUTION' limit 1))) from public.decisions d where d.id in ('${ids["Same race"]}','${ids["Conflict race"]}');`]).trim());
  const call=id=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Decision link concurrency timeout"));},60000);
   child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Decision link concurrency failed: "+err));const line=out.split(/\r?\n/).find(x=>x.startsWith("RACE_RESULT="));if(!line)return reject(new Error("Missing link result"));resolve(JSON.parse(line.slice(12)));});
   child.stdin.end(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);select 'RACE_RESULT='||public.link_decision_entity(jsonb_build_object('decisionId','${id}','linkedEntityType','ARTIFACT','linkedEntityId','${targets[id].artifact}','relationshipType','CONSIDERED_IN_DECISION'))::text;select pg_sleep(0.5);commit;`);
  });
  const same=await Promise.all([call(ids["Same race"]),call(ids["Same race"])]);
  if(same.some(x=>x.linked_entity_type!=="ARTIFACT")||JSON.stringify(same[0])!==JSON.stringify(same[1]))throw new Error("Identical links diverged");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('events',(select count(*) from public.change_log where change_type='DECISION_LINK_ADDED'),'links',(select count(*) from public.decision_links));`]).trim());
  if(stats.events!==1||stats.links!==1)throw new Error("Duplicate link race created duplicate state");
  console.log("M10.11 independent-session concurrent duplicate one canonical link/event PASS");
 } finally {run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
