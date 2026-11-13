import {spawn} from 'node:child_process';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
/** Isolated configuration races; no shared authorization helper is changed. */
export async function testAiPromptTemplates({run,args,binary,childEnv,root}){
 const name='fici_ai_prompt_concurrency',children=[];
 run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==='-d'?name:v);
 const actor="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);";
 const input=`'{"roleCode":"STRUCTURED_CREATIVITY_ASSISTANT","activityType":"scamper","systemInstruction":"FICI concurrency fixture. Human review required.","taskTemplate":"Safe supplied SCAMPER task.","outputSchema":{"type":"object","properties":{"response":{"type":"string"}},"required":["response"],"additionalProperties":false}}'::jsonb`;
 function request(sql){
  let signal;const ready=new Promise(resolve=>signal=resolve);
  const promise=new Promise((resolve,reject)=>{
   const child=spawn(binary('psql'),[...dbArgs,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out='',err='';
   const timer=setTimeout(()=>{child.kill();signal();reject(new Error('Prompt configuration race timeout'));},60000);
   child.stdout.on('data',x=>{out+=x;if(out.includes('RACE_READY'))signal();});child.stderr.on('data',x=>err+=x);
   child.on('error',e=>{clearTimeout(timer);signal();reject(e);});
   child.on('close',code=>{clearTimeout(timer);signal();if(code===0)resolve(out);else reject(new Error('Prompt race failed: '+err));});
   child.stdin.end(sql);
  });return {promise,ready};
 }
 const parse=(out,marker)=>{const line=out.split(/\r?\n/).map(x=>x.trim()).find(x=>x.startsWith(marker));if(!line)throw new Error('Missing prompt result');return JSON.parse(line.slice(marker.length));};
 try{
  run('psql',[...dbArgs,'-f','-'],artifactReviewSecurityFixture(root)+`\n${actor}select public.seed_ai_prompt_templates();commit;`);
  const v1=run('psql',[...dbArgs,'-t','-A','-c',"select to_jsonb(t)-'status' from public.ai_prompt_templates t where role_code='STRUCTURED_CREATIVITY_ASSISTANT' and activity_type='scamper' and version=1;"]).trim();
  const first=request(`begin;${actor}select 'PROMPT_RESULT='||public.create_ai_prompt_template(${input})::text;select 'RACE_READY';select pg_sleep(0.5);commit;`);
  await first.ready;
  const second=request(`begin;${actor}select 'PROMPT_RESULT='||public.create_ai_prompt_template(${input})::text;commit;`);
  const versions=(await Promise.all([first.promise,second.promise])).map(out=>parse(out,'PROMPT_RESULT=')).sort((a,b)=>a.version-b.version);
  if(versions[0].version!==2||versions[1].version!==3||versions[0].id===versions[1].id)throw new Error('Prompt version allocation failed');
  for(const v of versions)if(!/^[a-f0-9-]{36}$/.test(v.id))throw new Error('Invalid fixture identity');
  const activate=request(`begin;${actor}select public.set_ai_prompt_template_active('${versions[0].id}',true);select 'RACE_READY';select pg_sleep(0.5);commit;`);
  await activate.ready;
  const activateNext=request(`begin;${actor}select public.set_ai_prompt_template_active('${versions[1].id}',true);commit;`);
  await Promise.all([activate.promise,activateNext.promise]);
  const active=JSON.parse(run('psql',[...dbArgs,'-t','-A','-c',"select private.resolve_active_ai_prompt_template('STRUCTURED_CREATIVITY_ASSISTANT','scamper');"]).trim());
  if(active.id!==versions[1].id)throw new Error('Active selection race failed');
  const after=run('psql',[...dbArgs,'-t','-A','-c',"select to_jsonb(t)-'status' from public.ai_prompt_templates t where role_code='STRUCTURED_CREATIVITY_ASSISTANT' and activity_type='scamper' and version=1;"]).trim();
  if(after!==v1)throw new Error('Historical seed rewritten');
  const revoke=request("begin;update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006001' and role_id=(select id from public.roles where code='ADMIN') and organization_id=(select id from public.organizations where slug='fici');select 'RACE_READY';select pg_sleep(0.5);commit;");
  await revoke.ready;
  const denied=request(`begin;${actor}do $$begin begin perform public.create_ai_prompt_template(${input});raise exception 'Stale Admin allowed';exception when insufficient_privilege then null;end;end$$;commit;`);
  await Promise.all([revoke.promise,denied.promise]);
  const stats=JSON.parse(run('psql',[...dbArgs,'-t','-A','-c',"select json_build_object('rows',(select count(*) from public.ai_prompt_templates),'active',(select count(*) from public.ai_prompt_templates where role_code='STRUCTURED_CREATIVITY_ASSISTANT' and activity_type='scamper' and status='active'));"]).trim());
  if(stats.rows!==10||stats.active!==1)throw new Error('Prompt race state changed');
  console.log('M14.3 independent-session version allocation/one-active/history/Admin-revocation race PASS');
 }finally{
  for(const child of children)if(child.exitCode===null)child.kill();
  run('psql',[...args,'-c',`drop database ${name} with (force)`]);
 }
}
