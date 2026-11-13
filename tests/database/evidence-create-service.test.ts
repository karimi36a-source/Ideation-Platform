import {spawnSync} from "node:child_process";
import {join} from "node:path";
import {expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const auth=vi.hoisted(()=>({userId:"00000000-0000-4000-8000-000000006004",calls:[] as string[]}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:async()=>({...auth})}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:async(name:string,args:Record<string,unknown>)=>{
 const allowed:Record<string,string>={create_evidence:"project_id,workspace_id,evidence_type,title,description,source_name,source_url,file_id",link_evidence:"input",update_artifact_draft:"target_version,expected_revision,snapshot,summary,set_summary",verify_evidence:"target_evidence,target_status,verification_note"};
 auth.calls.push(name);
 if(!allowed[name])throw new Error("Unexpected test transport operation");
 const sql=`public.${name}(${allowed[name].split(",").map(key=>literal(args[key])).join(",")})`;
 const lines=query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(auth.userId)},true);select 'RESULT='||${sql}::text;commit;`).split(/\r?\n/);
 const row=lines.find(line=>line.startsWith("RESULT="));if(!row)throw new Error("Canonical RPC row absent");return {data:JSON.parse(row.slice(7)),error:null};
 }})}));
import {createEvidence} from "@/features/evidence/create";
import {linkEvidence} from "@/features/evidence/link";
import {verifyEvidence} from "@/features/evidence/verify";
import {updateArtifactDraft} from "@/features/artifacts/update-draft";
function literal(value:unknown){return value===null||value===undefined?"null":`'${(typeof value==="string"?value:JSON.stringify(value)).replaceAll("'","''")}'`;}
function query(sql:string){
 const port=process.env.FICI_EVIDENCE_TEST_PORT;
 if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw new Error("Disposable PostgreSQL test context required");
 const result=spawnSync(join(process.env.POSTGRES_BIN,process.platform==="win32"?"psql.exe":"psql"),["-X","-h","127.0.0.1","-p",port,"-U","postgres","-d","fici_evidence_create_service","-v","ON_ERROR_STOP=1","-t","-A","-f","-"],{input:sql,encoding:"utf8",windowsHide:true,timeout:50000});
 if(result.error||result.status!==0)throw new Error(`Disposable service transport failed: ${result.error?.message??result.stderr}`);return result.stdout.trim();
}
it("AT-EV-001 actual createEvidence service persists canonically and composes only an explicit link",async()=>{
 const context=JSON.parse(query("select row_to_json(c)::text from public.evidence_service_context c;"));
 const input={projectId:context.project,workspaceId:context.workspace,evidenceType:"CUSTOMER_INTERVIEW",title:" Interview recording ",description:" Recorded observations ",sourceName:" Interview P1, offline "};
 const before=Number(query("select count(*) from public.evidence_links"));
 const created=await createEvidence(input);
 expect(created).toMatchObject({title:"Interview recording",description:"Recorded observations",source_name:"Interview P1, offline",created_by:auth.userId,verification_status:"UNVERIFIED",verified_by:null,verified_at:null,source_url:null,file_id:null,archived_at:null,metadata:{}});
 expect(JSON.parse(query(`select to_jsonb(e)::text from public.evidence e where id=${literal(created.id)};`))).toEqual(created);
 expect(Number(query("select count(*) from public.evidence_links"))).toBe(before);
 const second=await createEvidence(input);expect(second.id).not.toBe(created.id);
 expect(Number(query(`select count(*) from public.evidence where id in(${literal(created.id)},${literal(second.id)})`))).toBe(2);
 const linked=await linkEvidence({evidenceId:created.id,entityType:"GAP",entityId:context.target,relationshipType:"SUPPORTS"});
 expect(linked.evidence_id).toBe(created.id);expect(linked.linked_entity_id).toBe(context.target);
 expect(Number(query("select count(*) from public.evidence_links"))).toBe(before+1);
 expect(JSON.parse(query(`select to_jsonb(e)::text from public.evidence e where id=${literal(created.id)};`))).toEqual(created);
 console.log("AT-EV-001 public createEvidence to PostgreSQL + explicit linkEvidence PASS");
},50000);
it("AT-EV-002 real generic Draft service persists analysis without invoking Evidence services or changing Evidence",async()=>{
 const context=JSON.parse(query("select row_to_json(c)::text from public.evidence_service_context c;"));
 const initial=Number(query("select count(*) from public.evidence"));
 const explicit=await createEvidence({projectId:context.project,workspaceId:context.workspace,evidenceType:"PAPER",title:"Explicit capture",description:"Recorded source facts",sourceName:"Named publication"});
 expect(explicit.verification_status).toBe("UNVERIFIED");
 expect(Number(query("select count(*) from public.evidence"))).toBe(initial+1);
 auth.userId="00000000-0000-4000-8000-000000006005";
 await verifyEvidence({evidenceId:explicit.id,verificationStatus:"VERIFIED",note:"Separate human verification"});
 const snapshot=()=>JSON.parse(query("select jsonb_build_object('evidence',(select jsonb_agg(to_jsonb(e) order by id) from public.evidence e),'links',(select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l),'history',(select jsonb_agg(to_jsonb(h) order by id) from public.evidence_verification_history h),'decisions',(select jsonb_agg(to_jsonb(d) order by id) from public.decision_links d))::text"));
 const before=snapshot();auth.calls=[];
 const fixture={outputType:"ANALYSIS",text:"The existing patents appear to leave a possible gap around X.",source:null,verification:"unverified"};
 const saved=await updateArtifactDraft({artifactVersionId:context.version,expectedDraftRevision:0,contentSnapshot:fixture});
 expect(saved.content_snapshot).toEqual(fixture);
 expect(JSON.parse(query(`select content_snapshot::text from public.artifact_versions where id=${literal(context.version)}`))).toEqual(fixture);
 expect(auth.calls).toEqual(["update_artifact_draft"]);
 expect(snapshot()).toEqual(before);
 // Factual-sounding text cannot supply or synthesize a missing source identity.
 for(const sourceName of [undefined,""," \t\n "]){
  await expect(createEvidence({projectId:context.project,workspaceId:context.workspace,evidenceType:"OTHER",title:"Analysis",description:fixture.text,sourceName})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
 }
 expect(auth.calls).toEqual(["update_artifact_draft"]);
 expect(snapshot()).toEqual(before);
 console.log("AT-EV-002 actual updateArtifactDraft service + explicit source capture + zero Evidence RPC/verification/link side effects PASS");
},50000);
