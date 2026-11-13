import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {votingCreationFixture} from "./voting-creation-fixture.mjs";
export async function testVotingRevealConcurrency({run,args,binary,childEnv,root}){
 const name="fici_voting_reveal_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
  const output=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`
reset role;
create temporary table race_reveal as select (payload#>>'{session,id}')::uuid id from vc_results where payload#>>'{session,activity_instance_id}'=(select id::text from vc_activities where n=2) and jsonb_array_length(payload->'options')=2;
grant select on race_reveal to authenticated;
update public.voting_sessions set vote_limit=3 where id=(select id from race_reveal);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.open_voting_session(id) from race_reveal;
reset role;
create temporary table race_option as select o.* from public.voting_options o join race_reveal s on s.id=o.voting_session_id where sequence=1;
grant select on race_option to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.cast_vote(voting_session_id,id,1) from race_option;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.cast_vote(voting_session_id,id,1) from race_option;
reset role;
update public.voting_sessions set status='CLOSED',closed_at=clock_timestamp() where id=(select id from race_reveal);
select 'REVEAL_TARGET='||id from race_reveal;commit;`);
  const id=output.split(/\r?\n/).find(x=>x.startsWith("REVEAL_TARGET="))?.slice(14);
  if(!/^[a-f0-9-]{36}$/.test(id??""))throw new Error("Missing voting concurrency fixture");
  const call=actor=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Voting concurrency timeout"));},60000);
   child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Voting open concurrency failed: "+err));try{const line=out.split(/\r?\n/).find(x=>x.startsWith("REVEAL_RESULT="));if(!line)throw new Error("Missing voting result");resolve(JSON.parse(line.slice(14)));}catch(e){reject(e);}});
   child.stdin.end(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-${actor}',true);select 'REVEAL_RESULT='||public.reveal_voting_session('${id}')::text;select pg_sleep(0.5);commit;`);
  });
  const rows=await Promise.all([call("000000006002"),call("000000006009")]);
  if(rows.some(x=>x.id!==id||x.status!=="CLOSED"||!x.opened_at||!x.closed_at)||JSON.stringify(rows[0])!==JSON.stringify(rows[1]))throw new Error("Concurrent opens changed canonical state/timestamp");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('events',(select count(*) from public.change_log where entity_id='${id}' and change_type='VOTING_SESSION_REVEALED'),'votes',(select count(*) from public.votes),'options',(select count(*) from public.voting_options where voting_session_id='${id}'),'stamps',(select count(distinct revealed_at) from public.votes where voting_session_id='${id}'),'shown',(select count(revealed_at) from public.votes where voting_session_id='${id}'));`]).trim());
  if(stats.events!==1||stats.votes!==2||stats.options!==2||stats.stamps!==1||stats.shown!==2)throw new Error("Concurrent open side effects invalid");
  console.log("M10.5 independent-session reveal one timestamp/one event/canonical retry PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
