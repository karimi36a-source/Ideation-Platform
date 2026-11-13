import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {votingCreationFixture} from "./voting-creation-fixture.mjs";

export async function testVotingVoteCloseConcurrency({run,args,binary,childEnv,root,multiple=false}) {
 const name="fici_voting_vote_close_concurrency";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((value,index)=>args[index-1]==="-d"?name:value);
 try {
  const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
  const output=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.open_voting_session((payload#>>'{session,id}')::uuid) from vc_results where jsonb_array_length(payload->'options')=3;
reset role;
select 'RACE_TARGET='||json_build_object('session',payload#>>'{session,id}','option',payload#>>'{options,0,id}')::text from vc_results where jsonb_array_length(payload->'options')=3;
commit;`);
  const line=output.split(/\r?\n/).find(value=>value.startsWith("RACE_TARGET="));
  if(!line)throw new Error("Missing vote-close fixture");
  const fixture=JSON.parse(line.slice(12));
  if(![fixture.session,fixture.option].every(value=>/^[a-f0-9-]{36}$/.test(value)))throw new Error("Invalid vote-close fixture IDs");
  const call=(actor,body)=>new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});
   let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Vote-close race timeout"));},60000);
   child.stdout.on("data",value=>out+=value);child.stderr.on("data",value=>err+=value);
   child.on("error",error=>{clearTimeout(timer);reject(error);});
   child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error("Vote-close race failed: "+err));
    const result=out.split(/\r?\n/).find(value=>value.startsWith("RACE_RESULT="));
    if(!result)return reject(new Error("Missing vote-close result"));
    try{resolve(JSON.parse(result.slice(12)));}catch(error){reject(error);}
   });
   child.stdin.end(`begin;set local application_name='m1016_vote_close';set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-${actor}',true);
set local statement_timeout='50s';select pg_sleep(0.2);create temporary table race_result(payload jsonb);
${body}
select 'RACE_RESULT='||payload::text from race_result;select pg_sleep(0.2);commit;`);
  });
  const results=await Promise.all([
   call("000000006005",`do $$begin insert into race_result values(public.cast_vote('${fixture.session}','${fixture.option}',1));exception when object_not_in_prerequisite_state then insert into race_result values('{"closed":true}');end $$;`),
   ...(multiple?[call("000000006004",`do $$begin insert into race_result values(public.cast_vote('${fixture.session}','${fixture.option}',1));exception when object_not_in_prerequisite_state then insert into race_result values('{"closed":true}');end $$;`),call("000000006009",`do $$begin insert into race_result values(public.cast_vote('${fixture.session}','${fixture.option}',1));exception when object_not_in_prerequisite_state then insert into race_result values('{"closed":true}');end $$;`)]:[]),
   call("000000006002",`insert into race_result values(public.close_voting_session('${fixture.session}'));reset role;update race_result set payload=payload||jsonb_build_object('votesAtClose',(select count(*) from public.votes where voting_session_id='${fixture.session}'));`)
  ]);
  const close=results.at(-1);const votes=results.slice(0,-1);const vote=votes[0];
  if(close.status!=="CLOSED"||close.id!==fixture.session||!close.closed_at)throw new Error("Race failed to close canonical Session");
  if(vote.closed!==true&&(vote.value!==1||vote.user_id!=="00000000-0000-4000-8000-000000006005"))throw new Error("Invalid racing Vote result");
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object(
 'count',(select count(*) from public.votes where voting_session_id='${fixture.session}'),
 'events',(select count(*) from public.change_log where entity_id='${fixture.session}' and change_type='VOTING_SESSION_CLOSED'),
 'connections',(select count(*) from pg_stat_activity where application_name='m1016_vote_close'),
 'status',(select status from public.voting_sessions where id='${fixture.session}'));`]).trim());
  if(stats.count!==votes.filter(value=>value.closed!==true).length||stats.count!==close.votesAtClose||stats.events!==1||stats.connections!==0||stats.status!=="CLOSED")throw new Error("Vote-close race persisted invalid state");
  // Count is captured while the canonical close lock is held; every successful
  // cast must have committed before that lock could be acquired. Process output
  // is used only after COMMIT succeeds, never as evidence of a partial commit.
  console.log(`M10.19 ${multiple?"multiple-votes":"single-vote"} commit ordering: ${stats.count} votes committed before close; ${votes.filter(value=>value.closed===true).length} rejected after close`);
  const canonical=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('stamp',(select closed_at from public.voting_sessions where id='${fixture.session}'),'badTime',(select count(*) from public.change_log l join public.voting_sessions s on s.id=l.entity_id where s.id='${fixture.session}' and l.change_type='VOTING_SESSION_CLOSED' and l.created_at is distinct from s.closed_at));`]).trim());
  if(canonical.stamp!==close.closed_at||canonical.badTime!==0)throw new Error("Close timestamp diverged");
  const after=await call("000000006005",`do $$begin perform public.cast_vote('${fixture.session}','${fixture.option}',1);raise exception 'Vote after committed close' using errcode='XX000';exception when object_not_in_prerequisite_state then insert into race_result values('{"closed":true}');end $$;`);
  if(after.closed!==true)throw new Error("Post-close vote accepted");
  const remaining=Number(run("psql",[...dbArgs,"-t","-A","-c","select count(*) from pg_stat_activity where application_name='m1016_vote_close';"]).trim());
  if(remaining!==0)throw new Error("Post-close worker leaked connection");
  if(multiple)console.log("M10.19 multiple-vote close ordering/one timestamp/event/loser rollback/no connections PASS");
  console.log("M10.16 independent-session close-vs-vote valid commit order/one close event/no connections/post-close denial PASS");
 } finally {run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
