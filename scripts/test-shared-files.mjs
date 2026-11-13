import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testSharedFiles({run,args,childEnv,root}){
 const name='fici_shared_files';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  let fixture=artifactReviewSecurityFixture(root);
  for(const file of ['activity-research-setup.sql','share-entity-setup.sql','team-sharing-cohort.sql','share-revoke-setup.sql','share-history-setup.sql','shared-files-setup.sql'])fixture+=readFileSync(join(root,'tests/integration',file),'utf8');
  run('psql',[...db,'-f','-'],fixture);
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.shared-files.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:240000,env:{...childEnv,FICI_SHARED_FILES_TEST_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw Error('Shared File acceptance failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
  console.log(result.stdout);console.log('M13.15 exact-FILE/shared-signing/linked-isolation/revocation/archive/mutation/storage-privacy PASS');
 }finally{run('psql',[...args,'-c','drop database '+name+' with (force)']);}
}
