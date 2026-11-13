import {spawn} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export async function testAiArtifactRevisionConcurrency({run,args,binary,childEnv,root}){
 const name='fici_ai_artifact_revision',children=[];
 run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==='-d'?name:v);
 function request(sql){let ready;const signal=new Promise(r=>ready=r);const promise=new Promise((resolve,reject)=>{
  const child=spawn(binary('psql'),[...dbArgs,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out='',err='';
  const timer=setTimeout(()=>{child.kill();ready();reject(Error('AI Artifact revision concurrency timeout'));},60000);
  child.stdout.on('data',x=>{out+=x;if(out.includes('RACE_READY'))ready();});child.stderr.on('data',x=>err+=x);
  child.on('error',e=>{clearTimeout(timer);ready();reject(e);});child.on('close',code=>{clearTimeout(timer);ready();if(code===0)resolve(out);else reject(Error('AI Artifact revision race failed: '+err));});child.stdin.end(sql);
 });return {ready:signal,promise};}
 const parse=out=>{const line=out.split(/\r?\n/).map(x=>x.trim()).find(x=>x.startsWith('RESULT='));if(!line)throw Error('Missing canonical revision result');return JSON.parse(line.slice(7));};
 const quoted=v=>JSON.stringify(v).replaceAll("'","''");
 try{
  const read=file=>readFileSync(join(root,'tests/integration',file),'utf8');
  const setup=artifactReviewSecurityFixture(root)+read('activity-research-setup.sql')+read('ai-activity-availability.sql').split('-- No resource differentiation')[0]+read('ai-run-task.sql').split('-- RUNTIME TESTS')[0]+read('ai-conversion.sql').split('-- CONVERSION TESTS')[0]+read('ai-artifact-revision.sql').split('-- REVISION TESTS')[0];
  const input=parse(run('psql',[...dbArgs,'-t','-A','-f','-'],setup+"select 'RESULT='||pg_temp.ar_request('Race')::text;commit;"));
  const first=request(`begin;set local role service_role;select 'RESULT='||public.apply_ai_artifact_revision('${quoted(input)}'::jsonb)::text;select 'RACE_READY';select pg_sleep(0.5);commit;`);await first.ready;
  const second=request(`begin;set local role service_role;select 'RESULT='||public.apply_ai_artifact_revision('${quoted(input)}'::jsonb)::text;commit;`);
  const rows=(await Promise.all([first.promise,second.promise])).map(parse);if(rows[0].id!==rows[1].id||rows[0].version_number!==2)throw Error('Duplicate concurrent Draft');
  const a={...input,expectedVersionId:rows[0].id,expectedDraftRevision:0,idempotencyKey:'00000000-0000-4000-8000-000000141601',contentSnapshot:{human:'First edit'}};
  const b={...a,idempotencyKey:'00000000-0000-4000-8000-000000141602',contentSnapshot:{human:'Conflicting edit'}};
  const third=request(`begin;set local role service_role;select public.apply_ai_artifact_revision('${quoted(a)}'::jsonb);select 'RACE_READY';select pg_sleep(0.5);commit;`);await third.ready;
  const fourth=request(`begin;set local role service_role;do $$begin perform public.apply_ai_artifact_revision('${quoted(b)}'::jsonb);raise exception 'Lost-update conflict accepted';exception when unique_violation then null;end$$;commit;`);await Promise.all([third.promise,fourth.promise]);
  const retry=parse(await request(`begin;set local role service_role;select 'RESULT='||public.apply_ai_artifact_revision('${quoted(input)}'::jsonb)::text;commit;`).promise);
  if(retry.content_snapshot.human!=='First edit'||retry.draft_revision!==1)throw Error('Retry overwrote canonical Draft');
  const out=run('psql',[...dbArgs,'-t','-A','-c',`select count(*) from public.artifact_versions where artifact_id='${input.artifactId}';select count(*) from public.audit_events where event_type='AI_ARTIFACT_DRAFT_APPLIED';`]).trim().split(/\r?\n/);
  if(out.join(',')!=='2,2')throw Error('Duplicate Version or provenance');
  console.log('M14.16 independent-session exact-retry/Draft-CAS/conflict/numbering/provenance PASS');
 }finally{
  for(const child of children)if(child.exitCode===null)child.kill();
  run('psql',[...args,'-c',`select pg_terminate_backend(pid) from pg_stat_activity where datname='${name}'`]);
  run('psql',[...args,'-c',`drop database ${name}`]);
 }
}
