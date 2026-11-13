import {spawn} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import assert from 'node:assert/strict';
import {session8Fixture} from './session8-fixture.mjs';
export async function testSession8Reading({run,args,binary,childEnv,root}){
 const name='fici_session8_reading';run('psql',[...args,'-c','create database '+name+' template postgres']);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  const scenario=readFileSync(join(root,'tests/integration/session8-patent-reading.sql'),'utf8');
  const marker="insert into reading select 'framework'";assert.equal(scenario.split(marker).length,2,'Session 8 concurrency fixture boundary');
  run('psql',[...db,'-f','-'],session8Fixture(root)+scenario.split(marker)[0]+`
reset role;create table public.session8_test_context as select pg_temp.reading_id('session8') activity,pg_temp.reading_id('patent') patent,(select data from reading where label='notes') notes;commit;`);
  const context=JSON.parse(run('psql',[...db,'-t','-A','-c','select row_to_json(x)::text from public.session8_test_context x']).trim());
  const call=()=>new Promise((resolve,reject)=>{
   const child=spawn(binary('psql'),[...db,'-t','-A','-f','-'],{cwd:root,env:childEnv,windowsHide:true});let out='',err='';
   const timer=setTimeout(()=>{child.kill();reject(Error('Session 8 save concurrency timeout'));},60000);
   child.stdout.on('data',chunk=>out+=chunk);child.stderr.on('data',chunk=>err+=chunk);child.on('error',reject);
   child.on('close',code=>{clearTimeout(timer);if(code!==0)return reject(Error(err));const line=out.split(/\r?\n/).find(x=>x.startsWith('RESULT='));if(!line)return reject(Error('Missing canonical reading result'));resolve(JSON.parse(line.slice(7)));});
   const notes=JSON.stringify(context.notes).replaceAll("'","''");
   child.stdin.end("begin;set local statement_timeout='50s';set local role authenticated;set local request.jwt.claim.sub='00000000-0000-4000-8000-000000006005';select 'RESULT='||public.save_patent_reading_framework('"+context.activity+"','"+context.patent+"','"+notes+"'::jsonb,null)::text;select pg_sleep(0.1);commit;");
  });
  const results=await Promise.all([call(),call()]);assert.deepEqual(results[0],results[1]);
  const counts=JSON.parse(run('psql',[...db,'-t','-A','-c',"select json_build_array((select count(*) from public.artifacts where artifact_type='PATENT_READING_FRAMEWORK'),(select count(*) from public.artifact_versions v join public.artifacts a on a.id=v.artifact_id where a.artifact_type='PATENT_READING_FRAMEWORK'),(select count(*) from public.activity_outputs where activity_instance_id='"+context.activity+"'),(select count(*) from public.activity_research_links where activity_instance_id='"+context.activity+"'))::text"]).trim());
  assert.deepEqual(counts,[1,1,1,1]);
  console.log('M12.26 independent concurrent first saves one canonical Artifact/Version/output/source reference PASS');
 }finally{run('psql',[...args,'-c','drop database '+name+' with(force)']);}
}
