import {spawnSync} from 'node:child_process';
import {mkdtempSync,readdirSync,readFileSync,rmSync,realpathSync,existsSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join,resolve,dirname,relative,isAbsolute} from 'node:path';
import {createServer} from 'node:net';
const root=resolve(import.meta.dirname,'..'),dockerMode=process.argv.includes('--docker'),idempotencyMode=process.argv.includes('--idempotency'),uiMode=process.argv.includes('--classroom-ui'),tokenMode=uiMode||process.argv.includes('--join-token'),studentMode=tokenMode||process.argv.includes('--student-join'),masterMode=idempotencyMode||studentMode||process.argv.includes('--master');
const milestone=idempotencyMode?'M16.14':uiMode?'M16.6':tokenMode?'M16.5':studentMode?'M16.4':masterMode?'M16.3':'M16.2';
const dockerDesktop='C:/Program Files/Docker/Docker/resources/bin/docker.exe';
const docker=process.platform==='win32'&&existsSync(dockerDesktop)?dockerDesktop:'docker';
const container='fici-m162-'+randomUUID();
let tempRoot,dir,port;
const bin=process.env.POSTGRES_BIN;
const childEnv=Object.fromEntries(Object.entries(process.env).filter(([name])=>!name.toUpperCase().startsWith('PG')));
const execute=(executable,args,options={})=>spawnSync(executable,args,{cwd:root,windowsHide:true,encoding:'utf8',timeout:60000,maxBuffer:16*1024*1024,env:childEnv,...options});
const checked=(label,r)=>{if(r.error||r.status!==0){const error=new Error(label+' failed: '+(r.error?.message??r.stderr));error.exitCode=Number.isInteger(r.status)&&r.status>0?r.status:1;throw error;}return r.stdout;};
const run=(name,args)=>checked(name,execute(join(bin,name+(process.platform==='win32'?'.exe':'')),args,{env:{...childEnv,...(name==='psql'?{PGOPTIONS:'-c statement_timeout=50000'}:{})}}));
const runDocker=(args,options)=>checked('docker',execute(docker,args,options));
let started=false,containerAttempted=false;
try{
 if(dockerMode){
  if(runDocker(['info','--format','{{.OSType}}']).trim()!=='linux')throw Error('Docker Linux engine required');
  console.log(milestone+' Docker validation environment PASS');
  // No host port, bind mount, password, or persistent database volume. Trust
  // authentication is confined to this isolated container's own loopback.
  containerAttempted=true;
  runDocker(['run','--detach','--name',container,'--network','none','--tmpfs','/var/lib/postgresql/data:rw','--env','POSTGRES_HOST_AUTH_METHOD=trust','--env','POSTGRES_INITDB_ARGS=--no-locale --encoding=UTF8','postgres:17'],{timeout:180000});
  const deadline=Date.now()+60000;let ready=false;
  while(Date.now()<deadline){
   // TCP readiness avoids the image entrypoint's temporary socket-only server.
   const probe=execute(docker,['exec',container,'pg_isready','-h','127.0.0.1','-U','postgres','-d','postgres'],{timeout:5000});
   if(!probe.error&&probe.status===0){ready=true;break;}
   await new Promise(done=>setTimeout(done,250));
  }
  if(!ready)throw Error('Disposable PostgreSQL container readiness failed');
 }else{
  if(!bin)throw Error('POSTGRES_BIN required (or use --docker)');
  tempRoot=realpathSync(tmpdir());dir=mkdtempSync(join(tempRoot,'fici-live-room-'));
  port=await new Promise((resolve,reject)=>{const s=createServer();s.once('error',reject);s.listen(0,'127.0.0.1',()=>{const p=s.address().port;s.close(()=>resolve(p));});});
  run('initdb',['-D',join(dir,'data'),'-U','postgres','-A','trust','--no-locale','--encoding=UTF8']);
  run('pg_ctl',['-D',join(dir,'data'),'-l',join(dir,'postgres.log'),'-o','-h 127.0.0.1 -p '+port,'-w','start']);started=true;
 }
 const args=['-X','-h','127.0.0.1',...(dockerMode?[]:['-p',String(port)]),'-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'];
 for(const f of ['tests/integration/fixtures/auth.sql','tests/integration/fixtures/realtime.sql','tests/integration/fixtures/storage.sql',...readdirSync(join(root,'supabase/migrations')).filter(f=>f.endsWith('.sql')).sort().map(f=>'supabase/migrations/'+f),'supabase/seed.sql','tests/integration/live-session-rooms.sql',...(masterMode?['tests/integration/master-live-session-room.sql']:[]),...(studentMode?['tests/integration/student-live-session-authorization.sql']:[])]){
  // Feed the exact repository SQL unchanged, retaining psql ON_ERROR_STOP.
  const output=dockerMode?runDocker(['exec','--interactive','--env','PGOPTIONS=-c statement_timeout=50000',container,'psql',...args,'-f','-'],{input:readFileSync(join(root,f),'utf8')}):run('psql',[...args,'-f',f]);
  if(f.endsWith('live-session-rooms.sql')||f.endsWith('master-live-session-room.sql')||f.endsWith('student-live-session-authorization.sql'))console.log(output);
 }
 if(masterMode){
  if(!dockerMode)throw Error('M16.3 focused service database validation requires --docker');
  const result=execute(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.live-room.config.mts','--reporter=verbose'],{timeout:300000,env:{...childEnv,FICI_LIVE_ROOM_DOCKER:docker,FICI_LIVE_ROOM_CONTAINER:container,...(studentMode?{FICI_LIVE_ROOM_STUDENT:'1'}:{}),...(tokenMode?{FICI_LIVE_ROOM_TOKEN:'1'}:{}),...(uiMode?{FICI_LIVE_ROOM_UI:'1'}:{}),...(idempotencyMode?{FICI_LIVE_ROOM_IDEMPOTENCY:'1'}:{})}});
  if(result.stdout)console.log(result.stdout);
  checked('M16.3 service/database assertions',result);
  console.log('M16.3 Master operation/authorization/reuse/concurrency/provider-failure-integrity PASS');
  if(idempotencyMode)console.log('M16.14 double-start/response-loss/commit-loss/one-active/history-preservation PASS');
  if(uiMode)console.log('M16.6 classroom-context/Student-Master/privacy/no-educational-mutation PASS');
  if(tokenMode)console.log('M16.5 Student-Master/token-authorization/revocation/provider-failure PASS');
  if(studentMode)console.log('M16.4 Student join authorization/Cohort isolation/removal/direct-ID-provider-ref-denial PASS');
 }
 console.log(milestone+' fresh migration and focused database validation PASS');
}catch(error){
 // Preserve the database outcome before cleanup, which may fail independently.
 process.exitCode=error.exitCode??1;
 console.error(milestone+' fresh migration and focused database validation FAIL');
 console.error(error);
}finally{
 try{
  if(dockerMode){
   if(containerAttempted){
    const removed=execute(docker,['rm','--force','--volumes',container]);
    if(removed.error||removed.status!==0){
     // A failed image pull may never have created the named container. Only
     // accept that case after a successful exact-name inventory query.
     const remaining=runDocker(['ps','--all','--filter','name=^/'+container+'$','--format','{{.Names}}']);
     if(remaining.trim())checked('docker cleanup',removed);
    }
   }
  }else if(dir){
   if(started)run('pg_ctl',['-D',join(dir,'data'),'-m','fast','-w','stop']);
   const target=realpathSync(dir),child=relative(tempRoot,target);
   if(dirname(target)!==tempRoot||!child.startsWith('fici-live-room-')||child.includes('..')||isAbsolute(child))throw Error('Unsafe temporary cluster path');
   rmSync(target,{recursive:true,force:true});
  }
  console.log(milestone+' cleanup PASS');
 }catch(error){
  // Never replace a database failure or turn cleanup-only failure into DB FAIL.
  // If stopping failed, the remaining cleanup is deliberately not attempted.
  console.error(milestone+' cleanup WARN ('+(error?.code??'cleanup error')+'); disposable resource may remain: '+(dockerMode?container:dir));
 }
}


