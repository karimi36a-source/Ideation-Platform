import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {votingCreationFixture} from "./voting-creation-fixture.mjs";
export async function testVotingCastConcurrency({run,args,binary,childEnv,root}){
 const name="fici_voting_cast_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
  const output=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`
reset role;
create temporary table race_target as select (payload#>>'{session,id}')::uuid id from vc_results where jsonb_array_length(payload->'options')=3;
grant select on race_target to authenticated;
insert into public.voting_options(voting_session_id,label,sequence) select id,'Fourth race choice',4 from race_target;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.open_voting_session(id) from race_target;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
reset role;
create temporary table race_options as select o.* from public.voting_options o join race_target s on s.id=o.voting_session_id;
grant select on race_options to authenticated;
set local role authenticated;
select public.cast_vote(voting_session_id,id,1) from race_options where sequence<=2;
reset role;
select 'CAST_TARGET='||json_build_object('session',(select id from race_target),'options',(select json_agg(id order by sequence) from race_options))::text;
commit;`);
  const line=output.split(/\r?\n/).find(x=>x.startsWith("CAST_TARGET="));
  if(!line)throw new Error("Missing vote race fixture");
  const fixture=JSON.parse(line.slice(12));
  if(![fixture.session,...fixture.options].every(x=>/^[a-f0-9-]{36}$/.test(x)))throw new Error("Invalid vote race IDs");
  const call=(option,actor="000000006005")=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Vote race timeout"));},60000);
   child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Vote concurrency failed: "+err));try{const result=out.split(/\r?\n/).find(x=>x.startsWith("CAST_RESULT="));if(!result)throw new Error("Missing race result");resolve(JSON.parse(result.slice(12)));}catch(e){reject(e);}});
   child.stdin.end(`begin;set local application_name='m1019_cast';set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-${actor}',true);
create temporary table result(payload jsonb);
do $$begin insert into result values(public.cast_vote('${fixture.session}','${option}',1));exception when unique_violation then insert into result values('{"conflict":true}');end $$;
select 'CAST_RESULT='||payload::text from result;select pg_sleep(0.5);commit;`);
  });
  const results=await Promise.all([call(fixture.options[2]),call(fixture.options[3])]);
  if(results.filter(x=>x.conflict===true).length!==1||results.filter(x=>x.value===1&&x.user_id==="00000000-0000-4000-8000-000000006005"&&x.revealed_at===null).length!==1)throw new Error("Vote budget race did not have one winner");
  const count=Number(run("psql",[...dbArgs,"-t","-A","-c",`select count(*) from public.votes where voting_session_id='${fixture.session}' and user_id='00000000-0000-4000-8000-000000006005';`]).trim());
  if(count!==3)throw new Error("Concurrent vote budget exceeded");
  // Fresh same-option contender: this different eligible voter has zero votes.
  const fresh=await Promise.all([call(fixture.options[0],"000000006004"),call(fixture.options[0],"000000006004")]);
  if(fresh.filter(x=>x.conflict===true).length!==1||fresh.filter(x=>x.value===1).length!==1)throw new Error("Fresh same-option race failed");
  const freshStats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('votes',(select count(*) from public.votes where voting_session_id='${fixture.session}' and user_id='00000000-0000-4000-8000-000000006004'),'status',(select status from public.voting_sessions where id='${fixture.session}'),'limit',(select vote_limit from public.voting_sessions where id='${fixture.session}'),'connections',(select count(*) from pg_stat_activity where application_name='m1019_cast'));`]).trim());
  if(freshStats.votes!==1||freshStats.status!=="OPEN"||freshStats.limit!==3||freshStats.connections!==0)throw new Error("Vote race leaked state or connections");
  console.log("M10.19 fresh same-option one winner/one row/budget and OPEN unchanged/no connections PASS");
  const retries=await Promise.all([call(fixture.options[0]),call(fixture.options[0])]);
  if(retries.some(x=>x.conflict!==true))throw new Error("Duplicate concurrency bypass");
  console.log("M10.4 independent-session budget race one winner/count three/duplicate conflict PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
