import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006005',calls:0}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({...state})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:async(name:string,args:{input:unknown})=>{if(name!=='finalize_decision')throw Error('Unexpected operation');state.calls++;try{const out=query("begin;set local role authenticated;select set_config('request.jwt.claim.sub',"+literal(state.userId)+",true);select 'RESULT='||public.finalize_decision("+literal(JSON.stringify(args.input))+"::jsonb)::text;commit;");return {data:JSON.parse(out.split(/\r?\n/).find(s=>s.startsWith('RESULT='))!.slice(7)),error:null};}catch{return {data:null,error:{code:'42501'}};}}})}));
import {finalizeDecision} from '@/features/decisions/finalize';
function literal(v:string){return "'"+v.replaceAll("'","''")+"'";}
function query(sql:string){const port=process.env.FICI_DECISION_EVIDENCE_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable context required');const r=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_decision_evidence','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:sql,encoding:'utf8',windowsHide:true,timeout:45000});if(r.error||r.status!==0)throw Error('SQL denied');return r.stdout.trim();}
it('M12.18 public service finalizes with real unchanged Evidence, returns canonical Decision and denies stale/foreign authority',async()=>{
 const ctx=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.de_test_context'));
 const before=query('select jsonb_agg(to_jsonb(e) order by id)::text from public.evidence e');
 const first=await finalizeDecision(ctx.Service),retry=await finalizeDecision({...ctx.Service,linkedEvidenceIds:[...ctx.Service.linkedEvidenceIds].reverse().concat(ctx.Service.linkedEvidenceIds[0])});
 expect(first).toEqual(retry);expect(first.status).toBe('FINALIZED');expect(first.outcome).toBe(ctx.Service.outcome);
 expect(JSON.parse(query('select to_jsonb(d)::text from public.decisions d where id='+literal(first.id)))).toEqual(first);
 const statuses=JSON.parse(query("begin;set local role authenticated;select set_config('request.jwt.claim.sub',"+literal(state.userId)+",true);select 'RESULT='||jsonb_agg(jsonb_build_object('type',l.linked_entity_type,'relation',l.relationship_type,'status',e.verification_status,'verifier',e.verified_by) order by e.verification_status)::text from public.evidence_links l join public.evidence e on e.id=l.evidence_id where l.linked_entity_id="+literal(first.id)+";commit;").split(/\r?\n/).find(s=>s.startsWith('RESULT='))!.slice(7));
 expect(statuses).toHaveLength(2);expect(statuses.every((x:{type:string;relation:string})=>x.type==='DECISION'&&x.relation==='SUPPORTS')).toBe(true);expect(statuses.map((x:{status:string})=>x.status).sort()).toEqual(['UNVERIFIED','VERIFIED']);
 expect(query('select jsonb_agg(to_jsonb(e) order by id)::text from public.evidence e')).toBe(before);
 for(const n of [6001,6002,6003,6004,6006,6008]){state.userId='00000000-0000-4000-8000-'+String(n).padStart(12,'0');await expect(finalizeDecision(ctx.Service)).rejects.toMatchObject({code:'NOT_FOUND'});}
 query("begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select public.remove_team_member("+literal(ctx.TeamId)+",'00000000-0000-4000-8000-000000006005');commit;");state.userId='00000000-0000-4000-8000-000000006005';await expect(finalizeDecision(ctx.Service)).rejects.toMatchObject({code:'NOT_FOUND'});
},90000);
