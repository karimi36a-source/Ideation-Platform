import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
export function testSharingPrivacy({run,args,childEnv,root}){
 const name='fici_sharing_privacy';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  const generated=spawnSync(process.execPath,['scripts/mind-map-browser-fixture.mjs'],{cwd:root,encoding:'utf8',windowsHide:true});
  if(generated.status!==0||!generated.stdout.includes('update auth.users set'))throw Error('Canonical map privacy fixture unavailable');
  run('psql',[...db,'-f','-'],generated.stdout.split('update auth.users set')[0]+readFileSync(join(root,'tests/integration/sharing-privacy-setup.sql'),'utf8'));
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.sharing-privacy.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:240000,env:{...childEnv,FICI_SHARING_PRIVACY_TEST_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw Error('Sharing privacy acceptance failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
  console.log(result.stdout);console.log('M13.23 AT-E2E-PRIV-001 exact-one/map/pages/API/DB-RLS/Chat-realtime/linked-records/Versions/revoke/removal/role-only PASS');
 }finally{run('psql',[...args,'-c','drop database '+name+' with (force)']);}
}
