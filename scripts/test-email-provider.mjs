import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testEmailProviderIsolation({root,run,args,childEnv,integrityOnly=false}){
 const name='fici_email_provider';run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  run('psql',[...db,'-qAt'],artifactReviewSecurityFixture(root)+`
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
create table public.email_isolation_fixture(id uuid);
grant select,insert on public.email_isolation_fixture to authenticated;
grant select on public.email_isolation_fixture to service_role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.email_isolation_fixture select (public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team'))->>'id')::uuid from submitted_fixtures where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(id) from public.email_isolation_fixture;
select public.approve_artifact(id,null) from public.email_isolation_fixture;
commit;
set role service_role;
select public.create_domain_notification(jsonb_build_object('notificationType','ARTIFACT_APPROVED','recipientContext',x->'recipientContext','formatterInput','{}'::jsonb,'entityReference',jsonb_build_object('entityType','submission','entityId',s.id),'idempotencyKey',x->>'idempotencyKey','title','Artifact approved','body','An Artifact submission has been approved.','recipientStrategy','CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM')) from public.email_isolation_fixture s cross join lateral jsonb_array_elements(public.approval_notification_contexts(s.id)) x;
`);
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.email-provider.config.mts',...(integrityOnly?['-t','M15.33|provider failures cannot|actual provider failure/timeout','--reporter=verbose']:[])],{cwd:root,encoding:'utf8',windowsHide:true,timeout:240000,env:{...childEnv,...(integrityOnly?{FICI_NOTIFICATION_INTEGRITY:'1'}:{}),FICI_EMAIL_TEST_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw Error('Email isolation test failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
  console.log(result.stdout);console.log('M15.14 provider failure preserves committed approval/Version/in-app notification PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
