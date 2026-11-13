import {spawn} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import assert from 'node:assert/strict';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export async function testCommentNotificationCommit({root,binary,args,env,run}){
 const name='fici_comment_notifications';run('psql',[...args,'-c',`create database ${name} template postgres`]);const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  const setup=readFileSync(join(root,'tests/integration/comment-notifications.sql'),'utf8').split("insert into cn select 'Feedback'")[0];
  run('psql',[...db,'-qAt'],artifactReviewSecurityFixture(root)+setup+`reset role;create table public.comment_commit_context as table cn;grant select on public.comment_commit_context to authenticated;commit;`);
  for(const kind of ['feedback_items','share_comments'])for(const finish of ['rollback','commit']){
   const child=spawn(binary('psql'),[...db,'-qAt'],{env,windowsHide:true,stdio:['pipe','pipe','pipe']});let out='',err='',timer;child.stdout.on('data',c=>{out+=c;});child.stderr.on('data',c=>{err+=c;});const done=new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(new Error('Comment fixture failed: '+err)));});done.catch(()=>{});
   try{
    const ready=new Promise((resolve,reject)=>{timer=setTimeout(()=>reject(new Error('Comment fixture not ready')),15000);child.stdout.on('data',()=>{const m=out.match(/M1513_READY=([0-9a-f-]{36})/);if(m){clearTimeout(timer);resolve(m[1]);}});});
    const statement=kind==='feedback_items'?`select 'M1513_READY='||(public.add_feedback('ARTIFACT',sub.artifact_id,sub.artifact_version_id,'COMMENT','Private feedback')->>'id') from public.submissions sub where sub.id=(select (payload->>'id')::uuid from public.comment_commit_context where label='Team');`:`select 'M1513_READY='||(public.add_share_comment(jsonb_build_object('shareId',(select payload->>'id' from public.comment_commit_context where label='Share'),'content','Private comment'))->>'id');`;
    child.stdin.write(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);`+statement+'\n');
    const id=await ready;
    assert.equal(run('psql',[...db,'-qAt'],`set role service_role;select public.comment_notification_contexts('${id}');`).trim(),'[]','uncommitted source cannot dispatch');
    child.stdin.end(finish+';\n');await done;
    if(finish==='rollback'){assert.equal(run('psql',[...db,'-qAt'],`select count(*) from public.${kind} where id='${id}';`).trim(),'0');assert.equal(run('psql',[...db,'-qAt'],`select count(*) from private.comment_notification_batches where source_id='${id}';`).trim(),'0');}
    else{
     const sql=`set role service_role;select public.create_domain_notification(jsonb_build_object('notificationType','COMMENT_RECEIVED','recipientContext',d->'recipientContext','formatterInput','{}'::jsonb,'entityReference',d->'entityReference','idempotencyKey',d->>'idempotencyKey','title','New comment received','body','New feedback was added.','recipientStrategy','CURRENT_AUTHORIZED_TARGET_OWNERS_EXCLUDING_AUTHOR'))->>'id' from jsonb_array_elements(public.comment_notification_contexts('${id}')) d;`;
     const deliver=()=>new Promise((resolve,reject)=>{const p=spawn(binary('psql'),[...db,'-qAt'],{env,windowsHide:true,stdio:['pipe','pipe','pipe']});let data='',error='';p.stdout.on('data',c=>{data+=c;});p.stderr.on('data',c=>{error+=c;});p.on('error',reject);p.on('exit',code=>code===0?resolve(data.trim()):reject(new Error(error)));p.stdin.end(sql);});
     const [a,b]=await Promise.all([deliver(),deliver()]);assert.equal(a,b);assert.equal(a.split(/\s+/).length,2,'one notice per source-side recipient');
     assert.equal(run('psql',[...db,'-qAt'],`select count(*) from private.comment_notification_batches where source_id='${id}';`).trim(),'1');
    }
   }finally{clearTimeout(timer);if(child.exitCode===null){child.stdin.end('rollback;\n');await done;}}
  }
 }finally{run('psql',[...args,'-c',`drop database if exists ${name} with (force)`]);}
 console.log('M15.13 two-session M8/M13 commit/rollback + concurrent canonical notification identity PASS');
}
