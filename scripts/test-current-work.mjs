import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testStudentCurrentWork({root,run,args,childEnv,pilotMasterOnly=false,pilotStudentOnly=false,pilotNotificationsOnly=false,pilotProgressOnly=false}){
 const name='fici_current_work';run('psql',[...args,'-c',`create database ${name} template postgres`]);const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  let fixture=artifactReviewSecurityFixture(root)
   .replaceAll('00000000-0000-4000-8000-000000000602','00000000-0000-4000-8000-000000098100')
   .replaceAll('00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000098102');
  fixture=fixture.replace('begin;',()=>`begin;
-- Isolated curriculum follows DRAFT -> definitions -> APPROVED. No guard bypass.
insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000098100','00000000-0000-4000-8000-000000000601','M15.17 isolated curriculum','draft');
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence,status) values('00000000-0000-4000-8000-000000098101','00000000-0000-4000-8000-000000098100',1,'Current work fixture','Test only','Canonical current-work validation',1,'active');
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,status,requires_review) values
 ('00000000-0000-4000-8000-000000098102','00000000-0000-4000-8000-000000098101','Personal Activity','custom','Personal Workspace',1,'active',true),
 ('00000000-0000-4000-8000-000000098001','00000000-0000-4000-8000-000000098101','Team Activity','custom','Team Workspace',2,'active',true),
 ('00000000-0000-4000-8000-000000098002','00000000-0000-4000-8000-000000098101','Concurrent Team Activity','custom','Team Workspace',3,'active',false),
 ('00000000-0000-4000-8000-000000098003','00000000-0000-4000-8000-000000098101','LOCKED_FUTURE_PRIVATE_TITLE','custom','Team Workspace',4,'active',false),
 ('00000000-0000-4000-8000-000000098004','00000000-0000-4000-8000-000000098101','Available Team Activity','custom','Team Workspace',5,'active',false);
insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory) values('00000000-0000-4000-8000-000000098003','00000000-0000-4000-8000-000000098002','approved_output',true);
update public.curriculum_versions set status='approved' where id='00000000-0000-4000-8000-000000098100';
`);
  const marker='-- Canonical parent resource counts';
  if(!fixture.includes(marker))throw Error('Missing canonical fixture boundary');
  fixture=fixture.replace(marker,()=>`update public.teams set status='active' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
`+marker).replace("select '00000000-0000-4000-8000-000000098102',c.id", "select case when p.label='Team' then '00000000-0000-4000-8000-000000098001'::uuid else '00000000-0000-4000-8000-000000098102'::uuid end,c.id");
  run('psql',[...db,'-qAt'],fixture+`
create table public.current_work_fixture(label text primary key,payload jsonb);
grant select,insert,update on public.current_work_fixture to authenticated;
insert into public.current_work_fixture select 'Project '||label,payload from logged_projects;
insert into public.current_work_fixture select 'Team '||label,payload from acceptance_teams;
insert into public.current_work_fixture select 'Artifact '||label,payload from submitted_fixtures;
insert into public.current_work_fixture select 'Instance '||label,jsonb_build_object('id',id) from instances;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.current_work_fixture select 'Approval',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team')) from submitted_fixtures where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((payload->>'id')::uuid) from public.current_work_fixture where label='Approval';
select public.approve_artifact((payload->>'id')::uuid,null) from public.current_work_fixture where label='Approval';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.current_work_fixture select 'V2',public.create_artifact_version((payload->>'artifactId')::uuid,'{"private":"DO_NOT_RETURN"}','Second version') from submitted_fixtures where label='Team';
insert into public.current_work_fixture select 'Revision',public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),(payload->>'id')::uuid,(select id from instances where label='Team')) from public.current_work_fixture where label='V2';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((payload->>'id')::uuid) from public.current_work_fixture where label='Revision';
select public.request_revision((payload->>'id')::uuid,'DO_NOT_RETURN_PRIVATE_FEEDBACK') from public.current_work_fixture where label='Revision';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.current_work_fixture select 'V3',public.create_revision_draft((payload->>'id')::uuid,'{"private":"DO_NOT_RETURN"}','Revision draft') from public.current_work_fixture where label='Revision';
-- A2 owns private Personal work and explicitly shares only its frozen Artifact.
insert into public.current_work_fixture select 'A2 Project',public.create_development_project('A2 PRIVATE PROJECT','individual',(select id from public.workspaces where workspace_type='PERSONAL' and owner_user_id='00000000-0000-4000-8000-000000006005'));
select public.link_project_to_program((payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test')) from public.current_work_fixture where label='A2 Project';
insert into public.current_work_fixture select 'A2 Artifact',public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','A2 PRIVATE ARTIFACT',null,false,false) from public.current_work_fixture where label='A2 Project';
insert into public.current_work_fixture select 'Share',public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',payload->>'artifactId','sourceVersionId',payload->>'initialVersionId','destinationType','TEAM','destinationId',(select payload->>'teamId' from acceptance_teams where label='A'),'permissionLevel','VIEW','shareMode','SNAPSHOT')) from public.current_work_fixture where label='A2 Artifact';
reset role;
insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
 select '00000000-0000-4000-8000-000000098002',cohort_id,project_id,workspace_id,team_id,started_by,started_at,'active','{}' from public.activity_instances where id=(select id from instances where label='Team');
commit;
`);
  if(pilotProgressOnly){
   if(!process.argv.includes('--scenario-only'))for(const file of ['master-cohort-overview','pending-review-queue','revision-status','learning-progress']){
    console.log(run('psql',[...db,'-qAt'],readFileSync(join(root,'tests/integration',file+'.sql'),'utf8')));
   }
   const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.current-work.config.mts','-t','M15.32','--reporter=verbose'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:420000,env:{...childEnv,FICI_CURRENT_WORK_TEST_PORT:String(args[args.indexOf('-p')+1]),FICI_PILOT_PROGRESS:'1'}});
   if(result.error||result.status!==0)throw Error('Pilot progress acceptance failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
   console.log(result.stdout);console.log('M15.32 canonical progress/review/revision/exact-approval/dependency/privacy PASS');return;
  }
  if(pilotNotificationsOnly){
   const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.current-work.config.mts','-t','M15.31','--reporter=verbose'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:300000,env:{...childEnv,FICI_CURRENT_WORK_TEST_PORT:String(args[args.indexOf('-p')+1]),FICI_PILOT_NOTIFICATIONS:'1'}});
   if(result.error||result.status!==0)throw Error('Pilot notification acceptance failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
   console.log(result.stdout);console.log('M15.31 notification lifecycle/recipient-isolation/read-realtime/email-policy PASS');return;
  }
  if(pilotStudentOnly){
   const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.current-work.config.mts','-t','M15.30','--reporter=verbose'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:300000,env:{...childEnv,FICI_CURRENT_WORK_TEST_PORT:String(args[args.indexOf('-p')+1]),FICI_PILOT_STUDENT:'1'}});
   if(result.error||result.status!==0)throw Error('Pilot Student acceptance failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
   console.log(result.stdout);console.log('M15.30 Student/personal-Team-tools/chat/Share/review/current-progress/membership/privacy PASS');return;
  }
  if(pilotMasterOnly){
   const output=run('psql',[...db,'-qAt'],readFileSync(join(root,'tests/integration/pilot-master-acceptance.sql'),'utf8'));
   if(!output.includes('M15.29 assigned-Master/activity-review/exact-Version/notifications/queue/progress/privacy/replacement PASS'))throw Error('Pilot Master acceptance incomplete');
   console.log(output);return;
  }
  run('psql',[...db,'-qAt'],readFileSync(join(root,'tests/integration/master-cohort-overview.sql'),'utf8'));
  run('psql',[...db,'-qAt'],readFileSync(join(root,'tests/integration/pending-review-queue.sql'),'utf8'));
  run('psql',[...db,'-qAt'],readFileSync(join(root,'tests/integration/revision-status.sql'),'utf8'));
  run('psql',[...db,'-qAt'],readFileSync(join(root,'tests/integration/learning-progress.sql'),'utf8'));
  const authorizationMarker='M15.25 cross-Cohort/foreign-history/Share/direct-ID/source-RLS authorization gate PASS';
  const authorizationOutput=run('psql',[...db,'-qAt'],readFileSync(join(root,'tests/integration/progress-authorization.sql'),'utf8'));
  if(!authorizationOutput.includes(authorizationMarker))throw Error('Progress authorization suite did not complete');
  console.log(authorizationMarker);
  // The integrated service file now runs the approval lifecycle and all M15.25
  // attacks through separate authenticated psql sessions. Budget the whole file;
  // its individual SQL/test limits stay at 45 seconds, with no assertion skips.
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.current-work.config.mts','--reporter=verbose'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:480000,env:{...childEnv,FICI_CURRENT_WORK_TEST_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw Error('Current work validation failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);console.log(result.stdout);console.log('M15.17 authenticated self contexts/Activity candidates/revision/approval/removal/RLS/unread aggregation PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}



