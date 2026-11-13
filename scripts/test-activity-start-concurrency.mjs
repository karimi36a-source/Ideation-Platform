import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";

/** Two real PostgreSQL sessions in a clone of the disposable test database.
 * Never accepts a hosted URL or credentials; all fixtures are synthetic. */
export async function testActivityStartConcurrency({run,args,binary,childEnv,root}){
 const name="fici_activity_start_concurrency";
 const sessions=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((value,index)=>args[index-1]==="-d"?name:value);
 try{
  const setup=readFileSync(join(root,"tests/integration/activity-start.sql"),"utf8").split("-- M7.6 TEST CASES")[0];
  const output=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`\nselect 'CONTEXT='||to_jsonb(x)::text from av_context x where label='Team';\ncommit;`);
  const line=output.split(/\r?\n/).find(v=>v.startsWith("CONTEXT="));
  if(!line)throw new Error("Missing concurrency fixture context");
  const ctx=JSON.parse(line.slice(8));
  for(const field of ["definition","project","workspace","team"]){if(!/^[a-f0-9-]{36}$/.test(ctx[field]))throw new Error("Invalid fixture UUID");}
  const call=`public.start_activity('${ctx.definition}','${ctx.project}','${ctx.workspace}','${ctx.team}')`;
  const claims="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);";
  function request(sqlOverride,onReady){const session=new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true,stdio:["pipe","pipe","pipe"]});
   let out="",err="";const timer=setTimeout(()=>{child.kill();reject(new Error("Concurrency session timed out"));},60_000);
   let ready=false;
   child.stdout.on("data",v=>{out+=v;if(!ready&&out.includes("LOCK_READY")){ready=true;onReady?.();}});child.stderr.on("data",v=>{err+=v;});
   child.on("error",error=>{clearTimeout(timer);reject(error);});
   child.on("close",code=>{clearTimeout(timer);if(code!==0)return reject(new Error(`Concurrency session failed: ${err}`));
    try{const result=out.split(/\r?\n/).find(v=>v.startsWith("START_RESULT="));if(!result)throw new Error("Missing start result");resolve(JSON.parse(result.slice(13)));}catch(error){reject(error);}
   });
   // Holding the first transaction after start forces the other session to wait
   // on its context lock and then observe the committed nonterminal execution.
   child.stdin.end(sqlOverride??`begin;${claims}select 'START_RESULT='||${call}::text;select pg_sleep(1);commit;`);
  });sessions.push(session);return session;}
  const settled=await Promise.allSettled([request(),request()]);
  for(const item of settled)if(item.status==="rejected")throw item.reason;
  const results=settled.map(item=>item.value);
  const success=results.filter(v=>v.started===true),denied=results.filter(v=>v.started===false);
  if(success.length!==1||denied.length!==1||denied[0].reasonCode!=="ACTIVE_INSTANCE_EXISTS"||denied[0].existingActiveInstanceId!==success[0].activity.id)throw new Error("Concurrent duplicate start was not safely serialized");
  const counts=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('instances',(select count(*) from public.activity_instances),'participants',(select count(*) from public.activity_participants),'actor',(select started_by from public.activity_instances),'participant',(select user_id from public.activity_participants));`]).trim());
  if(counts.instances!==1||counts.participants!==1||counts.actor!=="00000000-0000-4000-8000-000000006005"||counts.participant!==counts.actor)throw new Error("Concurrent starts left partial or duplicate state");
  const isolation=run("psql",[...dbArgs,"-t","-A","-f","-"],`begin isolation level repeatable read;${claims}select 'ISOLATION='||public.start_activity('00000000-0000-4000-8000-000000750804','${ctx.project}','${ctx.workspace}','${ctx.team}')::text;commit;`);
  const isolated=JSON.parse(isolation.split(/\r?\n/).find(v=>v.startsWith("ISOLATION=")).slice(10));
  if(isolated.started!==false||isolated.reasonCode!=="INVALID_CONTEXT")throw new Error("Stale-snapshot isolation must fail closed");
  // Natural expiry while waiting cannot retain start authority. A real second
  // session holds precisely the lock used by the RPC, without creating an Activity.
  const expiryDefinition="00000000-0000-4000-8000-000000750804";
  const lockKey=`fici-activity-start:${expiryDefinition}:${ctx.project}:${ctx.workspace}:${ctx.team}`;
  let signalReady;const ready=new Promise(resolve=>{signalReady=resolve;});
  const blocker=request(`begin;select pg_advisory_xact_lock(hashtextextended('${lockKey}',76));select 'LOCK_READY';select pg_sleep(5);select 'START_RESULT={"fixture":true}';commit;`,()=>signalReady());
  await Promise.race([ready,blocker.then(()=>{throw new Error("Lock fixture exited before readiness");})]);
  const expirationOutput=run("psql",[...dbArgs,"-t","-A","-c",`update public.role_assignments set ends_at=clock_timestamp()+interval '2 seconds' where user_id='00000000-0000-4000-8000-000000006002' and cohort_id=(select cohort_id from public.teams where id='${ctx.team}') and status='active' returning 'EXPIRY='||to_json(ends_at)::text;`]);
  const expiration=JSON.parse(expirationOutput.split(/\r?\n/).find(v=>v.startsWith("EXPIRY=")).slice(7));
  const expiring=request(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select 'START_RESULT='||jsonb_build_object('observedAt',statement_timestamp(),'result',public.start_activity('${expiryDefinition}','${ctx.project}','${ctx.workspace}','${ctx.team}'))::text;commit;`);
  const expiryResults=await Promise.allSettled([blocker,expiring]);
  for(const item of expiryResults)if(item.status==="rejected")throw item.reason;
  const waiting=expiryResults[1].value;
  if(Date.parse(waiting.observedAt)>=Date.parse(expiration)||waiting.result.started!==false||waiting.result.reasonCode!=="INVALID_CONTEXT")throw new Error("Master expiry while waiting was not enforced at recorded start time");
  const remaining=run("psql",[...dbArgs,"-t","-A","-c","select count(*) from public.activity_instances;"]).trim();
  if(remaining!=="1")throw new Error("Expired waiting starter created an orphan execution");
  console.log("M7.6 role expiry while waiting denies start without partial state PASS");
  console.log("M7.6 two-session concurrency/READ COMMITTED/one instance/one initiator PASS");
 }finally{await Promise.allSettled(sessions);run("psql",[...args,"-c",`drop database ${name}`]);}
}
