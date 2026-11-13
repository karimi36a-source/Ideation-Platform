import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testShareRevoke({run,args,childEnv,root}){
 const name='fici_share_revoke';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  let fixture=artifactReviewSecurityFixture(root);
  for(const file of ['activity-research-setup.sql','share-entity-setup.sql','team-sharing-cohort.sql','share-revoke-setup.sql'])fixture+=readFileSync(join(root,'tests/integration',file),'utf8');
  run('psql',[...db,'-f','-'],fixture);
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.share-revoke.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:240000,env:{...childEnv,FICI_REVOKE_TEST_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw Error('Revoke acceptance failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
  console.log(result.stdout);console.log('M13.12 AT-SHARE-005 current-source-authority/revocation/history/audit-hook/retry/concurrency/rollback/File/privacy PASS');
 }finally{run('psql',[...args,'-c','drop database '+name+' with (force)']);}
}
