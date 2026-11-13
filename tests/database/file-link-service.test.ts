import {spawnSync} from "node:child_process";
import {join} from "node:path";
import {expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const actor=vi.hoisted(()=>({userId:"00000000-0000-4000-8000-000000006004"}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:async()=>({...actor})}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:async(name:string,args:{input:unknown})=>{
 if(name!=="link_file")throw new Error("Unexpected RPC");
 try{const text=query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(actor.userId)},true);select 'RESULT='||public.link_file(${literal(JSON.stringify(args.input))}::jsonb)::text;commit;`);const row=text.split(/\r?\n/).find(v=>v.startsWith('RESULT='));return {data:row?JSON.parse(row.slice(7)):null,error:null};}catch{return {data:null,error:{code:"42501"}};}
 }})}));
import {linkFile} from "@/features/files/link";
function literal(value:string){return `'${value.replaceAll("'","''")}'`;}
function query(sql:string){
 const port=process.env.FICI_FILE_LINK_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error("Disposable test context required");
 const result=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_file_link_operations','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(result.error||result.status!==0)throw Error('Disposable SQL rejected');return result.stdout.trim();
}
it('public linkFile returns canonical row without File metadata, preserves creator on authorized retry and denies exact-ID foreign users',async()=>{
 const context=JSON.parse(query('select row_to_json(c)::text from public.file_link_test_context c'));
 const input={fileId:context.file_id,entityType:'DEVELOPMENT_OBJECT',entityId:context.target,relationshipType:'REFERENCE'};
 const first=await linkFile(input);expect(first.file_id).toBe(context.file_id);expect(first.entity_id).toBe(context.target);expect(first.created_by).toBe(actor.userId);
 expect(JSON.parse(query(`select to_jsonb(l)::text from public.file_links l where id=${literal(first.id)}`))).toEqual(first);
 expect(first).not.toHaveProperty('filename');expect(first).not.toHaveProperty('storage_reference');
 actor.userId='00000000-0000-4000-8000-000000006005';expect(await linkFile(input)).toEqual(first);
 actor.userId='00000000-0000-4000-8000-000000006006';await expect(linkFile(input)).rejects.toMatchObject({code:'NOT_FOUND'});
 actor.userId='00000000-0000-4000-8000-000000006004';
},45000);
