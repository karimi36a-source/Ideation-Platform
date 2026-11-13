import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {votingCreationFixture} from "./voting-creation-fixture.mjs";
export async function testVotingCloseConcurrency({run,args,binary,childEnv,root}){
 const name="fici_voting_close_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
  const output=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+"\nselect public.open_voting_session((payload#>>'{session,id}')::uuid) from vc_results where payload#>>'{session,activity_instance_id}'=(select id::text from vc_activities where n=2);reset role;select 'CLOSE_TARGET='||(payload#>>'{session,id}') from vc_results where payload#>>'{session,activity_instance_id}'=(select id::text from vc_activities where n=2) limit 1;commit;");
  const id=output.split(/\r?\n/).find(x=>x.startsWith("CLOSE_TARGET="))?.slice(13);
  if(!/^[a-f0-9-]{36}$/.test(id??""))throw new Error("Missing voting concurrency fixture");
  const call=actor=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Voting concurrency timeout"));},60000);
   child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Voting open concurrency failed: "+err));try{const line=out.split(/\r?\n/).find(x=>x.startsWith("CLOSE_RESULT="));if(!line)throw new Error("Missing voting result");resolve(JSON.parse(line.slice(13)));}catch(e){reject(e);}});
   child.stdin.end(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-${actor}',true);select 'CLOSE_RESULT='||public.close_voting_session('${id}')::text;select pg_sleep(0.5);commit;`);
  });
  const rows=await Promise.all([call("000000006002"),call("000000006009")]);
  if(rows.some(x=>x.id!==id||x.status!=="CLOSED"||!x.opened_at||!x.closed_at)||JSON.stringify(rows[0])!==JSON.stringify(rows[1]))throw new Error("Concurrent opens changed canonical state/timestamp");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('events',(select count(*) from public.change_log where entity_id='${id}' and change_type='VOTING_SESSION_CLOSED'),'votes',(select count(*) from public.votes),'options',(select count(*) from public.voting_options where voting_session_id='${id}'));`]).trim());
  if(stats.events!==1||stats.votes!==0||stats.options!==2)throw new Error("Concurrent open side effects invalid");
  console.log("M10.6 independent-session close one timestamp/one event/canonical retry PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
