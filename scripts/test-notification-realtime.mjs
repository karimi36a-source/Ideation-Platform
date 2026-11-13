import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
/** Two real sessions prove uncommitted transport rows are invisible. No websocket mock claim. */
export async function testNotificationCommit({binary,args,env,run}){
 const uid='00000000-0000-4000-8000-000000015700';
 run('psql',args,"insert into auth.users(id,email) values('"+uid+"','m157-commit@example.test'); select public.provision_user_profile('"+uid+"','active');");
 for(const [suffix,finish,expected] of [['1','commit',1],['2','rollback',0]]){
  const id='00000000-0000-4000-8000-00000001570'+suffix;
  const child=spawn(binary('psql'),[...args,'-qAt'],{env,windowsHide:true,stdio:['pipe','pipe','pipe']});
  let stderr='';child.stderr.on('data',c=>{stderr+=c;});
  const exited=new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(new Error('Commit fixture failed: '+stderr)));});
  try{
   const ready=new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('Commit fixture not ready')),10000);let out='';child.stdout.on('data',c=>{out+=c;if(out.includes('READY')){clearTimeout(timer);resolve();}});});
   child.stdin.write("begin; insert into public.notifications(id,recipient_user_id,notification_type,title,body) values('"+id+"','"+uid+"','MEMBER_ADDED','Commit test','Safe'); select 'READY';\n");
   await ready;
   const query="select count(*) from realtime.messages where event='notification.changed' and payload->>'id'='"+id+"';";
   assert.equal(run('psql',[...args,'-qAt'],query).trim(),'0','uncommitted transport cannot be observed');
   child.stdin.end(finish+';\n');await exited;
   assert.equal(run('psql',[...args,'-qAt'],query).trim(),String(expected),'commit-only transport visibility');
  }finally{if(child.exitCode===null)child.stdin.end('rollback;\n');}
 }
 console.log('M15.7 two-session committed INSERT visibility + rollback PASS');
}
