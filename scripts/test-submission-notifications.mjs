import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
/** Independent sessions against a disposable clone prove post-commit delivery
 * and concurrent event identity without changing M8 or notification semantics. */
export async function testSubmissionNotificationCommit({root,binary,args,env,run}){
 const name='fici_submission_notifications';
 run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  for(const finish of ['rollback','commit']){
   const child=spawn(binary('psql'),[...db,'-qAt'],{env,windowsHide:true,stdio:['pipe','pipe','pipe']});
   let out='',err='';child.stdout.on('data',c=>{out+=c;});child.stderr.on('data',c=>{err+=c;});
   const done=new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(new Error('Submission commit fixture failed: '+err)));});
   done.catch(()=>{});
   let timer;
   try{
    const ready=new Promise((resolve,reject)=>{timer=setTimeout(()=>reject(new Error('Submission commit fixture not ready')),15000);child.stdout.on('data',()=>{const m=out.match(/M1510_READY=([0-9a-f-]{36})/);if(m){clearTimeout(timer);resolve(m[1]);}});});
    child.stdin.write(artifactReviewSecurityFixture(root)+`
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select 'M1510_READY='||(public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team'))->>'id') from submitted_fixtures where label='Team';
`);
    const sid=await ready;
    const request=JSON.stringify({notificationType:'SUBMISSION_RECEIVED',recipientContext:{sourceId:sid},formatterInput:{},entityReference:{entityType:'submission',entityId:sid},idempotencyKey:'submission-received:'+sid,title:'Submission received',body:'A submission is available for your assigned review.',recipientStrategy:'CURRENT_ASSIGNED_SUBMISSION_REVIEWER'});
    const invoke=`public.create_domain_notification('${request}'::jsonb)`;
    run('psql',[...db,'-qAt'],`set role service_role;do $$begin begin perform ${invoke};raise exception 'Uncommitted Submission notified';exception when insufficient_privilege then null;end;end$$;`);
    child.stdin.end(finish+';\n');await done;
    assert.equal(run('psql',[...db,'-qAt'],`select count(*) from public.submissions where id='${sid}';`).trim(),finish==='commit'?'1':'0');
    assert.equal(run('psql',[...db,'-qAt'],`select count(*) from public.notifications where entity_type='submission' and entity_id='${sid}';`).trim(),'0','no premature/rolled-back notice');
    if(finish==='commit'){
     const deliver=()=>new Promise((resolve,reject)=>{const p=spawn(binary('psql'),[...db,'-qAt'],{env,windowsHide:true,stdio:['pipe','pipe','pipe']});let ids='',error='';p.stdout.on('data',c=>{ids+=c;});p.stderr.on('data',c=>{error+=c;});p.on('error',reject);p.on('exit',code=>code===0?resolve(ids.trim()):reject(new Error('Submission delivery failed: '+error)));p.stdin.end(`set role service_role;select ${invoke}->>'id';`);});
     const [a,b]=await Promise.all([deliver(),deliver()]);assert.match(a,/^[0-9a-f-]{36}$/);assert.equal(a,b,'concurrent retry returns one canonical note');
     assert.equal(run('psql',[...db,'-qAt'],`select count(*) from public.notifications where entity_id='${sid}' and recipient_user_id='00000000-0000-4000-8000-000000006002';`).trim(),'1');
     assert.equal(run('psql',[...db,'-qAt'],`select count(*) from realtime.messages m join public.notifications n on m.payload->>'id'=n.id::text where n.entity_id='${sid}' and m.private and m.event='notification.changed' and m.topic='notifications:'||n.recipient_user_id::text;`).trim(),'1','private refresh only after canonical notice commit');
    }
   }finally{clearTimeout(timer);if(child.exitCode===null){child.stdin.end('rollback;\n');await done;}}
  }
 }finally{run('psql',[...args,'-c',`drop database if exists ${name} with (force)`]);}
 console.log('M15.10 two-session Submission commit/rollback + concurrent notification identity PASS');
}
