import {spawn} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export async function testShareEntityConcurrency({run,args,binary,childEnv,root}){
 const database='fici_share_entity_race',children=[];
 run('psql',[...args,'-c',`create database ${database} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==='-d'?database:v);
 const query=sql=>run('psql',[...db,'-t','-A','-c',sql]).trim();
 function session(label,version,hold=false){
  let readySignal;const ready=new Promise(resolve=>readySignal=resolve);
  let child;
  const done=new Promise((resolve,reject)=>{
   child=spawn(binary('psql'),[...db,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});children.push(child);
   let out='',err='';const timer=setTimeout(()=>{child.kill();reject(Error('Share concurrency timeout'));},45000);
   child.stdout.on('data',d=>{out+=d;if(out.includes('READY'))readySignal();});child.stderr.on('data',d=>err+=d);
   child.on('error',reject);child.on('exit',code=>{clearTimeout(timer);if(code===0)resolve(out);else reject(Error(`Share concurrency failure: ${err}`));});
   child.stdin.write(`begin;set local application_name='share_race_${label}';set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);select 'SHARE='||(public.share_entity((select request||jsonb_build_object('sourceVersionId',${version==='first'?'v1':'v2'}) from share_race))->>'id');select 'READY';\n`);
   if(!hold)child.stdin.end('commit;\n');
  });
  // Attach rejection immediately while a sibling is deliberately blocked.
  done.catch(()=>{});
  return {ready,done,finish:terminal=>child.stdin.end(`${terminal};\n`)};
 }
 try{
  run('psql',[...db,'-f','-'],artifactReviewSecurityFixture(root)+`
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Regression: an earlier identically titled source must never select scope.
select public.create_patent_record(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','publicationNumber','Decoy scope','title','Original source','sourceDatabase','PATENTSCOPE','sourceUrl','https://example.test/decoy')) from logged_projects where label='Individual';
`+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/share-entity-setup.sql'),'utf8')+`
reset role;
create table share_race(request jsonb,v1 uuid,v2 uuid);
create table share_race_scope(project_id uuid,destination_id uuid);
insert into share_race_scope select (p.payload->>'id')::uuid,(t.payload->>'teamId')::uuid
 from logged_projects p cross join acceptance_teams t where p.label='Team' and t.label='B';
grant select on share_race to authenticated;
commit;`);
  for(const mode of ['commit','rollback','different']){
   run('psql',[...db,'-f','-'],`begin;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare p public.development_projects;a jsonb;v jsonb;begin
 select * into p from public.development_projects where id=(select project_id from share_race_scope);
 a:=public.create_artifact(p.id,p.primary_workspace_id,'DEVELOPED_CONCEPT','Race ${mode}',null,false,false);
 v:=public.create_artifact_version((a->>'artifactId')::uuid,'{"notes":"V2"}','Second');
 delete from share_race;
 insert into share_race select jsonb_build_object('entityType','ARTIFACT','entityId',a->>'artifactId','destinationType','TEAM','destinationId',destination_id,'permissionLevel','VIEW','shareMode','SNAPSHOT'),(a->>'initialVersionId')::uuid,(v->>'id')::uuid from share_race_scope;
 assert found;
end$$;commit;`);
   const first=session('first','first',true);
   await Promise.race([first.ready,first.done.then(()=>{throw Error('Share session exited before readiness');})]);
   let second;
   if(mode==='different'){
    // The error is caught only by this test session to assert its exact safe code.
    const sql=`begin;set local application_name='share_race_second';set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);do $$begin perform public.share_entity((select request||jsonb_build_object('sourceVersionId',v2) from share_race));raise exception 'Conflict missing';exception when sqlstate 'P1304' then null;end$$;commit;`;
    let child;const done=new Promise((resolve,reject)=>{child=spawn(binary('psql'),[...db,'-f','-'],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let err='';const timer=setTimeout(()=>{child.kill();reject(Error('Version conflict timeout'));},45000);child.stderr.on('data',d=>err+=d);child.on('error',reject);child.on('exit',code=>{clearTimeout(timer);if(code===0)resolve('CONFLICT');else reject(Error(err));});child.stdin.end(sql);});done.catch(()=>{});second={done};
   }else second=session('second','first');
   let blocked=false;
   for(let n=0;n<100;n++){
    if(query("select count(*) from pg_stat_activity where application_name='share_race_second' and wait_event_type='Lock'")==='1'){blocked=true;break;}
    await new Promise(resolve=>setTimeout(resolve,20));
   }
   if(!blocked)throw Error('Competing Share did not serialize');
   first.finish(mode==='rollback'?'rollback':'commit');
   const [a,b]=await Promise.all([first.done,second.done]);
   const id=out=>out.split(/\r?\n/).find(line=>line.startsWith('SHARE='))?.slice(6);
   if(!id(a)||mode==='commit'&&id(a)!==id(b)||mode==='rollback'&&(!id(b)||id(a)===id(b)))throw Error('Unsafe duplicate Share result');
   if(query("select count(*) from public.shares where shared_entity_id=(select (request->>'entityId')::uuid from share_race)")!=='1')throw Error('Duplicate/partial Share');
   if(query("select count(*) from public.share_snapshots ss join public.shares s on s.id=ss.share_id where s.shared_entity_id=(select (request->>'entityId')::uuid from share_race) and ss.source_version_id=(select v1 from share_race)")!=='1')throw Error('Wrong Snapshot binding');
   if(query("select count(*) from public.audit_events where event_type='SHARE_CREATED' and entity_id in(select id from public.shares where shared_entity_id=(select (request->>'entityId')::uuid from share_race))")!=='1')throw Error('Wrong audit count');
  }
  console.log('M13.4 concurrent duplicate/rollback/different-version PASS');
 }finally{
  for(const child of children)if(child.exitCode===null)child.kill();
  run('psql',[...args,'-c',`drop database ${database} with (force)`]);
 }
}
