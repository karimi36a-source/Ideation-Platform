import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006004',calls:0}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({...state})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:async(name:string,args:{input:unknown})=>{
 if(name!=='create_patent_record')throw Error('Unexpected RPC');state.calls++;
 try{const text=query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select 'RESULT='||public.create_patent_record(${literal(JSON.stringify(args.input))}::jsonb)::text;commit;`);const result=text.split(/\r?\n/).find(v=>v.startsWith('RESULT='));return {data:result?JSON.parse(result.slice(7)):null,error:null};}catch{return {data:null,error:{code:'42501'}};}
 }})}));
import {createPatentRecord} from '@/features/patents/create';
function literal(value:string){return `'${value.replaceAll("'","''")}'`;}
function query(sql:string){
 const port=process.env.FICI_PATENT_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable context required');
 const result=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_patent_create_service','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(result.error||result.status!==0)throw Error('Disposable SQL denied');return result.stdout.trim();
}
it('AT-PAT-001 public service persists exact source/notes/relevance and denies scope/creator attacks without side effects',async()=>{
 const fetchSpy=vi.spyOn(globalThis,'fetch').mockRejectedValue(Error('Source fetch forbidden'));
 const contexts=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.patent_service_context'));
 const before=query("select jsonb_build_object('evidence',(select jsonb_agg(to_jsonb(e) order by id) from public.evidence e),'links',(select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l))::text");
 const make=(label:string)=>({projectId:contexts[label].id,workspaceId:contexts[label].primary_workspace_id,publicationNumber:' WO 2025/012345 A1 ',title:' Source title ',sourceDatabase:'PATENTSCOPE',sourceUrl:'https://research.example.test/source',whyRetained:' Human notes ',relevanceStatus:'POSSIBLY_RELEVANT'});
 for(const label of ['Team','Individual']){
  const input=make(label);const created=await createPatentRecord(input);
  expect(created).toMatchObject({publication_number:input.publicationNumber,title:input.title,source_url:input.sourceUrl,source_database:input.sourceDatabase,why_retained:input.whyRetained,relevance_status:input.relevanceStatus,created_by:state.userId});
  expect(JSON.parse(query(`select to_jsonb(p)::text from public.patent_records p where id=${literal(created.id)}`))).toEqual(created);
  const second=await createPatentRecord(input);expect(second.id).not.toBe(created.id);
  expect(Number(query(`select count(*) from public.patent_records where id in(${literal(created.id)},${literal(second.id)})`))).toBe(2);
 }
 const calls=state.calls;await expect(createPatentRecord({...make('Team'),createdBy:state.userId})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(state.calls).toBe(calls);
 for(const n of [6001,6002,6003,6006,6008]){state.userId=`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;await expect(createPatentRecord(make('Team'))).rejects.toMatchObject({code:'NOT_FOUND'});}
 state.userId='00000000-0000-4000-8000-000000006005';await expect(createPatentRecord(make('Individual'))).rejects.toMatchObject({code:'NOT_FOUND'});
 state.userId='00000000-0000-4000-8000-000000006004';await expect(createPatentRecord({...make('Team'),workspaceId:contexts.Individual.primary_workspace_id})).rejects.toMatchObject({code:'NOT_FOUND'});
 const minimal={...make('Team'),relevanceStatus:undefined,whyRetained:null};expect((await createPatentRecord(minimal)).relevance_status).toBe('NOT_REVIEWED');
 query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select public.remove_team_member(${literal(contexts.TeamId.id)},${literal(state.userId)},null);commit;`);
 await expect(createPatentRecord(make('Team'))).rejects.toMatchObject({code:'NOT_FOUND'});expect((await createPatentRecord(make('Individual'))).created_by).toBe(state.userId);
 expect(query("select jsonb_build_object('evidence',(select jsonb_agg(to_jsonb(e) order by id) from public.evidence e),'links',(select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l))::text")).toBe(before);
 expect(fetchSpy).not.toHaveBeenCalled();fetchSpy.mockRestore();
},90000);
