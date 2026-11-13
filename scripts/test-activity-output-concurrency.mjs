import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Real concurrent requests in a disposable clone; no hosted credentials. */
export async function testActivityOutputConcurrency({run,args,binary,childEnv,root}){
 const name="fici_activity_output_concurrency",sessions=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  const setup=readFileSync(join(root,"tests/integration/activity-output-operation.sql"),"utf8").split("-- M7.9 TEST CASES")[0];
  const out=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`\nselect 'CONTEXT='||jsonb_build_object('activity',f.id,'object',o.payload->>'id','teamActivity',(select id from resumed_fixture where label='Team'),'teamObject',(select payload->>'id' from logged_objects where label='Activity Team'),'project',(select project from av_context where label='Team'))::text from resumed_fixture f cross join logged_objects o where f.label='Personal' and o.label='Solution';commit;`);
  const ctx=JSON.parse(out.split(/\r?\n/).find(v=>v.startsWith("CONTEXT=")).slice(8));
  for(const v of Object.values(ctx))if(!/^[a-f0-9-]{36}$/.test(v))throw new Error("Invalid synthetic fixture UUID");
  const request=(sql,onReady)=>{const p=new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true,stdio:["pipe","pipe","pipe"]});
   let out="",err="",ready=false;const timer=setTimeout(()=>{child.kill();reject(new Error("Output concurrency timeout"));},60_000);
   child.stdout.on("data",v=>{out+=v;if(!ready&&out.includes("LOCK_READY")){ready=true;onReady?.();}});child.stderr.on("data",v=>err+=v);
   child.on("error",e=>{clearTimeout(timer);reject(e);});child.on("close",code=>{clearTimeout(timer);if(code!==0)reject(new Error("Output concurrency failed: "+err));else resolve(out);});child.stdin.end(sql);
  });sessions.push(p);return p;};
  const claims=actor=>`set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);`;
  const sql=`begin;${claims("00000000-0000-4000-8000-000000006004")}select 'OUTPUT='||public.add_activity_output('${ctx.activity}','${ctx.object}')::text;select pg_sleep(0.5);commit;`;
  const settled=await Promise.allSettled([request(sql),request(sql)]);for(const v of settled)if(v.status==="rejected")throw v.reason;
  const rows=settled.map(v=>JSON.parse(v.value.split(/\r?\n/).find(line=>line.startsWith("OUTPUT=")).slice(7)));
  if(JSON.stringify(rows[0])!==JSON.stringify(rows[1])||rows[0].output_type!=="development_object")throw new Error("Concurrent retry returned inconsistent rows");
  const count=run("psql",[...dbArgs,"-t","-A","-c",`select count(*) from public.activity_outputs where activity_instance_id='${ctx.activity}' and development_object_id='${ctx.object}';`]).trim();
  if(count!=="1")throw new Error("Concurrent retry created duplicate output links");
  console.log("M7.9 independent-session identical retries/one canonical output PASS");
  // Expiry during a lock wait must not be rescued by statement-time RLS helpers.
  let unlock;const ready=new Promise(done=>unlock=done);
  const blocker=request(`begin;select pg_advisory_xact_lock(hashtextextended('fici-activity-output:${ctx.teamActivity}:${ctx.teamObject}',79));select 'LOCK_READY';select pg_sleep(5);commit;`,unlock);
  await Promise.race([ready,blocker.then(()=>{throw new Error("Lock fixture exited before readiness");})]);
  const expiryOut=run("psql",[...dbArgs,"-t","-A","-c",`update public.project_memberships set ends_at=clock_timestamp()+interval '2 seconds' where project_id='${ctx.project}' and user_id='00000000-0000-4000-8000-000000006004' and status='active' returning 'EXPIRY='||to_json(ends_at)::text;`]);
  const expiry=JSON.parse(expiryOut.split(/\r?\n/).find(v=>v.startsWith('EXPIRY=')).slice(7));
  const denial=await request(`begin;${claims("00000000-0000-4000-8000-000000006004")}do $$begin assert statement_timestamp()<'${expiry}'::timestamptz,'request must begin before authority expiry';begin perform public.add_activity_output('${ctx.teamActivity}','${ctx.teamObject}');raise exception 'Expired authority accepted';exception when insufficient_privilege then null;end;end $$;commit;`);
  await blocker;if(!denial.includes("COMMIT"))throw new Error("Expired request did not finish safely");
  if(run("psql",[...dbArgs,"-t","-A","-c",`select count(*) from public.activity_outputs where activity_instance_id='${ctx.teamActivity}';`]).trim()!=="0")throw new Error("Expired request inserted partial output");
  console.log("M7.9 timed Project authority expires during wait/no partial writes PASS");
 }finally{await Promise.allSettled(sessions);run("psql",[...args,"-c",`drop database ${name}`]);}
}
