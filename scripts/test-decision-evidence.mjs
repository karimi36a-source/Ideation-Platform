import {spawn,spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import assert from 'node:assert/strict';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
const literal=v=>"'"+String(v).replaceAll("'","''")+"'";
export async function testDecisionEvidence({run,args,binary,childEnv,root}){
 const name='fici_decision_evidence';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);const actor='00000000-0000-4000-8000-000000006005';
 const start=(sql,application)=>{
  const child=spawn(binary('psql'),[...db,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});let out='',err='';
  const finished=new Promise((resolve,reject)=>{const timer=setTimeout(()=>{child.kill();reject(Error('Decision Evidence race timed out'));},60000);child.stdout.on('data',x=>out+=x);child.stderr.on('data',x=>err+=x);child.on('error',e=>{clearTimeout(timer);reject(e);});child.on('close',code=>{clearTimeout(timer);if(code!==0)reject(Error('Decision Evidence race failed: '+err));else resolve(out);});});
  child.stdin.end("begin;set local application_name="+literal(application)+";set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub',"+literal(actor)+",true);"+sql+'commit;');
  return finished;
 };
 const finalize=(input,app)=>start("do $$declare r jsonb;begin begin r:=public.finalize_decision("+literal(JSON.stringify(input))+"::jsonb);perform set_config('test.de_result',jsonb_build_object('code','OK','decision',r)::text,true);exception when serialization_failure then perform set_config('test.de_result','{\"code\":\"CONFLICT\"}',true);end;end$$;select 'RESULT='||current_setting('test.de_result');select pg_sleep(0.2);",app).then(out=>JSON.parse(out.split(/\r?\n/).find(s=>s.startsWith('RESULT=')).slice(7)));
 try{
  run('psql',[...db,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/decision-evidence-setup.sql'),'utf8')+`
reset role;
create table public.de_test_context(label text,payload jsonb);
insert into public.de_test_context select label,pg_temp.de_args(label,array[pg_temp.de_source('UNVERIFIED'),pg_temp.de_source('VERIFIED')]) from de_decisions where label in ('Same race','Different race','Link race','Service');
insert into public.de_test_context values('OtherEvidence',to_jsonb(pg_temp.de_source('CONTRADICTED'))),('TeamId',(select payload->'teamId' from acceptance_teams where label='A'));
commit;`);
  const ctx=JSON.parse(run('psql',[...db,'-t','-A','-c','select jsonb_object_agg(label,payload)::text from public.de_test_context']).trim());
  const same=await Promise.all([finalize(ctx['Same race'],'m1218_same_1'),finalize({...ctx['Same race'],linkedEvidenceIds:[...ctx['Same race'].linkedEvidenceIds].reverse().concat(ctx['Same race'].linkedEvidenceIds[0])},'m1218_same_2')]);
  assert(same.every(r=>r.code==='OK'));assert.deepEqual(same[0].decision,same[1].decision);
  const different=await Promise.all([finalize(ctx['Different race'],'m1218_diff_1'),finalize({...ctx['Different race'],linkedEvidenceIds:[ctx.OtherEvidence]},'m1218_diff_2')]);
  assert.deepEqual(different.map(r=>r.code).sort(),['CONFLICT','OK']);
  const winner=different.find(r=>r.code==='OK').decision;
  const count=JSON.parse(run('psql',[...db,'-t','-A','-c',"select jsonb_build_object('events',(select count(*) from public.change_log where entity_id="+literal(winner.id)+" and change_type='DECISION_FINALIZED'),'links',(select count(*) from public.evidence_links where linked_entity_type='DECISION' and linked_entity_id="+literal(winner.id)+"))::text"]).trim());assert.equal(count.events,1);assert([1,2].includes(count.links));
  // Hold Evidence, then race real canonical linking and finalization operations.
  const held=spawn(binary('psql'),[...db,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});let holderOut='';
  let holderTimer;const ready=new Promise((resolve,reject)=>{holderTimer=setTimeout(()=>reject(Error('Evidence lock holder did not start')),10000);held.stdout.on('data',b=>{holderOut+=b;if(holderOut.includes('HOLDER_READY')){clearTimeout(holderTimer);resolve();}});held.on('error',reject);});
  const holderDone=new Promise((resolve,reject)=>{held.on('close',code=>code===0?resolve():reject(Error('Lock holder failed')));});
  held.stdin.write('begin;select id from public.evidence where id='+literal(ctx['Link race'].linkedEvidenceIds[0])+" for update;select 'HOLDER_READY';\n");
  try{
   await ready;
   const link={evidenceId:ctx['Link race'].linkedEvidenceIds[0],entityType:'DECISION',entityId:ctx['Link race'].decisionId,relationshipType:'SUPPORTS'};
   const linking=start('select public.link_evidence('+literal(JSON.stringify(link))+'::jsonb);','m1218_external_link');
   const waitLock=async app=>{const until=Date.now()+10000;while(Date.now()<until){const waiting=run('psql',[...db,'-t','-A','-c',"select exists(select 1 from pg_stat_activity where application_name="+literal(app)+" and wait_event_type='Lock')"]).trim();if(waiting==='t')return;await new Promise(r=>setTimeout(r,100));}throw Error('Expected operation lock wait not observed');};
   await waitLock('m1218_external_link');
   const finishing=finalize(ctx['Link race'],'m1218_finalize_link_race');await waitLock('m1218_finalize_link_race');
   held.stdin.end('commit;\n');await holderDone;await linking;assert.equal((await finishing).code,'OK');
  }finally{clearTimeout(holderTimer);if(!held.stdin.writableEnded)held.stdin.end('rollback;\n');}
  console.log('M12.18 real-session identical retry/different-Evidence conflict/one event/canonical-link-vs-finalize lock-order PASS');
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.decision-evidence.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:120000,env:{...childEnv,FICI_DECISION_EVIDENCE_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw Error('Decision Evidence public service failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
  console.log(result.stdout);console.log('M12.18 actual finalizeDecision service to PostgreSQL + real Evidence statuses/links/retry/identity/revocation PASS');
 }finally{run('psql',[...args,'-c','drop database '+name+' with (force)']);}
}
