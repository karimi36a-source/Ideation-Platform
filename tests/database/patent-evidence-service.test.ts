import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006004',calls:0}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({...state})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:async(name:string,args:{input:unknown})=>{
 if(name!=='link_patent_to_evidence')throw Error('Unexpected RPC');state.calls++;
 try{const text=query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select 'RESULT='||public.link_patent_to_evidence(${literal(JSON.stringify(args.input))}::jsonb)::text;commit;`);const result=text.split(/\r?\n/).find(v=>v.startsWith('RESULT='));return {data:result?JSON.parse(result.slice(7)):null,error:null};}catch{return {data:null,error:{code:'42501'}};}
 }})}));
import {linkPatentToEvidence} from '@/features/patents/evidence';
function literal(value:string){return `'${value.replaceAll("'","''")}'`;}
function query(sql:string){
 const port=process.env.FICI_PATENT_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable context required');
 const result=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_patent_evidence_service','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(result.error||result.status!==0)throw Error('Disposable SQL denied');return result.stdout.trim();
}


it('M12.14 actual service creates exact unverified source-backed Evidence and source link under real database auth',async()=>{
 const fetchSpy=vi.spyOn(globalThis,'fetch').mockRejectedValue(Error('Source fetching forbidden'));
 const contexts=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.patent_evidence_service_context'));
 const make=(label:string,claim=false)=>({patentRecordId:contexts[label].id,evidenceType:claim?'PATENT_CLAIM':'PATENT',title:' Source observation ',description:' Recorded source facts ',...(claim?{claimLocator:' Claims 1–3 '}: {})});
 for(const label of ['Team','Individual']){
  const original=JSON.stringify(contexts[label]);
  const first=await linkPatentToEvidence(make(label)),claim=await linkPatentToEvidence(make(label,true)),repeat=await linkPatentToEvidence(make(label));
  expect(new Set([first.id,claim.id,repeat.id]).size).toBe(3);
  for(const e of [first,claim,repeat]){
   expect(e).toMatchObject({project_id:contexts[label].project_id,workspace_id:contexts[label].workspace_id,created_by:state.userId,source_name:contexts[label].source_database+': '+contexts[label].publication_number,source_url:contexts[label].source_url,verification_status:'UNVERIFIED',verified_by:null,verified_at:null,file_id:null});
   expect(JSON.parse(query('select to_jsonb(e)::text from public.evidence e where id='+literal(e.id)))).toEqual(e);
   const links=JSON.parse(query('select jsonb_agg(to_jsonb(l))::text from public.evidence_links l where evidence_id='+literal(e.id)));
   expect(links).toHaveLength(1);expect(links[0]).toMatchObject({linked_entity_type:'PATENT_RECORD',linked_entity_id:contexts[label].id,relationship_type:'RELATED_TO',created_by:state.userId});
  }
  expect(claim.claim_locator).toBe(' Claims 1–3 ');expect(first.claim_locator).toBeNull();
  expect(JSON.parse(query('select to_jsonb(p)::text from public.patent_records p where id='+literal(contexts[label].id)))).toEqual(JSON.parse(original));
 }
 const calls=state.calls;await expect(linkPatentToEvidence({...make('Team'),sourceUrl:'https://spoof.example.test'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(state.calls).toBe(calls);
 for(const n of [6001,6002,6003,6006,6008]){state.userId='00000000-0000-4000-8000-'+String(n).padStart(12,'0');await expect(linkPatentToEvidence(make('Team'))).rejects.toMatchObject({code:'NOT_FOUND'});}
 state.userId='00000000-0000-4000-8000-000000006005';await expect(linkPatentToEvidence(make('Individual'))).rejects.toMatchObject({code:'NOT_FOUND'});
 state.userId='00000000-0000-4000-8000-000000006004';
 query("begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select public.remove_team_member("+literal(contexts.TeamId.id)+","+literal(state.userId)+",null);commit;");
 await expect(linkPatentToEvidence(make('Team'))).rejects.toMatchObject({code:'NOT_FOUND'});expect((await linkPatentToEvidence(make('Individual'))).created_by).toBe(state.userId);
 expect(fetchSpy).not.toHaveBeenCalled();fetchSpy.mockRestore();
},90000);
