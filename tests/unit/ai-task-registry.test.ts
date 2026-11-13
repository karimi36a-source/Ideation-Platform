import {expect,it,vi} from 'vitest';
import {readFileSync} from 'node:fs';
vi.mock('server-only',()=>({}));
import {getAiTaskDefinition,resolveAiTaskRequest} from '@/features/ai/task-registry';
import {aiContextRoleSchema} from '@/features/ai/context-schema';
import {aiOutputTypeSchema} from '@/features/ai/schema';
import {aiPromptRoleSchema,aiPromptOutputSchema,isAiPromptPairAllowed} from '@/features/ai/prompt-template-schema';
import {aiUsageModelProfileSchema,aiUsageEventSchema} from '@/features/ai/usage-schema';
import {aiGenerateInputSchema} from '@/features/ai/provider';
const expected=[
 ['SCAMPER_ASSISTANCE','STRUCTURED_CREATIVITY_ASSISTANT','scamper','AI_STANDARD','SUGGESTION'],
 ['BRAINSTORMING_ASSISTANCE','BRAINSTORMING_FACILITATOR','brainstorming','AI_STANDARD','SUGGESTION'],
 ['SYSTEM_STRUCTURE_ANALYSIS','SYSTEM_STRUCTURE_ANALYST','mind_map','AI_DEEP','ANALYSIS'],
 ['GAP_ANALYSIS','COMPARATIVE_CRITICAL_ANALYST','comparison','AI_DEEP','ANALYSIS'],
 ['PATENT_RESEARCH_ASSISTANCE','PATENT_RESEARCH_ASSISTANT','patent_research','AI_DEEP','ANALYSIS'],
 ['COMPARATIVE_ANALYSIS','COMPARATIVE_CRITICAL_ANALYST','comparison','AI_DEEP','COMPARISON'],
 ['CRITICAL_REVIEW','CRITICAL_REVIEWER','review','AI_DEEP','ANALYSIS'],
 ['SESSION10_GAP_REFINEMENT','COMPARATIVE_CRITICAL_ANALYST','comparison','AI_DEEP','ANALYSIS'],
];
it.each(expected)('%s resolves deterministically with an approved role/template/profile/output', (taskType,role,activity,profile,output)=>{
 const definition=getAiTaskDefinition(taskType);expect(getAiTaskDefinition(taskType)).toBe(definition);
 expect(definition).toMatchObject({taskType,allowedRole:role,templateActivityType:activity,defaultModelProfile:profile,allowedModelProfiles:[profile],outputType:output});
 expect(aiPromptRoleSchema.safeParse(definition.allowedRole).success).toBe(true);expect(isAiPromptPairAllowed(definition.allowedRole,definition.templateActivityType)).toBe(true);
 expect(aiOutputTypeSchema.safeParse(definition.outputType).success).toBe(true);expect(aiUsageModelProfileSchema.safeParse(profile).success).toBe(true);
 expect(resolveAiTaskRequest({taskType})).toEqual({definition,modelProfile:profile});
});
it.each(expected)('%s has explicit canonical context partitions and all global exclusions', taskType=>{
 const {context}=getAiTaskDefinition(taskType);expect(context.required.length).toBeGreaterThan(0);
 const roles=[...context.required,...context.optional,...context.forbidden];expect([...roles].sort()).toEqual([...aiContextRoleSchema.options].sort());expect(new Set(roles).size).toBe(roles.length);
 expect(context.exclusions).toEqual({unrelatedTeamOrWorkspace:true,revokedShare:true,formerTeam:true,unrevealedPeerBrainstorm:true,unrelatedChat:true,unrelatedFiles:true,siblingPrivateEntities:true,organizationWideData:true});
});
it.each(expected)('%s has a closed validated schema compatible with template and provider contracts', taskType=>{
 const task=getAiTaskDefinition(taskType);expect(aiPromptOutputSchema.safeParse(task.outputSchema).success).toBe(true);
 expect(task.outputSchema.type).toBe('object');expect(task.outputSchema.additionalProperties).toBe(false);
 expect(aiGenerateInputSchema.safeParse({modelProfile:task.defaultModelProfile,instructions:'FICI methodology fixture',input:'Authorized selected input fixture',outputSchema:task.outputSchema}).success).toBe(true);
 expect(Object.keys(task)).not.toContain('systemInstruction');expect(Object.keys(task)).not.toContain('taskTemplate');
});
it.each(expected)('%s requires human/evidence evaluation and grants no autonomous project actions', taskType=>{
 const task=getAiTaskDefinition(taskType);expect(task.verification).toEqual({initialStatus:'UNVERIFIED',humanReviewRequired:true,evidenceRequiredForFactualClaims:true,automaticVerification:false,automaticLegalConclusions:false});
 expect(task.allowedProjectActions).toEqual([]);
});
it.each(expected)('%s is immutable including nested schemas, context, actions, verification and profiles', taskType=>{
 const task=getAiTaskDefinition(taskType);
 function frozen(value:unknown){if(value!==null&&typeof value==='object'){expect(Object.isFrozen(value)).toBe(true);Object.values(value).forEach(frozen);}}frozen(task);
 expect(()=>Reflect.set(task,'allowedRole','ADMIN')).not.toThrow();expect(task.allowedRole).not.toBe('ADMIN');
 expect(()=>{(task.context.required as unknown as string[]).push('PATENT');}).toThrow();
 expect(Reflect.set(task.outputSchema,'additionalProperties',true)).toBe(false);
});
it.each(['','unknown','__proto__','constructor','FREE_PROMPT','CHAT','AUTONOMOUS_AGENT','APPROVE','VOTE','CHANGE_PERMISSIONS','PATENTABILITY',null,1,{},[]])('denies unknown or arbitrary unrestricted task %j',taskType=>{
 expect(()=>getAiTaskDefinition(taskType)).toThrow(expect.objectContaining({code:'UNKNOWN_TASK',message:'AI task unavailable'}));
});
it.each(['role','allowedRole','context','requiredContext','forbiddenContext','outputType','outputSchema','verification','allowedProjectActions','modelProfile','defaultModelProfile','allowedModelProfiles','costClass','instructions','prompt','provider','apiKey','contract','workspaceId','isAdmin'])('rejects request authority/prompt override %s',key=>{
 expect(()=>resolveAiTaskRequest({taskType:'SCAMPER_ASSISTANCE',[key]:'override'})).toThrow(expect.objectContaining({code:'INVALID_TASK_REQUEST'}));
});
it.each([null,{},[],{taskType:'UNKNOWN'},'SCAMPER_ASSISTANCE'])('rejects malformed requests without raw payload leakage',request=>{
 expect(()=>resolveAiTaskRequest(request)).toThrow(expect.objectContaining({code:'INVALID_TASK_REQUEST',message:'AI task unavailable'}));
});
it.each(expected)('%s profile resolution remains compatible with M14.4 usage metrics',taskType=>{
 const {definition,modelProfile}=resolveAiTaskRequest({taskType});const id='00000000-0000-4000-8000-000000006004';
 expect(aiUsageEventSchema.safeParse({id,user_id:id,project_id:id,workspace_id:id,activity_instance_id:null,task_type:definition.taskType,model_profile:modelProfile,input_usage:null,output_usage:null,estimated_cost:null,latency_ms:0,success_failure:'FAILURE',created_at:'2026-11-03T12:00:00Z'}).success).toBe(true);
});
it('patent/comparative/refinement outputs grant no legal, verification, voting or mutation authority',()=>{
 for(const name of ['PATENT_RESEARCH_ASSISTANCE','COMPARATIVE_ANALYSIS','SESSION10_GAP_REFINEMENT']){const task=getAiTaskDefinition(name);expect(task.verification.automaticLegalConclusions).toBe(false);expect(task.verification.automaticVerification).toBe(false);expect(task.allowedProjectActions).toEqual([]);}
});
it('keeps authoritative registry server-only without context retrieval, provider execution or credentials',()=>{
 const source=readFileSync('features/ai/task-registry.ts','utf8');expect(source).toMatch(/^import 'server-only';/);
 expect(source).not.toMatch(/from ['"].*(?:providers\/|authorization|db\/)|fetch\(|process\.env|gpt-[0-9]|\.generate\(/);
 expect(source).toContain('createAiModelProfileResolver(');
});
it('M14.19 Brainstorm context is optional exclusively for Brainstorm assistance',()=>{
 for(const [task] of expected){const c=getAiTaskDefinition(task).context;expect(c.optional.includes('BRAINSTORM')).toBe(task==='BRAINSTORMING_ASSISTANCE');expect(c.forbidden.includes('BRAINSTORM')).toBe(task!=='BRAINSTORMING_ASSISTANCE');}
});
