import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Real concurrent requests in a disposable clone; no hosted credentials. */
export async function testActivityCompletionConcurrency({run,args,binary,childEnv,root}){
 const name="fici_activity_completion_concurrency",sessions=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const setup=readFileSync(join(root,"tests/integration/activity-completion.sql"),"utf8").split("-- M7.10 TEST CASES")[0];
  const out=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`\nselect 'CONTEXT='||jsonb_build_object('activity',(select id from completion_fixture where label='Lead'),'teamActivity',(select id from completion_fixture where label='Expiry'),'project',(select project from av_context where label='Team'))::text;commit;`);
  const ctx=JSON.parse(out.split(/\r?\n/).find(v=>v.startsWith("CONTEXT=")).slice(8));
  for(const v of Object.values(ctx))if(!/^[a-f0-9-]{36}$/.test(v))throw new Error("Invalid synthetic fixture UUID");
  const request=(sql,onReady)=>{const p=new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true,stdio:["pipe","pipe","pipe"]});
   let out="",err="",ready=false;const timer=setTimeout(()=>{child.kill();reject(new Error("Completion concurrency timeout"));},60_000);
   child.stdout.on("data",v=>{out+=v;if(!ready&&out.includes("LOCK_READY")){ready=true;onReady?.();}});child.stderr.on("data",v=>err+=v);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)reject(new Error("Completion concurrency failed: "+err));else resolve(out);});child.stdin.end(sql);
  });sessions.push(p);return p;};
  const claims=actor=>`set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);`;
  const sql=`begin;${claims("00000000-0000-4000-8000-000000006005")}select 'COMPLETE='||public.complete_activity('${ctx.activity}')::text;select pg_sleep(0.5);commit;`;
  const settled=await Promise.allSettled([request(sql),request(sql)]);for(const v of settled)if(v.status==="rejected")throw v.reason;
  const rows=settled.map(v=>JSON.parse(v.value.split(/\r?\n/).find(line=>line.startsWith("COMPLETE=")).slice(9)));
  if(JSON.stringify(rows[0])!==JSON.stringify(rows[1])||rows[0].status!=="completed"||!rows[0].completed_at)throw new Error("Concurrent retry returned inconsistent rows");
  const canonical=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select to_jsonb(a) from public.activity_instances a where id='${ctx.activity}';`]).trim());
  if(JSON.stringify(canonical)!==JSON.stringify(rows[0]))throw new Error("Concurrent completion changed canonical timestamp");
  console.log("M7.10 independent-session completion/one canonical timestamp/idempotency PASS");
  for(const authority of ['project','master']){
  // Expiry during a lock wait must not be rescued by statement-time RLS helpers.
  let unlock;const ready=new Promise(done=>unlock=done);
  const blocker=request(`begin;select pg_advisory_xact_lock(hashtextextended('fici-activity-complete:${ctx.teamActivity}',710));select 'LOCK_READY';select pg_sleep(5);commit;`,unlock);
  await Promise.race([ready,blocker.then(()=>{throw new Error("Lock fixture exited before readiness");})]);
  const actor=authority==='project'?'00000000-0000-4000-8000-000000006005':'00000000-0000-4000-8000-000000006002';
  const expirySql=authority==='project'?`update public.project_memberships set ends_at=clock_timestamp()+interval '2 seconds' where project_id='${ctx.project}' and user_id='${actor}' and status='active' returning 'EXPIRY='||to_json(ends_at)::text;`:`update public.role_assignments set ends_at=clock_timestamp()+interval '2 seconds' where user_id='${actor}' and cohort_id=(select cohort_id from public.activity_instances where id='${ctx.teamActivity}') and status='active' returning 'EXPIRY='||to_json(ends_at)::text;`;
  const expiryOut=run("psql",[...dbArgs,"-t","-A","-c",expirySql]);
  const expiry=JSON.parse(expiryOut.split(/\r?\n/).find(v=>v.startsWith('EXPIRY=')).slice(7));
  const denial=await request(`begin;${claims(actor)}do $$begin assert statement_timestamp()<'${expiry}'::timestamptz,'request must begin before authority expiry';begin perform public.complete_activity('${ctx.teamActivity}');raise exception 'Expired authority accepted';exception when insufficient_privilege then null;end;end $$;commit;`);
  await blocker;if(!denial.includes("COMMIT"))throw new Error("Expired request did not finish safely");
  if(run("psql",[...dbArgs,"-t","-A","-c",`select count(*) from public.activity_instances where id='${ctx.teamActivity}' and status='active' and completed_at is null;`]).trim()!=="1")throw new Error("Expired request inserted partial completion");
  }
  console.log("M7.10 timed authority expires during wait/Activity remains active PASS");
 }finally{await Promise.allSettled(sessions);run("psql",[...args,"-c",`drop database ${name}`]);}
}
