import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {votingCreationFixture} from "./voting-creation-fixture.mjs";
export async function testDecisionFinalizationConcurrency({run,args,binary,childEnv,root}) {
 const name="fici_decision_finalize_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try {
  const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0]+readFileSync(join(root,"tests/integration/decision-finalization-setup.sql"),"utf8");
  const output=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+"select 'RACE_TARGET='||label||'='||(payload#>>'{decision,id}') from df_drafts where label in ('Same race','Conflict race');commit;");
  const ids=Object.fromEntries(output.split(/\r?\n/).filter(x=>x.startsWith("RACE_TARGET=")).map(x=>x.slice(12).split("=")));
  if(Object.keys(ids).length!==2||Object.values(ids).some(x=>! /^[a-f0-9-]{36}$/.test(x)))throw new Error("Missing Decision race fixtures");
  const targets=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_object_agg(d.id,json_build_object('otherOption',(select id from public.decision_options where decision_id=d.id and label='Highest votes'),'otherObject',(select id from public.development_objects where project_id=d.project_id and object_type='PROBLEM' limit 1),'option',(select id from public.decision_options where decision_id=d.id and label='Human alternative'),'artifact',(select id from public.artifacts where project_id=d.project_id and title='Considered'),'object',(select id from public.development_objects where project_id=d.project_id and object_type='SOLUTION' limit 1))) from public.decisions d where d.id in ('${ids["Same race"]}','${ids["Conflict race"]}');`]).trim());
  const call=(id,outcome,actor="000000006009",alternative=false)=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Decision finalization concurrency timeout"));},60000);
   child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Decision concurrency failed: "+err));const line=out.split(/\r?\n/).find(x=>x.startsWith("RACE_RESULT="));if(!line)return reject(new Error("Missing Decision concurrency result"));resolve(JSON.parse(line.slice(12)));});
   child.stdin.end(`begin;set local application_name='m1019_finalize';set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-${actor}',true);do $$declare result jsonb;begin begin result:=public.finalize_decision(jsonb_build_object('decisionId','${id}','outcome','${outcome}','reasoning','Reasoning ${outcome}','selectedOptionId','${alternative?targets[id].otherOption:targets[id].option}','linkedArtifactIds',jsonb_build_array('${targets[id].artifact}'),'linkedObjectIds',jsonb_build_array('${alternative?targets[id].otherObject:targets[id].object}')));perform set_config('test.race_result',result::text,true);exception when serialization_failure then perform set_config('test.race_result','{"code":"CONFLICT"}',true);end;end $$;select 'RACE_RESULT='||current_setting('test.race_result');select pg_sleep(0.5);commit;`);
  });
  const same=await Promise.all([call(ids["Same race"],"One"),call(ids["Same race"],"One","000000006002")]);
  if(same.some(x=>x.status!=="FINALIZED")||JSON.stringify(same[0])!==JSON.stringify(same[1]))throw new Error("Identical finalization diverged");
  const different=await Promise.all([call(ids["Conflict race"],"Winner A"),call(ids["Conflict race"],"Winner B","000000006002",true)]);
  if(different.filter(x=>x.code==="CONFLICT").length!==1||different.filter(x=>x.status==="FINALIZED").length!==1)throw new Error("Conflicting finalization did not yield one winner");
  const winner=different.find(x=>x.status==="FINALIZED");
  if(winner.reasoning!==`Reasoning ${winner.outcome}`)throw new Error("Mixed finalization payload");
  const expectedOption=winner.outcome==="Winner A"?targets[winner.id].option:targets[winner.id].otherOption;
  const expectedObject=winner.outcome==="Winner A"?targets[winner.id].object:targets[winner.id].otherObject;
  const payloadStats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('selected',(select json_agg(id) from public.decision_options where decision_id='${winner.id}' and selected),'objects',(select json_agg(linked_entity_id) from public.decision_links where decision_id='${winner.id}' and linked_entity_type='DEVELOPMENT_OBJECT'),'connections',(select count(*) from pg_stat_activity where application_name='m1019_finalize'),'participantActor',(select user_id from public.decision_participants where decision_id='${winner.id}'),'eventActor',(select changed_by from public.change_log where entity_id='${winner.id}' and change_type='DECISION_FINALIZED'),'badTime',(select count(*) from public.change_log l join public.decisions d on d.id=l.entity_id where l.change_type='DECISION_FINALIZED' and l.created_at is distinct from d.decided_at));`]).trim());
  if(JSON.stringify(payloadStats.selected)!==JSON.stringify([expectedOption])||JSON.stringify(payloadStats.objects)!==JSON.stringify([expectedObject])||payloadStats.connections!==0||payloadStats.badTime!==0||payloadStats.participantActor!==`00000000-0000-4000-8000-${winner.outcome==="Winner A"?"000000006009":"000000006002"}`||payloadStats.eventActor!==payloadStats.participantActor)throw new Error("Finalization loser left selection/link/timestamp/connection corruption");
  console.log("M10.19 cross-actor complete conflicting payload/loser rollback/no connections PASS");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('events',(select count(*) from public.change_log where change_type='DECISION_FINALIZED'),'participants',(select count(*) from public.decision_participants),'selected',(select count(*) from public.decision_options where selected),'links',(select count(*) from public.decision_links),'finalized',(select count(*) from public.decisions where status='FINALIZED' and decided_at is not null));`]).trim());
  if(stats.events!==2||stats.participants!==2||stats.selected!==2||stats.links!==4||stats.finalized!==2)throw new Error("Concurrent finalization side effects diverged");
  console.log("M10.10 independent-session identical/conflicting finalization one timestamp/event/participant PASS");
 } finally {run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
