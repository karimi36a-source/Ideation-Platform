import {beforeEach,afterEach,expect,it,vi} from 'vitest';
import {patentRecordSchema} from '@/features/patents/schema';
import {evidenceSchema} from '@/features/evidence/schema';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({rpc:vi.fn(),auth:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
import {createPatentRecord} from '@/features/patents/create';
import {createEvidence} from '@/features/evidence/create';
import {linkPatentToEvidence} from '@/features/patents/evidence';
import {verifyEvidence} from '@/features/evidence/verify';
const id='00000000-0000-4000-8000-000000006004';
// Test-only future output: no production AI type, table, renderer, or persistence.
const analysis=Object.freeze({type:'AI_ANALYSIS',label:'AI Analysis',text:'Possible technical difference; human investigation required.',sourcePatentRecordId:id});
const patent={projectId:id,workspaceId:id,publicationNumber:'WO SOURCE 1',title:'Source title',sourceDatabase:'PATENTSCOPE',sourceUrl:'https://source.example.test/patent',abstractText:'Exact source abstract',whyRetained:'Human research note',relevanceStatus:'POSSIBLY_RELEVANT'};
const evidence={projectId:id,workspaceId:id,evidenceType:'PATENT',title:'Source fact',description:'Human-recorded source observation',sourceName:'Patent publication'};
beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:id});m.rpc.mockRejectedValue(Error('Unexpected automatic mutation'));});
afterEach(()=>vi.restoreAllMocks());
it('AT-PAT-002 keeps the simulated future output AI_ANALYSIS-labeled and outside canonical source schemas',()=>{
 expect(analysis.type).toBe('AI_ANALYSIS');expect(analysis.label).toBe('AI Analysis');
 expect(patentRecordSchema.safeParse(analysis).success).toBe(false);expect(evidenceSchema.safeParse(analysis).success).toBe(false);
 expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['analysis','aiAnalysis','type','label','noveltyScore','patentabilityStatus','legalConclusion','force'])('rejects analysis/conclusion field %s without Patent/Evidence writes',async key=>{
 const fetch=vi.spyOn(globalThis,'fetch').mockRejectedValue(Error('No provider calls'));
 await expect(createPatentRecord({...patent,[key]:analysis})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(createEvidence({...evidence,[key]:analysis})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(linkPatentToEvidence({patentRecordId:id,evidenceType:'PATENT_CLAIM',title:'Claim source',description:'Source observation',claimLocator:'Claim 7',[key]:analysis})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(verifyEvidence({evidenceId:id,verificationStatus:'VERIFIED',[key]:analysis})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 expect(m.rpc).not.toHaveBeenCalled();expect(fetch).not.toHaveBeenCalled();
});
it('AI_ANALYSIS is not a Patent relevance or Evidence type/verification state',async()=>{
 await expect(createPatentRecord({...patent,relevanceStatus:analysis.type})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(createEvidence({...evidence,evidenceType:analysis.type})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(verifyEvidence({evidenceId:id,verificationStatus:analysis.type})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['PATENTABLE','NOT PATENTABLE','NOVEL','NOT NOVEL','INFRINGEMENT','CLEAR TO OPERATE','VALID','INVALID'])('does not coerce legal conclusion %s into research/verification metadata',async conclusion=>{
 await expect(createPatentRecord({...patent,relevanceStatus:conclusion})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(verifyEvidence({evidenceId:id,verificationStatus:conclusion})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 expect(m.rpc).not.toHaveBeenCalled();
});
