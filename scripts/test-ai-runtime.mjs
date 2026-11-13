import {spawn} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export async function testAiRuntimeConcurrency({run,args,binary,childEnv,root}){
 const name='fici_ai_runtime_concurrency',children=[];
 run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==='-d'?name:v);
 function request(sql){let ready;const signal=new Promise(r=>ready=r);const promise=new Promise((resolve,reject)=>{
  const child=spawn(binary('psql'),[...dbArgs,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out='',err='';
  const timer=setTimeout(()=>{child.kill();ready();reject(Error('AI operation concurrency timeout'));},60000);
  child.stdout.on('data',x=>{out+=x;if(out.includes('RACE_READY'))ready();});child.stderr.on('data',x=>err+=x);
  child.on('error',e=>{clearTimeout(timer);ready();reject(e);});child.on('close',code=>{clearTimeout(timer);ready();if(code===0)resolve(out);else reject(Error('AI operation race failed: '+err));});child.stdin.end(sql);
 });return {ready:signal,promise};}
 const parse=(out,label)=>{const line=out.split(/\r?\n/).map(x=>x.trim()).find(x=>x.startsWith(label));if(!line)throw Error('Missing runtime race result');return JSON.parse(line.slice(label.length));};
 try{
  const setup=artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-activity-availability.sql'),'utf8').split('-- No resource differentiation')[0]+readFileSync(join(root,'tests/integration/ai-run-task.sql'),'utf8').split('-- RUNTIME TESTS')[0];
  const out=run('psql',[...dbArgs,'-t','-A','-f','-'],setup+`set local role service_role;insert into runtime_ops values('Race',public.begin_ai_task_operation(pg_temp.runtime_req('Race')));select public.record_ai_task_attempt(pg_temp.runtime_attempt('Race'));select 'RUNTIME_SAVE='||pg_temp.runtime_save('Race')::text;select 'RUNTIME_BEGIN='||pg_temp.runtime_req('BeginRace')::text;commit;`);
  const save=JSON.stringify(parse(out,'RUNTIME_SAVE=')).replaceAll("'","''"),begin=JSON.stringify(parse(out,'RUNTIME_BEGIN=')).replaceAll("'","''");
  const first=request(`begin;set local role service_role;select 'SAVED='||to_jsonb(public.save_ai_task_result('${save}'::jsonb))::text;select 'RACE_READY';select pg_sleep(0.5);commit;`);
  await first.ready;
  const second=request(`begin;set local role service_role;select 'SAVED='||to_jsonb(public.save_ai_task_result('${save}'::jsonb))::text;commit;`);
  const values=(await Promise.all([first.promise,second.promise])).map(x=>parse(x,'SAVED='));if(values[0]!==values[1])throw Error('Concurrent result identity changed');
  const a=request(`begin;set local role service_role;select public.begin_ai_task_operation('${begin}'::jsonb);select 'RACE_READY';select pg_sleep(0.5);commit;`);await a.ready;
  const b=request(`begin;set local role service_role;do $$begin perform public.begin_ai_task_operation('${begin}'::jsonb);raise exception 'Duplicate begin accepted';exception when lock_not_available then null;end$$;commit;`);await Promise.all([a.promise,b.promise]);
  const counts=JSON.parse(run('psql',[...dbArgs,'-t','-A','-c',`select json_build_object('outputs',(select count(*) from public.ai_outputs),'refs',(select count(*) from public.ai_context_references),'usage',(select count(*) from public.ai_usage_events),'running',(select count(*) from public.ai_task_operations where status='running'));`]).trim());
  if(counts.outputs!==1||counts.refs!==1||counts.usage!==1||counts.running!==1)throw Error('Concurrent output/provenance/usage count mismatch');
  console.log('M14.11 independent-session begin serialization/atomic-save idempotency/exact-result/exact-provenance PASS');
  const dispositionSession="begin;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);set local role authenticated;";
  const firstDisposition=request(dispositionSession+`select public.set_ai_output_disposition('${values[0]}','ACCEPT_AS_CANDIDATE',0);select 'RACE_READY';select pg_sleep(0.5);commit;`);
  await firstDisposition.ready;
  const conflictingDisposition=request(dispositionSession+`do $$begin perform public.set_ai_output_disposition('${values[0]}','REJECTED',0);raise exception 'Lost update';exception when serialization_failure then null;end$$;commit;`);
  await Promise.all([firstDisposition.promise,conflictingDisposition.promise]);
  const sameA=request(dispositionSession+`select public.set_ai_output_disposition('${values[0]}','MODIFIED',1);select 'RACE_READY';select pg_sleep(0.5);commit;`);await sameA.ready;
  const sameB=request(dispositionSession+`select public.set_ai_output_disposition('${values[0]}','MODIFIED',1);commit;`);await Promise.all([sameA.promise,sameB.promise]);
  const dispositionState=JSON.parse(run('psql',[...dbArgs,'-t','-A','-c',`select json_build_object('revision',(select disposition_revision from public.ai_outputs where id='${values[0]}'),'state',(select disposition from public.ai_outputs where id='${values[0]}'),'audits',(select count(*) from public.change_log where entity_id='${values[0]}' and change_type::text='AI_OUTPUT_DISPOSITION_CHANGED'));`]).trim());
  if(dispositionState.revision!==2||dispositionState.state!=='MODIFIED'||dispositionState.audits!==2)throw Error('Disposition race/audit mismatch');
  console.log('M14.14 independent-session conflicting CAS/exact-retry/no-lost-update/atomic-audit PASS');
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}


