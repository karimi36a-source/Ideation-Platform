import {beforeEach,describe,expect,it,vi} from 'vitest';
import {createPatentRecordSchema} from '@/features/patents/create-schema';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
import {createPatentRecord} from '@/features/patents/create';
import {AuthorizationError} from '@/lib/auth/authorization';
const id='00000000-0000-4000-8000-000000006004';
const input={projectId:id,workspaceId:id,publicationNumber:' WO 2025/012345 A1 ',title:' Original title ',sourceDatabase:'PATENTSCOPE',sourceUrl:'https://research.example.test/source'};
const row={id,project_id:id,workspace_id:id,publication_number:input.publicationNumber,application_number:null,title:input.title,applicant:null,inventor:null,priority_date:null,filing_date:null,publication_date:null,ipc_cpc:null,source_database:'PATENTSCOPE',source_url:input.sourceUrl,abstract_text:null,relevance_status:'NOT_REVIEWED',why_retained:null,created_by:id,created_at:'2026-10-26T00:00:00Z'};
describe('strict createPatentRecord contract',()=>{
 it('accepts minimal input without modifying source formatting',()=>expect(createPatentRecordSchema.parse(input)).toEqual(input));
 it.each(['PATENTSCOPE','USPTO','GOOGLE_PATENTS'])('accepts %s',sourceDatabase=>expect(createPatentRecordSchema.safeParse({...input,sourceDatabase}).success).toBe(true));
 it.each(['NOT_REVIEWED','RELEVANT','POSSIBLY_RELEVANT','NOT_RELEVANT'])('accepts explicit human relevance %s',relevanceStatus=>expect(createPatentRecordSchema.safeParse({...input,relevanceStatus}).success).toBe(true));
 it.each(['createdBy','created_by','actorId','id','createdAt','force','novelty_score','patentability_status','metadata','scope','role'])('rejects spoof/additional %s',key=>expect(createPatentRecordSchema.safeParse({...input,[key]:id}).success).toBe(false));
 it.each([{relevanceStatus:null},{relevanceStatus:'NOVEL'},{sourceDatabase:'uspto'},{sourceDatabase:1},{sourceUrl:'http://example.test'},{sourceUrl:'https://'},{priorityDate:'2025-02-29'},{filingDate:'2025-04-31'},{publicationDate:'01/02/2025'},{applicant:3},{publicationNumber:''},{title:' '}])('rejects invalid input',change=>expect(createPatentRecordSchema.safeParse({...input,...change}).success).toBe(false));
 it('accepts nullable optional metadata and real ISO dates',()=>expect(createPatentRecordSchema.safeParse({...input,applicationNumber:null,applicant:null,inventor:null,priorityDate:'2024-02-29',filingDate:null,publicationDate:null,ipcCpc:null,abstractText:null,whyRetained:null}).success).toBe(true));
});
describe('server creation transport',()=>{
 beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:id});m.rpc.mockResolvedValue({data:row,error:null});});
 it('uses only narrow RPC and verifies canonical persisted metadata',async()=>{expect(await createPatentRecord(input)).toEqual(row);expect(m.rpc).toHaveBeenCalledExactlyOnceWith('create_patent_record',{input});});
 it('anonymous denied before RPC',async()=>{m.auth.mockRejectedValue(new AuthorizationError('AUTH_REQUIRED'));await expect(createPatentRecord(input)).rejects.toMatchObject({code:'AUTH_REQUIRED'});expect(m.rpc).not.toHaveBeenCalled();});
 it('spoof rejected before RPC',async()=>{await expect(createPatentRecord({...input,createdBy:id})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();});
 it('does not expose private database errors',async()=>{m.rpc.mockResolvedValue({error:{code:'42501',message:'private scope detail'}});await expect(createPatentRecord(input)).rejects.toMatchObject({code:'NOT_FOUND',message:expect.not.stringContaining('private scope detail')});});
 it('wrong creator response denied',async()=>{m.rpc.mockResolvedValue({data:{...row,created_by:'00000000-0000-4000-8000-000000006005'},error:null});await expect(createPatentRecord(input)).rejects.toMatchObject({code:'NOT_FOUND'});});
 it('modified source response denied',async()=>{m.rpc.mockResolvedValue({data:{...row,publication_number:row.publication_number.trim()},error:null});await expect(createPatentRecord(input)).rejects.toMatchObject({code:'NOT_FOUND'});});
 it('identity switch during RPC denied',async()=>{m.auth.mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:id}).mockResolvedValue({userId:'foreign'});await expect(createPatentRecord(input)).rejects.toMatchObject({code:'NOT_FOUND'});});
});
