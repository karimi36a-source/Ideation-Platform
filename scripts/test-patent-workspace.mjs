import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testPatentWorkspace({run,args,childEnv,root}){
 const name='fici_patent_workspace';run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
 run('psql',[...db,'-f','-'],artifactReviewSecurityFixture(root)+`
reset role;
create table public.patent_workspace_context(label text,payload jsonb);
insert into public.patent_workspace_context select label,payload from logged_projects where label in ('Team','Individual');
insert into public.patent_workspace_context select 'TeamId',jsonb_build_object('id',payload->>'teamId') from acceptance_teams where label='A';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into public.patent_workspace_context select 'Patent'||label,public.create_patent_record(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','publicationNumber','WO SOURCE 001','title','Canonical source title','sourceDatabase','PATENTSCOPE','sourceUrl','https://example.test/patent','whyRetained','Private retained research rationale','relevanceStatus','POSSIBLY_RELEVANT')) from logged_projects where label in ('Team','Individual');
select public.link_patent_to_evidence(jsonb_build_object('patentRecordId',payload->>'id','evidenceType','PATENT','title','Patent observation','description','Source-backed facts')) from public.patent_workspace_context where label='PatentTeam';
select public.link_patent_to_evidence(jsonb_build_object('patentRecordId',payload->>'id','evidenceType','PATENT_CLAIM','claimLocator',' Claim 7, paragraph 2 ','title','Claim observation','description','Claim source facts')) from public.patent_workspace_context where label='PatentTeam';
select public.create_patent_search_log(jsonb_build_object('projectId',p.payload->>'id','workspaceId',p.payload->>'primary_workspace_id','activityInstanceId',i.id,'databaseName','PATENTSCOPE','queryText','Private search query','searchMethod','Keyword family','reason','Private strategy','notes','Private human notes')) from logged_projects p join instances i on i.label='Team' where p.label='Team';
commit;`);
 const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.patent-workspace.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:180000,env:{...childEnv,FICI_PATENT_TEST_PORT:String(args[args.indexOf('-p')+1])}});
 if(result.error||result.status!==0)throw new Error('Patent Workspace acceptance failed: '+(result.error?.message??result.stderr)+'\n'+result.stdout);
 console.log(result.stdout);console.log('M12.15 real PostgreSQL Patent Workspace canonical reads + scope gates + Personal/Team/revocation PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
