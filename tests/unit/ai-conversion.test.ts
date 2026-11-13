import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),source:vi.fn(),object:vi.fn(),rpc:vi.fn()}));
vi.mock('@/lib/auth/authorization',()=>({getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({from:(table:string)=>({select:()=>({eq:()=>({maybeSingle:table==='ai_outputs'?m.source:m.object})})})})}));
vi.mock('@/features/ai/task-persistence',()=>({createAiTaskPersistenceClient:()=>({rpc:m.rpc})}));
import {convertAiOutputToCandidate,aiConversionTargets} from '@/features/ai/conversion';
import {getAiTaskDefinition} from '@/features/ai/task-registry';
import {patentTestResponse} from '../support/ai-patent-output';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const actor=id(4),structured={technique:'Combine',original_element:'Source',proposed_change:'Change',reasoning:'Reason',potential_benefit:'Benefit',risk_or_unknown:'Human review'};
const source={id:id(1),project_id:id(2),workspace_id:id(3),activity_instance_id:id(8),requested_by:id(5),ai_role:'STRUCTURED_CREATIVITY_ASSISTANT',task_type:'SCAMPER_ASSISTANCE',prompt_text:'Task',response_text:JSON.stringify(structured),output_type:'SUGGESTION',verification_status:'UNVERIFIED',disposition:'ACCEPT_AS_CANDIDATE',disposition_revision:1,created_at:'2026-11-04T12:00:00Z',model_provider_reference:null,metadata:{}};
const object={id:id(9),project_id:id(2),workspace_id:id(3),object_type:'IDEA',title:'Human title',content:source.response_text,status:null,verification_status:null,origin_type:'AI',origin_reference_id:id(1),created_by:actor,current_version_number:1,archived_at:null,metadata:{},created_at:'2026-11-04T12:01:00Z',updated_at:'2026-11-04T12:01:00Z'};
const input={aiOutputId:id(1),targetObjectType:'IDEA',candidateTitle:'Human title',confirmed:true};
beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:actor});m.source.mockResolvedValue({data:source,error:null});m.object.mockResolvedValue({data:object,error:null});m.rpc.mockResolvedValue({data:object,error:null});});
it('AT-AI-008: source response is preserved, human title/actor supplied, canonical candidate returned',async()=>{
 expect(await convertAiOutputToCandidate(input)).toMatchObject({id:id(9),origin_type:'AI',origin_reference_id:id(1),created_by:actor,status:null});
 expect(m.rpc).toHaveBeenCalledWith('convert_ai_output_to_candidate',{input:{actorId:actor,aiOutputId:id(1),targetObjectType:'IDEA',candidateTitle:'Human title',candidateContent:source.response_text,confirmed:true,sourceResponseHash:expect.stringMatching(/^[a-f0-9]{64}$/)}});
});
it('allows explicit human-confirmed content without rewriting source',async()=>{await convertAiOutputToCandidate({...input,candidateContent:'Human edited draft'});expect(m.rpc.mock.calls[0][1].input.candidateContent).toBe('Human edited draft');expect(source.response_text).toBe(JSON.stringify(structured));});
it.each([undefined,false,'true',1])('requires exact explicit confirmation %j',async confirmed=>{await expect(convertAiOutputToCandidate({...input,confirmed})).rejects.toMatchObject({code:'HUMAN_CONFIRMATION_REQUIRED'});expect(m.rpc).not.toHaveBeenCalled();});
it.each(['', '   ',undefined])('requires title %j',async candidateTitle=>{await expect(convertAiOutputToCandidate({...input,candidateTitle})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();});
it.each(['actorId','projectId','workspaceId','originType','created_by','verification_status','status','force','sourceResponseHash','createVerifiedEvidence','promoteToEvidence','verifiedBy'])('rejects spoofed %s',async key=>{await expect(convertAiOutputToCandidate({...input,[key]:'spoof'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();});
it.each(['KEEP_FOR_REVIEW','REJECTED','INVESTIGATE_FURTHER','MODIFIED'])('does not treat %s as conversion approval',async disposition=>{m.source.mockResolvedValue({data:{...source,disposition},error:null});await expect(convertAiOutputToCandidate(input)).rejects.toMatchObject({code:'NOT_ELIGIBLE'});expect(m.rpc).not.toHaveBeenCalled();});
it.each(['not JSON','{}',JSON.stringify({...structured,extra:'bad'})])('rejects malformed/non-valid saved response',async response_text=>{m.source.mockResolvedValue({data:{...source,response_text},error:null});await expect(convertAiOutputToCandidate(input)).rejects.toMatchObject({code:'INVALID_AI_OUTPUT'});expect(m.rpc).not.toHaveBeenCalled();});
it('rejects false task classification',async()=>{m.source.mockResolvedValue({data:{...source,output_type:'ANALYSIS'},error:null});await expect(convertAiOutputToCandidate(input)).rejects.toMatchObject({code:'INVALID_AI_OUTPUT'});});
it('denies unknown and incompatible target types',async()=>{await expect(convertAiOutputToCandidate({...input,targetObjectType:'DECISION'})).rejects.toMatchObject({code:'TARGET_TYPE_NOT_ALLOWED'});await expect(convertAiOutputToCandidate({...input,targetObjectType:'GAP'})).rejects.toMatchObject({code:'TARGET_TYPE_NOT_ALLOWED'});expect(m.rpc).not.toHaveBeenCalled();});
it.each(['Team B','other Personal','removed member','role-only','known ID','revoked Share'])('%s gets no conversion without source RLS access',async()=>{m.source.mockResolvedValue({data:null,error:null});await expect(convertAiOutputToCandidate(input)).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.rpc).not.toHaveBeenCalled();});
it('current source access does not override independent create authority',async()=>{m.rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(convertAiOutputToCandidate(input)).rejects.toMatchObject({code:'FORBIDDEN'});});
it('same converted source can reuse result, conflicting target is CONFLICT',async()=>{m.source.mockResolvedValue({data:{...source,disposition:'CONVERTED_TO_PROJECT_OBJECT'},error:null});expect((await convertAiOutputToCandidate(input)).id).toBe(object.id);await expect(convertAiOutputToCandidate({...input,targetObjectType:'GAP'})).rejects.toMatchObject({code:'CONFLICT'});});
it('normalizes persistence conflict without exposing diagnostics',async()=>{m.rpc.mockResolvedValue({data:null,error:{code:'23505',message:'private internal data'}});await expect(convertAiOutputToCandidate(input)).rejects.toMatchObject({code:'CONFLICT',message:'AI conversion unavailable.'});});
it('current candidate read remains mandatory after conversion',async()=>{m.object.mockResolvedValue({data:null,error:null});await expect(convertAiOutputToCandidate(input)).rejects.toMatchObject({code:'FORBIDDEN'});});
it('fails closed on changed authenticated actor',async()=>{m.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:id(6)});await expect(convertAiOutputToCandidate(input)).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.rpc).not.toHaveBeenCalled();});
it.each(Object.entries(aiConversionTargets))('uses the exact Task schema for allowed %s candidates',async(taskType,targets)=>{
 const task=getAiTaskDefinition(taskType);const fields=(task as unknown as {outputSchema:{required:string[]}}).outputSchema.required;
 m.source.mockResolvedValue({data:{...source,task_type:taskType,ai_role:task.allowedRole,output_type:task.outputType,response_text:JSON.stringify(taskType==='PATENT_RESEARCH_ASSISTANCE'?patentTestResponse('[]'):Object.fromEntries(fields.map(k=>[k,'Source text'])))},error:null});
 for(const targetObjectType of targets){const row={...object,object_type:targetObjectType};m.object.mockResolvedValue({data:row,error:null});m.rpc.mockResolvedValue({data:row,error:null});await expect(convertAiOutputToCandidate({...input,targetObjectType})).resolves.toMatchObject({object_type:targetObjectType});}
});

const approvedTargets={SCAMPER_ASSISTANCE:['IDEA'],BRAINSTORMING_ASSISTANCE:['IDEA'],SYSTEM_STRUCTURE_ANALYSIS:['SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION'],GAP_ANALYSIS:['GAP','OPEN_QUESTION','REQUIREMENT','RISK'],PATENT_RESEARCH_ASSISTANCE:['GAP','OPEN_QUESTION','RISK'],COMPARATIVE_ANALYSIS:['GAP','REQUIREMENT','RISK','OPEN_QUESTION'],CRITICAL_REVIEW:['GAP','RISK','OPEN_QUESTION','REQUIREMENT'],SESSION10_GAP_REFINEMENT:['GAP','SOLUTION','REQUIREMENT','OPEN_QUESTION']};
it('keeps the approved conversion permission catalog exact',()=>expect(aiConversionTargets).toEqual(approvedTargets));
it.each(Object.entries(approvedTargets))('%s denies every canonical type outside its approved set',async(taskType,targets)=>{
 const task=getAiTaskDefinition(taskType),fields=(task as unknown as {outputSchema:{required:string[]}}).outputSchema.required;
 m.source.mockResolvedValue({data:{...source,task_type:taskType,ai_role:task.allowedRole,output_type:task.outputType,response_text:JSON.stringify(taskType==='PATENT_RESEARCH_ASSISTANCE'?patentTestResponse('[]'):Object.fromEntries(fields.map(k=>[k,'Source'])))},error:null});
 for(const targetObjectType of ['PROBLEM','IDEA','SOLUTION','FEATURE','FUNCTION','COMPONENT','SYSTEM','SUBSYSTEM','GAP','OPEN_QUESTION','REQUIREMENT','RISK'].filter(k=>!targets.includes(k)))await expect(convertAiOutputToCandidate({...input,targetObjectType})).rejects.toMatchObject({code:'TARGET_TYPE_NOT_ALLOWED'});
 expect(m.rpc).not.toHaveBeenCalled();
});
