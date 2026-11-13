import {spawn,spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import assert from 'node:assert/strict';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export async function testActivityResearch({run,args,binary,childEnv,root}){
 const name='fici_activity_research';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  run('psql',[...db,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+`
reset role;create table public.research_test_ids as select pg_temp.research_context('Session9') activity,pg_temp.research_source('Patent') patent,pg_temp.research_source('Evidence') evidence;delete from public.activity_research_links where false;
commit;`);
  const ctx=JSON.parse(run('psql',[...db,'-t','-A','-c','select row_to_json(x)::text from public.research_test_ids x']).trim());
  // Use a fresh output tuple and a fresh Evidence input tuple for actual simultaneous retries.
  run('psql',[...db,'-c',"begin;set local request.jwt.claim.sub='00000000-0000-4000-8000-000000006004';insert into public.research_test_ids select activity,(public.create_patent_record(jsonb_build_object('projectId',p.id,'workspaceId',p.primary_workspace_id,'publicationNumber','race','title','Race source','sourceDatabase','USPTO','sourceUrl','https://example.test/race'))->>'id')::uuid,(public.create_evidence(p.id,p.primary_workspace_id,'MEASUREMENT','Race source','Source facts','Notebook')->>'id')::uuid from public.research_test_ids x join public.activity_instances a on a.id=x.activity join public.development_projects p on p.id=a.project_id;commit;"]);
  const fresh=JSON.parse(run('psql',[...db,'-t','-A','-c',"select row_to_json(x)::text from public.research_test_ids x where patent<>'"+ctx.patent+"'"]).trim());
  const call=expression=>new Promise((resolve,reject)=>{
   const child=spawn(binary('psql'),[...db,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});let out='',err='';
   const timer=setTimeout(()=>{child.kill();reject(Error('Research race timeout'));},60000);
   child.stdout.on('data',x=>out+=x);child.stderr.on('data',x=>err+=x);child.on('error',reject);child.on('close',code=>{clearTimeout(timer);if(code!==0)return reject(Error(err));const line=out.split(/\r?\n/).find(x=>x.startsWith('RESULT='));if(!line)return reject(Error('Missing canonical result'));resolve(JSON.parse(line.slice(7)));});
   child.stdin.end("begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select 'RESULT='||("+expression+")::text;select pg_sleep(0.15);commit;");
  });
  for(const expression of ["public.add_activity_research_reference('"+fresh.activity+"','PATENT_RECORD','"+fresh.patent+"')","public.add_activity_evidence_input('"+fresh.activity+"','"+fresh.evidence+"',false)"]){
   const rows=await Promise.all([call(expression),call(expression)]);assert.deepEqual(rows[0],rows[1]);
  }
  assert.equal(run('psql',[...db,'-t','-A','-c',"select count(*) from public.activity_research_links where entity_id='"+fresh.patent+"'"]).trim(),'1');
  const service=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.activity-research.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:120000,env:{...childEnv,FICI_ACTIVITY_RESEARCH_PORT:String(args[args.indexOf('-p')+1])}});
  if(service.error||service.status!==0)throw Error('Activity research services failed: '+(service.error?.message??service.stderr)+'\n'+service.stdout);
  console.log(service.stdout);console.log('M12.19 actual research/Evidence services PostgreSQL RLS/current-scope/revocation PASS');
  console.log('M12.19 simultaneous research registration/Evidence input canonical row concurrency PASS');
 }finally{run('psql',[...args,'-c','drop database '+name+' with(force)']);}
}
