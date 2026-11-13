import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),read:vi.fn(),rpc:vi.fn()}));
vi.mock('@/lib/auth/authorization',()=>({getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({from:()=>({select:()=>({eq:()=>({maybeSingle:m.read})})}),rpc:m.rpc})}));
import {setAiOutputDisposition} from '@/features/ai/disposition';
const id='00000000-0000-4000-8000-000000006004';
const row={id,project_id:id,workspace_id:id,activity_instance_id:null,requested_by:id,ai_role:'CRITICAL_REVIEWER',task_type:'CRITICAL_REVIEW',prompt_text:'Prompt',response_text:'Original generated response',output_type:'ANALYSIS',verification_status:'UNVERIFIED',disposition:'KEEP_FOR_REVIEW',disposition_revision:2,created_at:'2026-11-02T12:00:00Z',model_provider_reference:null,metadata:{}};
beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:id});m.read.mockResolvedValue({data:row,error:null});m.rpc.mockResolvedValue({data:{...row,disposition:'ACCEPT_AS_CANDIDATE',disposition_revision:3},error:null});});
it.each(['KEEP_FOR_REVIEW','ACCEPT_AS_CANDIDATE','MODIFIED','REJECTED','INVESTIGATE_FURTHER'])('human %s command uses current RLS revision and safe returned classification',async disposition=>{
 m.rpc.mockResolvedValue({data:{...row,disposition,disposition_revision:3},error:null});
 const r=await setAiOutputDisposition({aiOutputId:id,disposition});
 expect(m.rpc).toHaveBeenCalledWith('set_ai_output_disposition',{target_output:id,target_disposition:disposition,expected_revision:2});
 expect(r).toMatchObject({ai_generated:true,disposition,verification_status:'UNVERIFIED',requested_by:id});
 for(const key of ['prompt_text','response_text','metadata','model_provider_reference'])expect(r).not.toHaveProperty(key);
});
it.each(['CONVERTED_TO_PROJECT_OBJECT','APPROVED','VERIFIED','unknown'])('denies privileged/invalid disposition %s',async disposition=>{
 await expect(setAiOutputDisposition({aiOutputId:id,disposition})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['actorId','projectId','workspaceId','verification_status','response_text','expectedRevision','force','approved'])('rejects client override %s',async key=>{
 await expect(setAiOutputDisposition({aiOutputId:id,disposition:'REJECTED',[key]:'spoof'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['Team B','other Personal','removed member','role-only','unknown ID'])('%s current RLS denial prevents command',async()=>{
 m.read.mockResolvedValue({data:null,error:null});await expect(setAiOutputDisposition({aiOutputId:id,disposition:'REJECTED'})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.rpc).not.toHaveBeenCalled();
});
it('fails closed for unauthenticated access',async()=>{m.auth.mockRejectedValue(Error('private auth data'));await expect(setAiOutputDisposition({aiOutputId:id,disposition:'REJECTED'})).rejects.toMatchObject({code:'FORBIDDEN',message:'AI output unavailable.'});expect(m.rpc).not.toHaveBeenCalled();});
it('surfaces a safe conflict without retrying over another human update',async()=>{m.rpc.mockResolvedValue({data:null,error:{code:'40001',message:'private schema diagnostics'}});await expect(setAiOutputDisposition({aiOutputId:id,disposition:'REJECTED'})).rejects.toMatchObject({code:'CONFLICT',message:'AI output unavailable.'});expect(m.rpc).toHaveBeenCalledOnce();});
it('authorization loss before commit is denied by RPC',async()=>{m.rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(setAiOutputDisposition({aiOutputId:id,disposition:'REJECTED'})).rejects.toMatchObject({code:'FORBIDDEN'});});
it('changed authenticated identity cannot receive result',async()=>{m.auth.mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:'different'});await expect(setAiOutputDisposition({aiOutputId:id,disposition:'REJECTED'})).rejects.toMatchObject({code:'FORBIDDEN'});});
