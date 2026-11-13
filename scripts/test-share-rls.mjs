import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testShareRls({run,args,root}){
 const name='fici_share_rls';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  run('psql',[...db,'-f','-'],`do $$declare t text;r text;begin
   foreach t in array array['shares','share_snapshots'] loop
    foreach r in array array['anon','authenticated','service_role'] loop
     assert not has_table_privilege(r,'public.'||t,'SELECT,INSERT,UPDATE,DELETE');
    end loop;
   end loop;
  end$$;`);
  let fixture=artifactReviewSecurityFixture(root);
  for(const file of ['activity-research-setup.sql','share-entity-setup.sql','team-sharing-cohort.sql','shared-access.sql'])fixture+=readFileSync(join(root,'tests/integration',file),'utf8');
  const boundary=fixture.lastIndexOf('rollback;');if(boundary<0)throw Error('Missing fixture boundary');
  fixture=fixture.slice(0,boundary)+readFileSync(join(root,'tests/integration/share-rls.sql'),'utf8')+'\nrollback;';
  console.log(run('psql',[...db,'-f','-'],fixture));
 }finally{run('psql',[...args,'-c','drop database '+name+' with (force)']);}
}
