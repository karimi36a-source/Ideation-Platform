import {spawn} from 'node:child_process';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
/** One canonical event per server attempt, including concurrent logging retries. */
export async function testAiUsageEvents({run,args,binary,childEnv,root}){
 const name='fici_ai_usage_concurrency',children=[];
 run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==='-d'?name:v);
 const actor="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);reset role;";
 function request(sql){
  let signal;const ready=new Promise(resolve=>signal=resolve);
  const promise=new Promise((resolve,reject)=>{
   const child=spawn(binary('psql'),[...dbArgs,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out='',err='';
   const timer=setTimeout(()=>{child.kill();signal();reject(new Error('Usage logging race timeout'));},60000);
   child.stdout.on('data',x=>{out+=x;if(out.includes('RACE_READY'))signal();});child.stderr.on('data',x=>err+=x);
   child.on('error',e=>{clearTimeout(timer);signal();reject(e);});child.on('close',code=>{clearTimeout(timer);signal();if(code===0)resolve(out);else reject(new Error('Usage logging race failed: '+err));});
   child.stdin.end(sql);
  });return {promise,ready};
 }
 const parse=(out,marker)=>{const line=out.split(/\r?\n/).map(x=>x.trim()).find(x=>x.startsWith(marker));if(!line)throw new Error('Missing usage result');return JSON.parse(line.slice(marker.length));};
 try{
  const setup=run('psql',[...dbArgs,'-t','-A','-f','-'],artifactReviewSecurityFixture(root)+"\nselect 'USAGE_CONTEXT='||payload::text from logged_projects where label='Team';commit;");
  const ctx=parse(setup,'USAGE_CONTEXT=');
  for(const key of ['id','primary_workspace_id'])if(!/^[a-f0-9-]{36}$/.test(ctx[key]))throw new Error('Invalid fixture identity');
  const input={attemptId:'00000000-0000-4000-8000-000000094401',projectId:ctx.id,workspaceId:ctx.primary_workspace_id,taskType:'USAGE_FIXTURE',modelProfile:'AI_STANDARD',inputUsage:10,outputUsage:2,estimatedCost:null,latencyMs:50,successFailure:'FAILURE'};
  const body=JSON.stringify(input);
  const first=request(`begin;${actor}select 'USAGE_RESULT='||private.record_ai_usage_event('${body}'::jsonb)::text;select 'RACE_READY';select pg_sleep(0.5);commit;`);
  await first.ready;
  const second=request(`begin;${actor}select 'USAGE_RESULT='||private.record_ai_usage_event('${body}'::jsonb)::text;commit;`);
  const results=(await Promise.all([first.promise,second.promise])).map(out=>parse(out,'USAGE_RESULT='));
  if(JSON.stringify(results[0])!==JSON.stringify(results[1])||results[0].id!==input.attemptId)throw new Error('Logging retries changed canonical event');
  const other=JSON.stringify({...input,attemptId:'00000000-0000-4000-8000-000000094402',successFailure:'SUCCESS'});
  run('psql',[...dbArgs,'-f','-'],`begin;${actor}select private.record_ai_usage_event('${other}'::jsonb);commit;`);
  const stats=JSON.parse(run('psql',[...dbArgs,'-t','-A','-c',"select json_build_object('events',(select count(*) from public.ai_usage_events),'outputs',(select count(*) from public.ai_outputs));"]).trim());
  if(stats.events!==2||stats.outputs!==0)throw new Error('Usage attempt count or no-output boundary failed');
  console.log('M14.4 independent-session same-attempt logging idempotency/new-attempt separation/no-AI-output PASS');
 }finally{
  for(const child of children)if(child.exitCode===null)child.kill();
  run('psql',[...args,'-c',`drop database ${name} with (force)`]);
 }
}
