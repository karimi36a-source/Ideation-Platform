import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testShareComments({run,args,childEnv,root}){
 const name='fici_share_comments';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  let fixture=artifactReviewSecurityFixture(root);
  for(const file of ['activity-research-setup.sql','share-entity-setup.sql','team-sharing-cohort.sql','shared-access.sql'])fixture+=readFileSync(join(root,'tests/integration',file),'utf8');
  const boundary=fixture.lastIndexOf('rollback;');if(boundary<0)throw Error('Missing fixture boundary');
  fixture=fixture.slice(0,boundary)+`
-- Real review context: VIEW attacks must fail against an existing Submission.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- The M13.5 fixture deliberately revoked its COMMENT Share. Create a fresh
-- canonical Share; keep the revoked row/Snapshot as preserved history.
-- Preserve/revoke the intentionally incomplete PATENT COMMENT fixture rather
-- than bypassing normal retry integrity checks for the non-versioned test.
update public.shares set revoked_at=clock_timestamp(),revoked_by=public.current_platform_user_id() where id=pg_temp.shared_id('MissingSnapshot');
update shared_access_context set payload=public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',pg_temp.shared_id('Artifact'),'sourceVersionId',pg_temp.shared_id('V2'),'destinationType','TEAM','destinationId',(select payload->>'teamId' from acceptance_teams where label='B'),'permissionLevel','COMMENT','shareMode','SNAPSHOT')) where label='Comment';
insert into shared_access_context select 'Submission',public.submit_artifact(pg_temp.shared_id('Artifact'),pg_temp.shared_id('V2'),(select id from instances where label='Team'));
-- Positive Draft comment with no Submission: discussion is not formal review.
do $$declare p jsonb;a jsonb;r jsonb;begin
 select payload into p from logged_projects where label='Team';
 a:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Draft discussion only',null,false,false);
 insert into shared_access_context values('DraftArtifact',a);
 r:=public.share_entity(jsonb_build_object('entityType','ARTIFACT','entityId',a->>'artifactId','sourceVersionId',a->>'initialVersionId','destinationType','TEAM','destinationId',(select payload->>'teamId' from acceptance_teams where label='B'),'permissionLevel','COMMENT','shareMode','SNAPSHOT'));
 insert into shared_access_context values('DraftShare',r);
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(pg_temp.shared_id('Submission'));
create table public.comment_test_context as table shared_access_context;
insert into public.comment_test_context select 'Project',payload from logged_projects where label='Team';
insert into public.comment_test_context select 'Activity',jsonb_build_object('id',id) from instances where label='Team';
insert into public.comment_test_context select 'TeamB',payload from acceptance_teams where label='B';
insert into public.comment_test_context values('EvidenceSource',jsonb_build_object('id',pg_temp.research_source('Evidence'))),('ObjectSource',jsonb_build_object('id',pg_temp.research_source('Gap')));
commit;`;
  run('psql',[...db,'-f','-'],fixture);
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.shared-comments.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:240000,env:{...childEnv,FICI_COMMENT_TEST_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw Error('COMMENT acceptance failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
  console.log(result.stdout);console.log('M13.10 AT-SHARE-004 COMMENT exact-V2/thread/source-history/revocation/VIEW-denial/privacy PASS');
 }finally{run('psql',[...args,'-c','drop database '+name+' with (force)']);}
}
