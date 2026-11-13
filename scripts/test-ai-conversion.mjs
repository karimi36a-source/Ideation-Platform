import {spawn} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export async function testAiConversionConcurrency({run,args,binary,childEnv,root}){
 const name='fici_ai_conversion_concurrency',children=[];
 run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==='-d'?name:v);
 function request(sql){let ready;const signal=new Promise(r=>ready=r);const promise=new Promise((resolve,reject)=>{
  const child=spawn(binary('psql'),[...dbArgs,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out='',err='';
  const timer=setTimeout(()=>{child.kill();ready();reject(Error('AI conversion concurrency timeout'));},60000);
  child.stdout.on('data',x=>{out+=x;if(out.includes('RACE_READY'))ready();});child.stderr.on('data',x=>err+=x);
  child.on('error',e=>{clearTimeout(timer);ready();reject(e);});child.on('close',code=>{clearTimeout(timer);ready();if(code===0)resolve(out);else reject(Error('AI conversion race failed: '+err));});child.stdin.end(sql);
 });return {ready:signal,promise};}
 const parse=(out,label)=>{const line=out.split(/\r?\n/).map(x=>x.trim()).find(x=>x.startsWith(label));if(!line)throw Error('Missing conversion race result');return JSON.parse(line.slice(label.length));};
 try{
  const setup=artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-activity-availability.sql'),'utf8').split('-- No resource differentiation')[0]+readFileSync(join(root,'tests/integration/ai-run-task.sql'),'utf8').split('-- RUNTIME TESTS')[0]+readFileSync(join(root,'tests/integration/ai-conversion.sql'),'utf8').split('-- CONVERSION TESTS')[0];
  const out=run('psql',[...dbArgs,'-t','-A','-f','-'],setup+`select 'REQUEST_A='||pg_temp.cv_request('RaceA')::text;select 'REQUEST_B='||pg_temp.cv_request('RaceB')::text;commit;`);
  const a=JSON.stringify(parse(out,'REQUEST_A=')).replaceAll("'","''"),b=JSON.stringify(parse(out,'REQUEST_B=')).replaceAll("'","''");
  const first=request(`begin;set local role service_role;select 'CANDIDATE='||public.convert_ai_output_to_candidate('${a}'::jsonb)::text;select 'RACE_READY';select pg_sleep(0.5);commit;`);await first.ready;
  const second=request(`begin;set local role service_role;select 'CANDIDATE='||public.convert_ai_output_to_candidate('${a}'::jsonb)::text;commit;`);
  const rows=(await Promise.all([first.promise,second.promise])).map(x=>parse(x,'CANDIDATE='));if(rows[0].id!==rows[1].id||rows[0].origin_reference_id!==rows[1].origin_reference_id)throw Error('Concurrent conversion duplicated canonical identity');
  const third=request(`begin;set local role service_role;select public.convert_ai_output_to_candidate('${b}'::jsonb);select 'RACE_READY';select pg_sleep(0.5);commit;`);await third.ready;
  const fourth=request(`begin;set local role service_role;do $$begin perform public.convert_ai_output_to_candidate('${b}'::jsonb||'{"candidateTitle":"Conflicting title"}');raise exception 'Conflicting conversion accepted';exception when unique_violation then null;end$$;commit;`);await Promise.all([third.promise,fourth.promise]);
  // Retry must return current canonical state after later human edits, without
  // reapplying the original draft or losing the original conversion identity.
  run('psql',[...dbArgs,'-c',`begin;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);set local role authenticated;select public.update_development_object('${rows[0].id}','{"title":"Later human title","content":"Later human draft"}');commit;`]);
  const retry=await request(`begin;set local role service_role;select 'CANDIDATE='||public.convert_ai_output_to_candidate('${a}'::jsonb)::text;commit;`).promise;
  if(parse(retry,'CANDIDATE=').content!=='Later human draft')throw Error('Retry overwrote later human edits');
  const state=JSON.parse(run('psql',[...dbArgs,'-t','-A','-c',`select json_build_object('objects',(select count(*) from public.development_objects where origin_type='AI' and origin_reference_id is not null),'ideas',(select count(*) from public.idea_details d join public.development_objects o on o.id=d.development_object_id where o.origin_type='AI' and d.acceptance_state='candidate'),'audits',(select count(*) from public.change_log where entity_type='DEVELOPMENT_OBJECT' and related_ai_output_id is not null),'converted',(select count(*) from public.ai_outputs where disposition='CONVERTED_TO_PROJECT_OBJECT'),'wrong_revision',(select count(*) from public.ai_outputs where disposition='CONVERTED_TO_PROJECT_OBJECT' and disposition_revision<>2));`]).trim());
  if(state.objects!==2||state.ideas!==2||state.audits!==2||state.converted!==2||state.wrong_revision!==0)throw Error('Conversion concurrency atomic state mismatch');
  console.log('M14.15 independent-session exact-retry/conflicting-conversion/one-candidate/provenance/audit/canonical-edits PASS');
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
