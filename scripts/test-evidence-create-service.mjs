import {spawnSync} from "node:child_process";
import {join} from "node:path";
import {artifactReviewSecurityFixture} from "./artifact-review-security-fixture.mjs";
export function testEvidenceCreateService({run,args,childEnv,root}){
 const name="fici_evidence_create_service";run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 try{
  run("psql",[...db,"-f","-"],artifactReviewSecurityFixture(root)+`
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create table public.evidence_service_context(project uuid,workspace uuid,target uuid,version uuid);
insert into public.evidence_service_context select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,
(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'GAP','Acceptance Gap','Canonical content','User')->>'id')::uuid,
(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team') from logged_projects where label='Team';
grant select on public.evidence_service_context to authenticated;
commit;`);
  const result=spawnSync(process.execPath,[join(root,"node_modules/vitest/vitest.mjs"),"run","--config","vitest.evidence.config.mts"],{cwd:root,encoding:"utf8",windowsHide:true,timeout:90000,env:{...childEnv,FICI_EVIDENCE_TEST_PORT:String(args[args.indexOf("-p")+1])}});
  if(result.error||result.status!==0)throw new Error(`Evidence public-service acceptance failed: ${result.error?.message??result.stderr}\n${result.stdout}`);
  console.log(result.stdout);
  console.log("AT-EV-001 public createEvidence to PostgreSQL + explicit linkEvidence PASS");
  console.log("AT-EV-002 actual updateArtifactDraft service + explicit source capture + zero Evidence RPC/verification/link side effects PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
