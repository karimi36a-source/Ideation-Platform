import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testShareView({run,args,childEnv,root}){
 const name='fici_share_view';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  let fixture=artifactReviewSecurityFixture(root);
  for(const file of ['activity-research-setup.sql','share-entity-setup.sql','team-sharing-cohort.sql','shared-access.sql'])fixture+=readFileSync(join(root,'tests/integration',file),'utf8');
  const boundary=fixture.lastIndexOf('rollback;');if(boundary<0)throw Error('Missing fixture boundary');
  fixture=fixture.slice(0,boundary)+`
-- Real review context: VIEW attacks must fail against an existing Submission.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into shared_access_context select 'Submission',public.submit_artifact(pg_temp.shared_id('Artifact'),pg_temp.shared_id('V2'),(select id from instances where label='Team'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.shared_id('Submission'));
create table public.view_test_context as table shared_access_context;
insert into public.view_test_context select 'Project',payload from logged_projects where label='Team';
insert into public.view_test_context select 'Activity',jsonb_build_object('id',id) from instances where label='Team';
insert into public.view_test_context select 'TeamB',payload from acceptance_teams where label='B';
insert into public.view_test_context values('EvidenceSource',jsonb_build_object('id',pg_temp.research_source('Evidence'))),('ObjectSource',jsonb_build_object('id',pg_temp.research_source('Gap')));
commit;`;
  run('psql',[...db,'-f','-'],fixture);
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.shared-view.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:240000,env:{...childEnv,FICI_VIEW_TEST_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw Error('VIEW acceptance failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
  console.log(result.stdout);console.log('M13.9 AT-SHARE-003 VIEW server/RPC/RLS/relationships/review/privacy/immutable PASS');
 }finally{run('psql',[...args,'-c','drop database '+name+' with (force)']);}
}
