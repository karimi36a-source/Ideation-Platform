import {spawnSync} from "node:child_process";
import {join} from "node:path";
import {artifactReviewSecurityFixture} from "./artifact-review-security-fixture.mjs";
export function testFileUploadService({run,args,childEnv,root}){
 const name="fici_file_upload_service";run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
 run("psql",[...db,"-f","-"],artifactReviewSecurityFixture(root)+`
 reset role;
 create table public.file_service_context(label text,payload jsonb);
 insert into public.file_service_context select label,payload from logged_projects where label in ('Individual','Team');
 insert into public.file_service_context select 'TeamId',jsonb_build_object('id',payload->>'teamId') from acceptance_teams where label='A';
 grant select on public.file_service_context to authenticated;
 commit;`);
 const result=spawnSync(process.execPath,[join(root,"node_modules/vitest/vitest.mjs"),"run","--config","vitest.files.config.mts"],{cwd:root,encoding:"utf8",windowsHide:true,timeout:180000,env:{...childEnv,FICI_FILE_TEST_PORT:String(args[args.indexOf("-p")+1])}});
 if(result.error||result.status!==0)throw new Error(`File public-service acceptance failed: ${result.error?.message??result.stderr}\n${result.stdout}`);
 console.log(result.stdout);
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
