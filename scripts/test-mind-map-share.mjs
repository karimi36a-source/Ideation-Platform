import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testMindMapShare({run,args,root}){
 const name='fici_mind_map_share';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  let fixture=artifactReviewSecurityFixture(root);
  for(const file of ['activity-research-setup.sql','share-entity-setup.sql','team-sharing-cohort.sql','shared-access.sql'])fixture+=readFileSync(join(root,'tests/integration',file),'utf8');
  const boundary=fixture.lastIndexOf('rollback;');if(boundary<0)throw Error('Missing fixture boundary');
  let scenario=readFileSync(join(root,'tests/integration/mind-map-share.sql'),'utf8');
  const checkpoint='-- Revocation and removal preserve frozen history, and deny future access/comments.';
  if(!scenario.includes(checkpoint))throw Error('Missing query isolation fixture checkpoint');
  scenario=scenario.replace(checkpoint,()=>readFileSync(join(root,'tests/integration/shared-query-isolation.sql'),'utf8')+'\n'+checkpoint);
  const masterCheckpoint="update public.role_assignments set ends_at=clock_timestamp()-interval '1 second' where id=(select id from shared_master);";
  if(!scenario.includes(masterCheckpoint))throw Error('Missing Master isolation checkpoint');
  scenario=scenario.replace(masterCheckpoint,'set local role authenticated;\nselect pg_temp.map_query_isolation();\nreset role;\n'+masterCheckpoint);
  scenario+="\nset local role authenticated;\nselect set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);\nselect pg_temp.map_query_isolation();\nreset role;\nselect 'M13.20 exact-Snapshot/collections/search-pagination/joins/relationships/Master/removal/source-scope/File-Version isolation PASS';";
  fixture=fixture.slice(0,boundary)+scenario+'\nrollback;';
  console.log(run('psql',[...db,'-f','-'],fixture));
 }finally{run('psql',[...args,'-c','drop database '+name+' with (force)']);}
}
