import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006004',calls:0}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({...state})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:async(name:string,args:{input:unknown})=>{
 if(name!=='create_patent_search_log')throw Error('Unexpected RPC');state.calls++;
 try{const text=query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select 'RESULT='||public.create_patent_search_log(${literal(JSON.stringify(args.input))}::jsonb)::text;commit;`);const result=text.split(/\r?\n/).find(v=>v.startsWith('RESULT='));return {data:result?JSON.parse(result.slice(7)):null,error:null};}catch{return {data:null,error:{code:'42501'}};}
 }})}));
import {createPatentSearchLog} from '@/features/patents/search';
function literal(value:string){return `'${value.replaceAll("'","''")}'`;}
function query(sql:string){
 const port=process.env.FICI_PATENT_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable context required');
 const result=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_patent_search_service','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(result.error||result.status!==0)throw Error('Disposable SQL denied');return result.stdout.trim();
}

it('AT-PAT-003 actual public service persists append-only search evolution under current auth',async()=>{
 const fetchSpy=vi.spyOn(globalThis,'fetch').mockRejectedValue(Error('Provider fetch forbidden'));
 const contexts=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.patent_search_service_context'));
 const make=(label:string)=>({projectId:contexts[label].id,workspaceId:contexts[label].primary_workspace_id,activityInstanceId:contexts[label].activity_instance_id,databaseName:'PATENTSCOPE',queryText:' Exact search ',searchMethod:'Keyword family',reason:'Human refinement reason',termsLearned:['pivot'],classificationsLearned:['A01B'],notes:' Private research strategy ',resultsReviewedCount:4,relevantResultsCount:2});
 for(const label of ['Team','Individual']){
  const input=make(label),first=await createPatentSearchLog(input),again=await createPatentSearchLog(input),refined=await createPatentSearchLog({...input,queryText:'Refined query'});
  expect(new Set([first.id,again.id,refined.id]).size).toBe(3);
  expect(first).toMatchObject({searched_by:state.userId,query_text:input.queryText,notes:input.notes,database_name:input.databaseName,terms_learned:input.termsLearned});
  expect(JSON.parse(query('select to_jsonb(p)::text from public.patent_search_logs p where id='+literal(first.id)))).toEqual(first);
  expect(Number(query('select count(*) from public.patent_search_logs where project_id='+literal(input.projectId)))).toBe(3);
 }
 const calls=state.calls;await expect(createPatentSearchLog({...make('Team'),searchedAt:'2000-01-01'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(state.calls).toBe(calls);
 for(const n of [6001,6002,6003,6006,6008]){state.userId='00000000-0000-4000-8000-'+String(n).padStart(12,'0');await expect(createPatentSearchLog(make('Team'))).rejects.toMatchObject({code:'NOT_FOUND'});}
 state.userId='00000000-0000-4000-8000-000000006005';await expect(createPatentSearchLog(make('Individual'))).rejects.toMatchObject({code:'NOT_FOUND'});
 state.userId='00000000-0000-4000-8000-000000006004';await expect(createPatentSearchLog({...make('Team'),workspaceId:contexts.Individual.primary_workspace_id})).rejects.toMatchObject({code:'NOT_FOUND'});
 query("begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select public.remove_team_member("+literal(contexts.TeamId.id)+","+literal(state.userId)+",null);commit;");
 await expect(createPatentSearchLog(make('Team'))).rejects.toMatchObject({code:'NOT_FOUND'});expect((await createPatentSearchLog(make('Individual'))).searched_by).toBe(state.userId);
 expect(fetchSpy).not.toHaveBeenCalled();fetchSpy.mockRestore();
},90000);
