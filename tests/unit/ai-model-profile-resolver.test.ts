import {expect,it,vi} from 'vitest';
import {readFileSync} from 'node:fs';
vi.mock('server-only',()=>({}));
import {createAiModelProfileResolver,AiModelProfileResolutionError,type AiTaskProfileContract} from '@/features/ai/model-profile-resolver';
import {aiUsageEventSchema,aiUsageModelProfileSchema} from '@/features/ai/usage-schema';
import {OpenAiResponsesProvider} from '@/features/ai/providers/openai-responses';
import type {AiProvider} from '@/features/ai/provider';
// Contract examples only. M14.7 owns the persisted/runtime task registry.
const contracts:AiTaskProfileContract[]=[
 {taskType:'CLASSIFICATION',defaultModelProfile:'AI_FAST',allowedModelProfiles:['AI_FAST']},
 {taskType:'BRAINSTORMING',defaultModelProfile:'AI_STANDARD',allowedModelProfiles:['AI_STANDARD']},
 {taskType:'PATENT_COMPARISON',defaultModelProfile:'AI_DEEP',allowedModelProfiles:['AI_DEEP']},
 {taskType:'EXTRACTION',defaultModelProfile:'AI_EXTRACTION',allowedModelProfiles:['AI_EXTRACTION']},
];
it.each(contracts)('resolves $taskType default using the canonical platform profile',contract=>{
 expect(createAiModelProfileResolver(contract)()).toEqual({taskType:contract.taskType,modelProfile:contract.defaultModelProfile});
});
it('rejects deep escalation for a fast-only task',()=>{
 expect(()=>createAiModelProfileResolver(contracts[0])({modelProfile:'AI_DEEP'})).toThrow(expect.objectContaining({code:'PROFILE_NOT_ALLOWED'}));
});
it.each(contracts)('rejects every unsupported $taskType/profile combination',contract=>{
 const resolve=createAiModelProfileResolver(contract);
 for(const modelProfile of aiUsageModelProfileSchema.options)if(!contract.allowedModelProfiles.includes(modelProfile))expect(()=>resolve({modelProfile})).toThrow(expect.objectContaining({code:'PROFILE_NOT_ALLOWED'}));
});
it('accepts an override only when the bound server contract explicitly permits it',()=>{
 const resolve=createAiModelProfileResolver({...contracts[1],allowedModelProfiles:['AI_STANDARD','AI_DEEP']});
 expect(resolve().modelProfile).toBe('AI_STANDARD');expect(resolve({modelProfile:'AI_DEEP'}).modelProfile).toBe('AI_DEEP');
});
it.each(['FAST','STANDARD','DEEP_ANALYSIS','EXTRACTION','provider-model','UNKNOWN',null,1,{}])('rejects noncanonical client profile %j',modelProfile=>{
 expect(()=>createAiModelProfileResolver(contracts[0])({modelProfile})).toThrow(expect.objectContaining({code:'INVALID_PROFILE_REQUEST'}));
});
it.each(['role','isAdmin','taskType','allowedModelProfiles','defaultModelProfile','contract','projectId','workspaceId','context','apiKey','model','providerConfig','providerConfigurationReference'])('rejects client authority/config override %s',key=>{
 expect(()=>createAiModelProfileResolver(contracts[0])({[key]:'spoof'})).toThrow(expect.objectContaining({code:'INVALID_PROFILE_REQUEST'}));
});
it.each([null,[],{},'CLASSIFICATION',{...contracts[0],allowedModelProfiles:[]},{...contracts[0],allowedModelProfiles:['AI_STANDARD']},{...contracts[0],allowedModelProfiles:['AI_FAST','AI_FAST']},{...contracts[0],taskType:''},{...contracts[0],taskType:'secret text'},{...contracts[0],model:'vendor'},{...contracts[0],defaultModelProfile:'UNKNOWN'}])('rejects malformed/unbound trusted contract',contract=>{
 expect(()=>createAiModelProfileResolver(contract as AiTaskProfileContract)).toThrow(expect.objectContaining({code:'INVALID_TASK_CONTRACT'}));
});
it('captures contract configuration and freezes result, without authorization/context data',()=>{
 const contract={...contracts[0],allowedModelProfiles:[...contracts[0].allowedModelProfiles]};const resolve=createAiModelProfileResolver(contract);
 contract.defaultModelProfile='AI_DEEP';contract.allowedModelProfiles.push('AI_DEEP');
 expect(resolve()).toEqual({taskType:'CLASSIFICATION',modelProfile:'AI_FAST'});expect(Object.isFrozen(resolve())).toBe(true);
 expect(()=>resolve({modelProfile:'AI_DEEP'})).toThrow(AiModelProfileResolutionError);
});
it.each(contracts)('resolved $taskType works with success and failure usage records',contract=>{
 const result=createAiModelProfileResolver(contract)();const id='00000000-0000-4000-8000-000000006004';
 for(const success_failure of ['SUCCESS','FAILURE'])expect(aiUsageEventSchema.parse({id,user_id:id,project_id:id,workspace_id:id,activity_instance_id:null,task_type:result.taskType,model_profile:result.modelProfile,input_usage:null,output_usage:null,estimated_cost:null,latency_ms:1,success_failure,created_at:'2026-11-03T12:00:00Z'}).model_profile).toBe(result.modelProfile);
});
it.each(contracts)('resolved $taskType selects trusted provider configuration without vendor types in business result',async contract=>{
 const resolution=createAiModelProfileResolver(contract)();const transport=vi.fn<typeof fetch>().mockResolvedValue(new Response(JSON.stringify({id:'resp_test',status:'completed',output:[{type:'message',role:'assistant',content:[{type:'output_text',text:'ok'}]}]})));
 // Model strings/config are confined to adapter construction, never task contracts.
 const provider:AiProvider=new OpenAiResponsesProvider({apiKey:'mock-private-config',models:{[resolution.modelProfile]:'test-mapped-model'}},transport);
 expect((await provider.generate({modelProfile:resolution.modelProfile,instructions:'FICI rules',input:'selected content'})).success).toBe(true);
 expect(JSON.parse(transport.mock.calls[0][1]!.body as string).model).toBe('test-mapped-model');
 expect(Object.keys(resolution)).toEqual(['taskType','modelProfile']);
});
it('fails closed when provider configuration for the resolved profile is missing',async()=>{
 const resolution=createAiModelProfileResolver(contracts[3])();const transport=vi.fn<typeof fetch>();const provider=new OpenAiResponsesProvider({apiKey:'mock-key',models:{AI_STANDARD:'test-model'}},transport);
 expect((await provider.generate({modelProfile:resolution.modelProfile,instructions:'FICI',input:'text'})).error?.code).toBe('CONFIGURATION');expect(transport).not.toHaveBeenCalled();
});
it('allows another provider to map the same platform profile independently',async()=>{
 const resolution=createAiModelProfileResolver(contracts[3])();const alternative:AiProvider={generate:async request=>({success:true,text:request.modelProfile,structured:null,usage:{inputUsage:null,outputUsage:null},latencyMs:0,reference:{provider:'replacement',responseId:'alternative-reference'},error:null})};
 expect((await alternative.generate({modelProfile:resolution.modelProfile,instructions:'FICI',input:'text'})).text).toBe('AI_EXTRACTION');
});
it('keeps resolver server-only and independent from provider credentials, SDKs and authority',()=>{
 const source=readFileSync('features/ai/model-profile-resolver.ts','utf8');expect(source).toMatch(/^import 'server-only';/);
 expect(source).not.toMatch(/from ['"].*(?:providers\/|openai|authorization|db\/)|process\.env|fetch\(|gpt-[0-9]/);
});
