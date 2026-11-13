import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export async function testApprovalNotificationCommit({root,binary,args,env,run}){
 const name='fici_approval_notifications';
 run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  run('psql',[...db,'-qAt'],artifactReviewSecurityFixture(root)+`
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
create table public.approval_commit_fixture(id uuid);
grant select,insert on public.approval_commit_fixture to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.approval_commit_fixture select (public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team'))->>'id')::uuid from submitted_fixtures where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(id) from public.approval_commit_fixture;
commit;`);
  const sid=run('psql',[...db,'-qAt'],'select id from public.approval_commit_fixture;').trim();assert.match(sid,/^[0-9a-f-]{36}$/);
  for(const finish of ['rollback','commit']){
   const child=spawn(binary('psql'),[...db,'-qAt'],{env,windowsHide:true,stdio:['pipe','pipe','pipe']});
   let out='',err='',timer;child.stdout.on('data',c=>{out+=c;});child.stderr.on('data',c=>{err+=c;});
   const done=new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(new Error('Approval fixture failed: '+err)));});done.catch(()=>{});
   try{
    const ready=new Promise((resolve,reject)=>{timer=setTimeout(()=>reject(new Error('Approval fixture not ready')),15000);child.stdout.on('data',()=>{if(out.includes('M1512_READY')){clearTimeout(timer);resolve();}});});
    child.stdin.write(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select public.approve_artifact('${sid}','Private approval instructions');select 'M1512_READY';\n`);
    await ready;
    assert.equal(run('psql',[...db,'-qAt'],`set role service_role;select public.approval_notification_contexts('${sid}');`).trim(),'[]','uncommitted approval cannot dispatch');
    child.stdin.end(finish+';\n');await done;
    assert.equal(run('psql',[...db,'-qAt'],`select count(*) from public.notifications where entity_id='${sid}';`).trim(),finish==='rollback'?'0':'2','canonical notices share the approval commit boundary');
    if(finish==='rollback'){
     assert.equal(run('psql',[...db,'-qAt'],`select status from public.submissions where id='${sid}';`).trim(),'UNDER_REVIEW');
     assert.equal(run('psql',[...db,'-qAt'],'select count(*) from private.approval_notification_batches;').trim(),'0');
    }else{
     const deliver=()=>new Promise((resolve,reject)=>{const p=spawn(binary('psql'),[...db,'-qAt'],{env,windowsHide:true,stdio:['pipe','pipe','pipe']});let ids='',error='';p.stdout.on('data',c=>{ids+=c;});p.stderr.on('data',c=>{error+=c;});p.on('error',reject);p.on('exit',code=>code===0?resolve(ids.trim()):reject(new Error('Approval delivery failed: '+error)));p.stdin.end(`set role service_role;select public.create_domain_notification(jsonb_build_object('notificationType','ARTIFACT_APPROVED','recipientContext',x->'recipientContext','formatterInput','{}'::jsonb,'entityReference',jsonb_build_object('entityType','submission','entityId','${sid}'),'idempotencyKey',x->>'idempotencyKey','title','Artifact approved','body','An Artifact submission has been approved.','recipientStrategy','CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM'))->>'id' from jsonb_array_elements(public.approval_notification_contexts('${sid}')) x;`);});
     const [a,b]=await Promise.all([deliver(),deliver()]);assert.equal(a,b,'concurrent retries return same canonical notices');assert.equal(a.split(/\s+/).length,2);
     assert.equal(run('psql',[...db,'-qAt'],`select count(*) from public.notifications where entity_id='${sid}';`).trim(),'2');
     assert.equal(run('psql',[...db,'-qAt'],'select count(*) from private.approval_notification_batches;').trim(),'1');
     assert.equal(run('psql',[...db,'-qAt'],`select count(*) from realtime.messages m join public.notifications n on m.payload->>'id'=n.id::text where n.entity_id='${sid}' and m.private and m.event='notification.changed' and m.topic='notifications:'||n.recipient_user_id::text;`).trim(),'2');
    }
   }finally{clearTimeout(timer);if(child.exitCode===null){child.stdin.end('rollback;\n');await done;}}
  }
 }finally{run('psql',[...args,'-c',`drop database if exists ${name} with (force)`]);}
 console.log('M15.12 two-session approval commit/rollback + concurrent audience/notification identity PASS');
}
