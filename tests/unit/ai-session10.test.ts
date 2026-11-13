import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn(),baseline:vi.fn(),artifact:vi.fn(),run:vi.fn()}));
vi.mock('@/lib/auth/authorization',()=>({getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc,from:()=>({select:()=>({eq:()=>({maybeSingle:m.artifact})})})})}));
vi.mock('@/features/projects/baseline',()=>({getProjectBaseline:m.baseline}));
vi.mock('@/features/ai/run-task',()=>({runAiTask:m.run}));
import {confirmSession10Reconstruction,runSession10Reconstruction} from '@/features/ai/session10';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const checkpoint={id:id(1),activity_instance_id:id(2),project_id:id(3),workspace_id:id(4),reconstruction_ai_output_id:id(5),baseline_item_id:id(6),confirmed_by:id(7),confirmed_at:'2026-11-05T12:00:00Z'};
const confirmation={activityInstanceId:id(2),reconstructionAiOutputId:id(5),confirmed:true};
const input={projectId:id(3),workspaceId:id(4),activityInstanceId:id(2),baselineItemId:id(6),idempotencyKey:'session10-reconstruct'};
const baseline={id:id(6),artifact_id:id(8),artifact_version_id:id(9),baseline_type:'CURRENT_INVENTION_CONCEPT'};
const runtime={provider:{generate:vi.fn()}};
beforeEach(()=>{
 vi.resetAllMocks();m.auth.mockResolvedValue({userId:id(7)});m.rpc.mockImplementation(async name=>({data:name==='validate_session10_reconstruction_scope'?true:checkpoint,error:null}));m.baseline.mockResolvedValue([baseline]);m.artifact.mockResolvedValue({data:{id:id(8),artifact_type:'INVENTION_CONCEPT',project_id:id(3),workspace_id:id(4),current_version_id:id(9)},error:null});m.run.mockResolvedValue({id:id(5),ai_generated:true,verification_status:'UNVERIFIED'});
});
it('reconstruction selects exact effective baseline and uses ordinary comparative AI without requiring GAP',async()=>{
 const result=await runSession10Reconstruction(input,runtime);expect(result).toMatchObject({ai_generated:true,verification_status:'UNVERIFIED'});
 expect(m.run).toHaveBeenCalledWith(expect.objectContaining({taskType:'COMPARATIVE_ANALYSIS',selectedContextRefs:[{entityType:'ARTIFACT_VERSION',entityId:id(9),contextRole:'CURRENT_ARTIFACT'}]}),runtime);
 expect(m.rpc).toHaveBeenCalledWith('validate_session10_reconstruction_scope',{target_activity:id(2),target_project:id(3),target_workspace:id(4)});expect(runtime.provider.generate).not.toHaveBeenCalled();
});
it('keeps explicit research sources and requests uncertainty instead of inventing missing facts',async()=>{
 const ref={entityType:'EVIDENCE',entityId:id(10),contextRole:'EVIDENCE'};
 await runSession10Reconstruction({...input,selectedContextRefs:[ref]},runtime);
 expect(m.run.mock.calls[0][0].selectedContextRefs).toContainEqual(ref);expect(m.run.mock.calls[0][0].userInstruction).toMatch(/missing information and uncertainty.*do not invent facts/);
});
it('missing baseline is explicit and never falls back to latest Draft',async()=>{
 m.baseline.mockResolvedValue([]);await expect(runSession10Reconstruction(input,runtime)).rejects.toMatchObject({code:'CURRENT_BASELINE_REQUIRED'});expect(m.run).not.toHaveBeenCalled();
});
it('preserves canonical provider failure for safe retry',async()=>{
 m.run.mockRejectedValue({code:'PROVIDER_FAILED',message:'AI task unavailable.'});await expect(runSession10Reconstruction(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED'});
});
it('denies non-Session-10 or unauthorized Activity before reading baseline or calling AI',async()=>{
 m.rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(runSession10Reconstruction(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.baseline).not.toHaveBeenCalled();expect(m.run).not.toHaveBeenCalled();
});
it.each([{current_version_id:id(20)},{project_id:id(20)},{workspace_id:id(20)}])('rejects changed/mismatched baseline scope %#',async change=>{
 m.artifact.mockResolvedValue({data:{id:id(8),artifact_type:'INVENTION_CONCEPT',project_id:id(3),workspace_id:id(4),current_version_id:id(9),...change},error:null});await expect(runSession10Reconstruction(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.run).not.toHaveBeenCalled();
});
it.each(['GAP'])('reconstruction cannot silently select %s',async contextRole=>{
 await expect(runSession10Reconstruction({...input,selectedContextRefs:[{entityType:contextRole==='GAP'?'DEVELOPMENT_OBJECT':'ARTIFACT_VERSION',entityId:id(20),contextRole}]},runtime)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.run).not.toHaveBeenCalled();
});
it('explicit additional Artifact Versions supplement rather than replace current baseline',async()=>{
 const ref={entityType:'ARTIFACT_VERSION',entityId:id(20),contextRole:'CURRENT_ARTIFACT'};await runSession10Reconstruction({...input,selectedContextRefs:[ref]},runtime);
 expect(m.run.mock.calls[0][0].selectedContextRefs).toEqual([{entityType:'ARTIFACT_VERSION',entityId:id(9),contextRole:'CURRENT_ARTIFACT'},ref]);
});
it('explicit checkpoint returns canonical durable actor/time without AI disposition/verification commands',async()=>{
 expect(await confirmSession10Reconstruction(confirmation)).toEqual(checkpoint);expect(m.rpc).toHaveBeenCalledOnce();expect(m.rpc).toHaveBeenCalledWith('confirm_session10_reconstruction',{input:confirmation});
 expect(m.run).not.toHaveBeenCalled();
});
it.each([undefined,false,'true'])('rejects missing or inexact human confirmation %j',async confirmed=>{
 await expect(confirmSession10Reconstruction({...confirmation,confirmed})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['confirmedBy','confirmedAt','actorId','projectId','workspaceId','verification_status','disposition','force'])('rejects checkpoint spoofing %s',async key=>{
 await expect(confirmSession10Reconstruction({...confirmation,[key]:'spoof'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each([{confirmed_by:id(20)},{activity_instance_id:id(20)},{reconstruction_ai_output_id:id(20)}])('rejects mismatched checkpoint result %#',async change=>{
 m.rpc.mockResolvedValue({data:{...checkpoint,...change},error:null});await expect(confirmSession10Reconstruction(confirmation)).rejects.toMatchObject({code:'FORBIDDEN'});
});
it.each(['Team B','removed member','role-only actor','foreign output','unknown output'])('preserves database checkpoint denial for %s',async()=>{
 m.rpc.mockResolvedValue({data:null,error:{code:'42501',message:'private internal details'}});await expect(confirmSession10Reconstruction(confirmation)).rejects.toMatchObject({code:'FORBIDDEN',message:'Session 10 unavailable.'});
});
