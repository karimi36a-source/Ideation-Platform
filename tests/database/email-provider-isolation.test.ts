import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
import {z} from 'zod';
vi.mock('server-only',()=>({}));
import {ResendEmailProvider} from '@/features/email/providers/resend';
function state(){
 const port=process.env.FICI_EMAIL_TEST_PORT;
 if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable database required');
 const sql=`select jsonb_build_object('submissions',(select jsonb_agg(to_jsonb(s) order by s.id) from public.submissions s),'versions',(select jsonb_agg(to_jsonb(v) order by v.id) from public.artifact_versions v),'artifacts',(select jsonb_agg(to_jsonb(a) order by a.id) from public.artifacts a),'memberships',(select jsonb_agg(to_jsonb(m) order by m.id) from public.team_memberships m),'notifications',(select jsonb_agg(to_jsonb(n) order by n.id) from public.notifications n),'audits',(select count(*) from public.audit_events));`;
 const result=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_email_provider','-v','ON_ERROR_STOP=1','-qAt','-c',sql],{encoding:'utf8',windowsHide:true,timeout:45000});
 if(result.error||result.status!==0)throw Error('Disposable snapshot failed');
 return JSON.parse(result.stdout.trim());
}
it('provider failures cannot roll back or mutate committed approval, current Version, audit or in-app notifications',async()=>{
 const before=state();
 expect(before.submissions.some((s:{status:string})=>s.status==='APPROVED')).toBe(true);
 expect(before.versions.some((v:{status:string})=>v.status==='CURRENT')).toBe(true);
 expect(before.notifications.length).toBeGreaterThan(0);
 const cases=[{transport:vi.fn().mockResolvedValue(new Response(null,{status:503})),code:'UNAVAILABLE'},{transport:vi.fn().mockRejectedValue(new TypeError('offline')),code:'NETWORK'},{transport:vi.fn(()=>new Promise<Response>(()=>{})),code:'TIMEOUT'}];
 for(const test of cases){
  const provider=new ResendEmailProvider({apiKey:'re_mock_isolation_credential',from:'notices@example.test',siteOrigin:'https://fici.example.test',timeoutMs:20},[{id:'TEST_NOTICE',variablesSchema:z.object({}),render:()=>({subject:'FICI update',text:'A test update is available.',relativePath:'/account'})}],test.transport);
  expect(await provider.send({to:'learner@example.test',template:'TEST_NOTICE',variables:{}})).toMatchObject({success:false,error:{code:test.code}});
  expect(state()).toEqual(before);
 }
});
import {spawn} from 'node:child_process';
import {createNotificationEmailDelivery} from '@/features/notifications/email-delivery';
import {notificationEmailTemplate} from '@/features/notifications/email-template';
vi.mock('next/server',()=>({after:vi.fn()}));
function sql(command:string){
 const result=spawnSync(join(process.env.POSTGRES_BIN!,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',process.env.FICI_EMAIL_TEST_PORT!,'-U','postgres','-d','fici_email_provider','-v','ON_ERROR_STOP=1','-qAt','-c',command],{encoding:'utf8',windowsHide:true,timeout:45000});
 if(result.error||result.status!==0)throw Error('Disposable SQL denied');return result.stdout.trim();
}
const literal=(value:unknown)=>"'"+JSON.stringify(value).replaceAll("'","''")+"'::jsonb";
function contexts(input:unknown){return JSON.parse(sql('set role service_role;select public.notification_email_contexts('+literal(input)+');'));}
it('read-only service projection binds committed notification to current canonical account and exposes no content',()=>{
 const before=state(),n=before.notifications.find((v:{notification_type:string})=>v.notification_type==='ARTIFACT_APPROVED');
 const result=contexts({notificationId:n.id});expect(result).toHaveLength(1);expect(result[0]).toMatchObject({notificationId:n.id,notificationType:n.notification_type,recipientUserId:n.recipient_user_id,accountStatus:'active'});expect(Object.keys(result[0]).sort()).toEqual(['accountStatus','notificationId','notificationType','recipientEmail','recipientUserId']);expect(state()).toEqual(before);
 for(const role of ['anon','authenticated'])expect(()=>sql(`set role ${role};select public.notification_email_contexts(${literal({notificationId:n.id})});`)).toThrow('Disposable SQL denied');
 for(const bad of [{notificationId:n.id,to:'attacker@example.test'},{membershipId:n.id},{membershipId:n.id,membershipType:'UNKNOWN'},{notificationId:n.id,eligible:true}])expect(()=>contexts(bad)).toThrow('Disposable SQL denied');
});
it('actual provider failure/timeout after scheduled callback preserves committed domain and notification state',async()=>{
 const before=state(),n=before.notifications.find((v:{notification_type:string})=>v.notification_type==='ARTIFACT_APPROVED');
 for(const mode of ['failure','timeout']){
  const queue:(()=>Promise<void>)[]=[],events:unknown[]=[];
  const fetcher=vi.fn<typeof fetch>(mode==='failure'?async()=>new Response(null,{status:503}):()=>new Promise<Response>(()=>{}));
  const provider=new ResendEmailProvider({apiKey:'re_mock_delivery_credential',from:'notices@example.test',siteOrigin:'https://fici.example.test',timeoutMs:20},[notificationEmailTemplate],fetcher);
  const d=createNotificationEmailDelivery({read:async input=>contexts(input),provider:()=>provider,schedule:work=>{queue.push(work);},log:event=>{events.push(event);}});
  await d.schedule({notificationId:n.id});expect(queue).toHaveLength(1);expect(fetcher).not.toHaveBeenCalled();await queue[0]();expect(fetcher).toHaveBeenCalledTimes(1);expect(events).toEqual([{notificationId:n.id,outcome:mode==='failure'?'UNAVAILABLE':'TIMEOUT'}]);expect(state()).toEqual(before);
 }
});
it('membership added/removed/moved selectors follow immutable canonical event identity, not arbitrary recipients',()=>{
 const team=JSON.parse(sql(`select to_jsonb(x) from (select a.team_id as source,b.team_id as destination from public.team_memberships a cross join public.team_memberships b where a.user_id='00000000-0000-4000-8000-000000006005' and a.status='active' and b.user_id='00000000-0000-4000-8000-000000006006' and b.status='active' limit 1) x;`));
 const operation=(call:string)=>JSON.parse(sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);select 'RESULT='||(${call})::text;commit;`).split(/\r?\n/).find(s=>s.startsWith('RESULT='))!.slice(7));
 const removed=operation(`public.remove_team_member('${team.source}','00000000-0000-4000-8000-000000006004',null)`);
 const rem=contexts({membershipId:removed.membershipId,membershipType:'MEMBER_REMOVED'});expect(rem).toHaveLength(1);expect(rem[0].recipientUserId).toBe('00000000-0000-4000-8000-000000006004');
 const added=operation(`public.add_team_member('${team.source}','00000000-0000-4000-8000-000000006004','member')`);expect(contexts({membershipId:added.membershipId,membershipType:'MEMBER_ADDED'})).toHaveLength(1);
 const moved=operation(`public.move_team_member(target_user=>'00000000-0000-4000-8000-000000006004',source_team=>'${team.source}',destination_team=>'${team.destination}',move_reason=>null)`);
 expect(contexts({membershipId:moved.targetMembershipId,membershipType:'MEMBER_MOVED'})).toHaveLength(1);expect(contexts({membershipId:moved.sourceMembershipId,membershipType:'MEMBER_MOVED'})).toEqual([]);
 const formerWorkspace=sql(`select id from public.workspaces where team_id='${team.source}' limit 1;`);
 expect(z.uuid().safeParse(formerWorkspace).success).toBe(true);
 expect(sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select 'DENIED='||(public.get_team_workspace_access('${formerWorkspace}') is null)::text;rollback;`)).toContain('DENIED=true');
});

it('M15.27 old exact Submission IDs cannot restore a revoked reviewer scope',()=>{
 expect(sql(`begin;
 create temporary table email_old_link as select s.artifact_id,s.activity_instance_id,s.reviewer_user_id,w.team_id,t.cohort_id from public.submissions s join public.email_isolation_fixture f on f.id=s.id join public.artifacts a on a.id=s.artifact_id join public.workspaces w on w.id=a.workspace_id join public.teams t on t.id=w.team_id;
 grant select on email_old_link to authenticated;
 create temporary table email_pending(payload jsonb);grant select,insert on email_pending to authenticated;
 set local role authenticated;
 select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 insert into email_pending select public.submit_artifact(artifact_id,(public.create_artifact_version(artifact_id,'{"private":"M1527_NEW_DRAFT"}','Email security fixture')->>'id')::uuid,activity_instance_id) from email_old_link;
 select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 do $$begin assert public.can_review_submission((select (payload->>'id')::uuid from email_pending));end$$;
 select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
 select public.assign_master_to_cohort(cohort_id,'00000000-0000-4000-8000-000000006003') from email_old_link;
 select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
 do $$begin
 assert not public.can_review_submission((select (payload->>'id')::uuid from email_pending));
 begin perform public.start_review((select (payload->>'id')::uuid from email_pending));raise exception 'Old email ID restored review';exception when insufficient_privilege then null;end;
 end$$;
 reset role;
 do $$begin assert (select s.reviewer_user_id=o.reviewer_user_id from public.submissions s cross join email_old_link o where s.id=(select (payload->>'id')::uuid from email_pending));end$$;
 rollback;select 'M15.27 old-link reviewer denial PASS';`)).toContain('M15.27 old-link reviewer denial PASS');
});

it('M15.27 membership email failure and explicit replay preserve committed membership/history',async()=>{
 const before=state();
 for(const notificationType of ['MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED']){
  const n=before.notifications.find((v:{notification_type:string})=>v.notification_type===notificationType);
  expect(n).toBeDefined();
  const queue:(()=>Promise<void>)[]=[],events:unknown[]=[];
  const transport=vi.fn<typeof fetch>().mockResolvedValue(new Response(null,{status:503}));
  const provider=new ResendEmailProvider({apiKey:'re_mock_M1527_failure',from:'notices@example.test',siteOrigin:'https://fici.example.test'},[notificationEmailTemplate],transport);
  const d=createNotificationEmailDelivery({read:async input=>contexts(input),provider:()=>provider,schedule:work=>{queue.push(work);},log:event=>{events.push(event);}});
  for(let replay=0;replay<2;replay++){await d.schedule({notificationId:n.id});expect(queue).toHaveLength(replay+1);await queue[replay]();expect(state()).toEqual(before);}
  expect(transport).toHaveBeenCalledTimes(2);
  expect(transport.mock.calls[0][1]!.headers).toEqual(transport.mock.calls[1][1]!.headers);
  expect(events).toEqual([{notificationId:n.id,outcome:'UNAVAILABLE'},{notificationId:n.id,outcome:'UNAVAILABLE'}]);
 }
});
it('uncommitted/rolled-back notification is invisible to separate service projection; committed row becomes visible',async()=>{
 const before=state(),source=before.notifications.find((v:{notification_type:string})=>v.notification_type==='ARTIFACT_APPROVED');
 for(const [suffix,finish] of [['01','rollback'],['02','commit']]){
  const id='00000000-0000-4000-8000-0000000999'+suffix;
  const child=spawn(join(process.env.POSTGRES_BIN!,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',process.env.FICI_EMAIL_TEST_PORT!,'-U','postgres','-d','fici_email_provider','-v','ON_ERROR_STOP=1','-qAt'],{windowsHide:true,stdio:['pipe','pipe','pipe']});
  let out='';const done=new Promise<void>((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(Error('Disposable transaction failed')));});done.catch(()=>{});
  try{
   let timer:ReturnType<typeof setTimeout>;
   const ready=new Promise<void>((resolve,reject)=>{timer=setTimeout(()=>reject(Error('Transaction did not become ready')),15000);child.stdout.on('data',data=>{out+=data;if(out.includes('READY')){clearTimeout(timer);resolve();}});});
   child.stdin.write(`begin;insert into public.notifications(id,recipient_user_id,notification_type,title,body,entity_type,entity_id) select '${id}',recipient_user_id,notification_type,title,body,entity_type,entity_id from public.notifications where id='${source.id}';select 'READY';\n`);
   await ready;expect(contexts({notificationId:id})).toEqual([]);child.stdin.end(finish+';\n');await done;expect(contexts({notificationId:id})).toHaveLength(finish==='commit'?1:0);
  }finally{if(child.exitCode===null){child.stdin.end('rollback;\n');await done;}}
 }
},45000);
// Focused disposable-cluster M15.33 run. Fault triggers exist only inside the
// injecting test transaction, and are removed before it commits.
if(process.env.FICI_NOTIFICATION_INTEGRITY==='1')it('M15.33 submission/approval rollback, atomic approval notifications and email failure integrity',async()=>{
 const q=(v:string)=>"'"+v.replaceAll("'","''")+"'",student='00000000-0000-4000-8000-000000006005',master='00000000-0000-4000-8000-000000006002';
 const source=state().submissions.find((s:{id:string})=>s.id===sql('select id from public.email_isolation_fixture;'));
 const artifact=source.artifact_id,instance=source.activity_instance_id,prior=source.artifact_version_id;
 function actor(who:string,call:string){return JSON.parse(sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${q(who)},true);select 'RESULT='||(${call})::text;commit;`).split(/\r?\n/).find(v=>v.startsWith('RESULT='))!.slice(7));}
 const snapshot=()=>({domain:state(),transport:JSON.parse(sql("select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]') from realtime.messages x;")),actions:JSON.parse(sql("select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]') from public.review_actions x;")),batches:JSON.parse(sql("select coalesce(jsonb_agg(to_jsonb(x)),'[]') from private.approval_notification_batches x;"))});
 const notices=(sid:string)=>state().notifications.filter((n:{entity_id:string})=>n.entity_id===sid) as {id:string;notification_type:string;recipient_user_id:string}[];
 const queue:(()=>Promise<void>)[]=[],logs:{notificationId?:string;outcome:string}[]=[];
 const fetcher=vi.fn<typeof fetch>().mockResolvedValue(new Response(null,{status:503}));
 const provider=new ResendEmailProvider({apiKey:'re_mock_M1533',from:'notices@example.test',siteOrigin:'https://fici.example.test',timeoutMs:20},[notificationEmailTemplate],fetcher);
 const email=createNotificationEmailDelivery({read:async input=>contexts(input),provider:()=>provider,schedule:work=>{queue.push(work);},log:event=>{logs.push(event);}});
 const version=actor(student,`public.create_artifact_version(${q(artifact)},'{"private":"M1533 draft"}','Transaction integrity')`);
 // B: failure AFTER the Submission and Version writes have happened. Capture
 // the rolled-back generated ID through exception detail, never a fake row.
 const beforeSubmission=snapshot();
 const failed=JSON.parse(sql(`begin;
 create function pg_temp.m1533_submit_fault() returns trigger language plpgsql as $$begin
 assert (select status='SUBMITTED' from public.artifact_versions where id=new.artifact_version_id);
 raise exception 'M1533 submission fault' using errcode='P0002',detail=new.id::text;end$$;
 create trigger m1533_submit_fault after insert on public.submissions for each row when(new.artifact_version_id=${q(version.id)}) execute function pg_temp.m1533_submit_fault();
 set local role authenticated;select set_config('request.jwt.claim.sub',${q(student)},true);
 do $$declare detail0 text;begin begin perform public.submit_artifact(${q(artifact)},${q(version.id)},${q(instance)});raise exception 'Fault bypassed';
 exception when no_data_found then assert sqlerrm='M1533 submission fault';get stacked diagnostics detail0=PG_EXCEPTION_DETAIL;perform set_config('m1533.failed_id',detail0,true);end;end$$;
 select 'RESULT='||jsonb_build_object('id',current_setting('m1533.failed_id'))::text;
 reset role;drop trigger m1533_submit_fault on public.submissions;commit;`).split(/\r?\n/).find(v=>v.startsWith('RESULT='))!.slice(7));
 expect(snapshot()).toEqual(beforeSubmission);expect(notices(failed.id)).toEqual([]);
 expect(state().submissions.some((s:{id:string})=>s.id===failed.id)).toBe(false);
 expect(contexts({notificationId:failed.id})).toEqual([]);await email.schedule({notificationId:failed.id});expect(queue).toHaveLength(0);
 const submissionRequest=(sid:string)=>({notificationType:'SUBMISSION_RECEIVED',recipientContext:{sourceId:sid},formatterInput:{},entityReference:{entityType:'submission',entityId:sid},idempotencyKey:'submission-received:'+sid,title:'Submission received',body:'A submission is available for your assigned review.',recipientStrategy:'CURRENT_ASSIGNED_SUBMISSION_REVIEWER'});
 expect(()=>sql(`set role service_role;select public.create_domain_notification(${literal(submissionRequest(failed.id))});`)).toThrow('Disposable SQL denied');expect(snapshot()).toEqual(beforeSubmission);
 // Commit a real Submission; retry the notification independently of the domain.
 const submitted=actor(student,`public.submit_artifact(${q(artifact)},${q(version.id)},${q(instance)})`);
 const deliverSubmission=()=>JSON.parse(sql(`set role service_role;select public.create_domain_notification(${literal(submissionRequest(submitted.id))});`));
 const sn=deliverSubmission();expect(deliverSubmission().id).toBe(sn.id);expect(notices(submitted.id)).toHaveLength(1);expect(sn.recipient_user_id).toBe(master);
 actor(master,`public.start_review(${q(submitted.id)})`);
 // A: fault at the final approval audit write after supersession, CURRENT
 // pointer, Submission and review action. Everything must roll back to V1.
 const beforeApproval=snapshot();
 sql(`begin;
 create function pg_temp.m1533_approval_fault() returns trigger language plpgsql as $$begin
 assert (select status='APPROVED' from public.submissions where id=new.entity_id);
 assert (select current_version_id=${q(version.id)} from public.artifacts where id=${q(artifact)});
 assert (select status='SUPERSEDED' from public.artifact_versions where id=${q(prior)});
 raise exception 'M1533 approval fault' using errcode='P0002';end$$;
 create trigger m1533_approval_fault after insert on public.audit_events for each row when(new.event_type='ARTIFACT_APPROVED' and new.entity_id=${q(submitted.id)}) execute function pg_temp.m1533_approval_fault();
 set local role authenticated;select set_config('request.jwt.claim.sub',${q(master)},true);
 do $$begin begin perform public.approve_artifact(${q(submitted.id)},'M1533 approval');raise exception 'Fault bypassed';exception when no_data_found then assert sqlerrm='M1533 approval fault';end;end$$;
 reset role;drop trigger m1533_approval_fault on public.audit_events;commit;`);
 expect(snapshot()).toEqual(beforeApproval);expect(state().artifacts.find((a:{id:string})=>a.id===artifact).current_version_id).toBe(prior);
 expect(notices(submitted.id).filter(n=>n.notification_type==='ARTIFACT_APPROVED')).toEqual([]);
 expect(JSON.parse(sql(`set role service_role;select public.approval_notification_contexts(${q(submitted.id)});`))).toEqual([]);
 await email.schedule({notificationId:submitted.id});expect(queue).toHaveLength(0);expect(fetcher).not.toHaveBeenCalled();
 // C: canonical notification insertion is inside approval. Its failure must
 // roll back CURRENT, supersession, audit, recipients and dependent state.
 const beforeNotice=snapshot();
 sql(`begin;create function pg_temp.m1533_notice_fault() returns trigger language plpgsql as $$begin raise exception 'M1533 notification fault' using errcode='23514';end$$;
 create trigger m1533_notice_fault before insert on public.notifications for each row when(new.entity_id=${q(submitted.id)} and new.notification_type='ARTIFACT_APPROVED') execute function pg_temp.m1533_notice_fault();
 set local role authenticated;select set_config('request.jwt.claim.sub',${q(master)},true);
 do $$begin begin perform public.approve_artifact(${q(submitted.id)},'M1533 approval');raise exception 'Fault bypassed';exception when check_violation then assert sqlerrm='M1533 notification fault';end;end$$;
 reset role;drop trigger m1533_notice_fault on public.notifications;commit;`);
 expect(snapshot()).toEqual(beforeNotice);
 expect(notices(submitted.id).filter(n=>n.notification_type==='ARTIFACT_APPROVED')).toEqual([]);
 expect(state().submissions.find((s:{id:string})=>s.id===submitted.id).status).toBe('UNDER_REVIEW');
 expect(state().artifacts.find((a:{id:string})=>a.id===artifact).current_version_id).toBe(prior);
 expect(JSON.parse(sql(`set role service_role;select public.approval_notification_contexts(${q(submitted.id)});`))).toEqual([]);
 await email.schedule({notificationId:submitted.id});expect(queue).toHaveLength(0);expect(fetcher).not.toHaveBeenCalled();
 // Successful domain commit, then exact domain retry: no repeated action/audit.
 actor(master,`public.approve_artifact(${q(submitted.id)},'M1533 approval')`);const committed=snapshot();
 actor(master,`public.approve_artifact(${q(submitted.id)},'M1533 approval')`);expect(snapshot()).toEqual(committed);
 const approvalContexts=JSON.parse(sql(`set role service_role;select public.approval_notification_contexts(${q(submitted.id)});`));expect(approvalContexts).toHaveLength(2);
 const requests=approvalContexts.map((c:{recipientContext:unknown;idempotencyKey:string})=>({notificationType:'ARTIFACT_APPROVED',recipientContext:c.recipientContext,formatterInput:{},entityReference:{entityType:'submission',entityId:submitted.id},idempotencyKey:c.idempotencyKey,title:'Artifact approved',body:'An Artifact submission has been approved.',recipientStrategy:'CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM'}));
 expect(notices(submitted.id).filter(n=>n.notification_type==='ARTIFACT_APPROVED')).toHaveLength(2);
 for(const req of requests){const call=`set role service_role;select public.create_domain_notification(${literal(req)});`;const notice=JSON.parse(sql(call));expect(JSON.parse(sql(call)).id).toBe(notice.id);}
 const repaired=notices(submitted.id);expect(repaired.filter(n=>n.notification_type==='ARTIFACT_APPROVED').map(n=>n.recipient_user_id).sort()).toEqual(['00000000-0000-4000-8000-000000006004',student].sort());expect(repaired).toHaveLength(3);
 expect(repaired.some(n=>['00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006003'].includes(n.recipient_user_id))).toBe(false);
 expect(JSON.parse(sql(`select count(*) from realtime.messages where event='notification.changed' and payload->>'id' in(select id::text from public.notifications where entity_id=${q(submitted.id)});`))).toBe(3);
 // D: real scheduler + provider with simulated HTTP failure. Explicit retry
 // uses the same email idempotency key and cannot replay any domain operation.
 const beforeEmail=snapshot();for(const n of repaired)await email.schedule({notificationId:n.id});expect(queue).toHaveLength(3);
 expect(fetcher).not.toHaveBeenCalled();for(const work of queue)await work();expect(fetcher).toHaveBeenCalledTimes(3);expect(snapshot()).toEqual(beforeEmail);
 expect(logs).toEqual(repaired.map(n=>({notificationId:n.id,outcome:'UNAVAILABLE'})));
 await email.schedule({notificationId:repaired[0].id});await queue.at(-1)!();expect(fetcher.mock.calls[3][1]!.headers).toEqual(fetcher.mock.calls[0][1]!.headers);expect(snapshot()).toEqual(beforeEmail);
 // Despite failed email, canonical approval and committed notifications remain
 // exact; notification records have no authority to change workflow state.
 expect(state().versions.find((v:{id:string})=>v.id===version.id).status).toBe('CURRENT');expect(state().submissions.filter((s:{id:string})=>s.id===submitted.id)).toHaveLength(1);
},120000);
