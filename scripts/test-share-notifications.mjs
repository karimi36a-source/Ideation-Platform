import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
/** Real sessions prove Share commit/rollback and concurrent recipient identity.
 * Uses only the disposable cluster supplied by test-db, never hosted projects. */
export async function testShareNotificationCommit({root,binary,args,env,run}){
 for(const finish of ['rollback','commit']){
  const child=spawn(binary('psql'),[...args,'-qAt'],{env,windowsHide:true,stdio:['pipe','pipe','pipe']});
  let out='',err='';child.stdout.on('data',c=>{out+=c;});child.stderr.on('data',c=>{err+=c;});
  const done=new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(new Error('Share commit fixture failed: '+err)));});
  let readyTimer;
  try{
   const ready=new Promise((resolve,reject)=>{readyTimer=setTimeout(()=>reject(new Error('Share commit fixture not ready')),15000);child.stdout.on('data',()=>{const match=out.match(/M159_READY=([0-9a-f-]{36})/);if(match){clearTimeout(readyTimer);resolve(match[1]);}});});
   child.stdin.write(artifactReviewSecurityFixture(root)+`
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select 'M159_READY='||(public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',payload->>'initialVersionId',
 'destinationType','TEAM','destinationId',(select payload->>'teamId' from acceptance_teams where label='B'),'permissionLevel','VIEW','shareMode','SNAPSHOT'))->>'id') from submitted_fixtures where label='Team';
`);
   const sid=await ready;
   const contexts=`set role service_role;select jsonb_array_length(public.artifact_share_notification_contexts('${sid}'));`;
   assert.equal(run('psql',[...args,'-qAt'],contexts).trim(),'0','uncommitted Share cannot produce recipients/notifications');
   child.stdin.end(finish+';\n');await done;
   assert.equal(run('psql',[...args,'-qAt'],contexts).trim(),finish==='commit'?'2':'0','only committed canonical recipients visible');
   if(finish==='commit'){
    assert.equal(run('psql',[...args,'-qAt'],`select count(*) from public.notifications where entity_type='share' and entity_id='${sid}';`).trim(),'0','Share commit precedes delivery');
    const sql=`set role service_role; select public.create_domain_notification(jsonb_build_object('notificationType','ARTIFACT_SHARED','recipientContext',c.value,'formatterInput','{}'::jsonb,
'entityReference',jsonb_build_object('entityType','share','entityId','${sid}'),'title','Artifact shared','body','An Artifact Snapshot has been shared with you.','recipientStrategy','CURRENT_SHARE_DESTINATION'))->>'id'
from jsonb_array_elements(public.artifact_share_notification_contexts('${sid}')) c;`;
    const deliver=()=>new Promise((resolve,reject)=>{const p=spawn(binary('psql'),[...args,'-qAt'],{env,windowsHide:true,stdio:['pipe','pipe','pipe']});let ids='',error='';p.stdout.on('data',c=>{ids+=c;});p.stderr.on('data',c=>{error+=c;});p.on('error',reject);p.on('exit',code=>code===0?resolve(ids.trim().split(/\r?\n/).sort()):reject(new Error('Concurrent notification failed: '+error)));p.stdin.end(sql);});
    const [a,b]=await Promise.all([deliver(),deliver()]);assert.deepEqual(a,b,'concurrent replay returns exact canonical notification IDs');assert.equal(a.length,2);
    assert.equal(run('psql',[...args,'-qAt'],`select count(*) from public.notifications where entity_type='share' and entity_id='${sid}';`).trim(),'2','one note per recipient/event after concurrent retries');
   }
  }finally{clearTimeout(readyTimer);if(child.exitCode===null){child.stdin.end('rollback;\n');await done;}}
 }
 console.log('M15.9 two-session Share commit/rollback + concurrent recipient notification identity PASS');
}
