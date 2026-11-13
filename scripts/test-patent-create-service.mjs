import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testPatentCreateService({run,args,childEnv,root}){
 const name='fici_patent_create_service';run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  run('psql',[...db,'-f','-'],artifactReviewSecurityFixture(root)+`
reset role;
create table public.patent_service_context(label text,payload jsonb);
insert into public.patent_service_context select label,payload from logged_projects where label in ('Team','Individual');
insert into public.patent_service_context select 'TeamId',jsonb_build_object('id',payload->>'teamId') from acceptance_teams where label='A';
grant select on public.patent_service_context to authenticated;
commit;`);
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.patents.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:120000,env:{...childEnv,FICI_PATENT_TEST_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw new Error(`Patent public-service acceptance failed: ${result.error?.message??result.stderr}\n${result.stdout}`);
  console.log(result.stdout);console.log('AT-PAT-001 actual createPatentRecord service to PostgreSQL + exact persisted source/relevance + no Evidence/fetch + revocation PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
