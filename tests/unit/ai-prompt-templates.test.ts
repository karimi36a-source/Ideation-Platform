import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
import {aiPromptOutputSchema,aiPromptTemplateSchema,createAiPromptTemplateSchema,isAiPromptPairAllowed,aiPromptRoleSchema} from '@/features/ai/prompt-template-schema';
import {createAiPromptTemplate,setAiPromptTemplateActive,seedAiPromptTemplates} from '@/features/ai/prompt-templates';
const actor='00000000-0000-4000-8000-000000006001',id='00000000-0000-4000-8000-000000094303';
const outputSchema={type:'object',properties:{response:{type:'string'}},required:['response'],additionalProperties:false};
const input={roleCode:'STRUCTURED_CREATIVITY_ASSISTANT',activityType:'scamper',systemInstruction:'Safe FICI instructions',taskTemplate:'Safe task',outputSchema};
const row={id,role_code:input.roleCode,activity_type:input.activityType,version:2,system_instruction:input.systemInstruction,task_template:input.taskTemplate,output_schema:outputSchema,status:'inactive',created_by:actor,created_at:'2026-11-02T12:00:00Z'};
beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:actor});m.rpc.mockResolvedValue({data:row,error:null});});
it('uses only the narrow authenticated creation RPC and canonical result',async()=>{
 expect(await createAiPromptTemplate(input)).toEqual(row);expect(m.rpc).toHaveBeenCalledWith('create_ai_prompt_template',{input});
});
it('accepts canonical JSONB key ordering',async()=>{
 m.rpc.mockResolvedValue({data:{...row,output_schema:{additionalProperties:false,required:['response'],properties:{response:{type:'string'}},type:'object'}},error:null});
 expect((await createAiPromptTemplate(input)).id).toBe(id);
});
it.each(['createdBy','created_by','version','status','createdAt','providerApiKey','organizationId'])('rejects writable %s before RPC',async key=>{
 await expect(createAiPromptTemplate({...input,[key]:actor})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each([null,[],{}, {...input,roleCode:'UNKNOWN'}, {...input,activityType:'review'}, {...input,outputSchema:{type:'string'}}])('rejects malformed creation %#',async bad=>{
 await expect(createAiPromptTemplate(bad)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each([{created_by:id},{status:'active'},{version:0},{system_instruction:'Changed response'},{role_code:'CRITICAL_REVIEWER',activity_type:'review'},{output_schema:{type:'object',properties:{secret:{type:'string'}},additionalProperties:false}}])('withholds invalid/mismatched result %#',async bad=>{
 m.rpc.mockResolvedValue({data:{...row,...bad},error:null});await expect(createAiPromptTemplate(input)).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('withholds result after identity changes',async()=>{
 m.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:id});await expect(createAiPromptTemplate(input)).rejects.toMatchObject({code:'FORBIDDEN'});
});
it.each(['42501','23505'])('does not surface database details (%s)',async code=>{
 m.rpc.mockResolvedValue({data:null,error:{code,message:'private SQL/internal path'}});await expect(createAiPromptTemplate(input)).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('sanitizes unexpected transport errors',async()=>{
 m.rpc.mockRejectedValue(new Error('private transport token'));await expect(createAiPromptTemplate(input)).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('activates/deactivates exact version without client scope or creator fields',async()=>{
 m.rpc.mockResolvedValue({data:{...row,status:'active'},error:null});expect((await setAiPromptTemplateActive({templateId:id,active:true})).status).toBe('active');expect(m.rpc).toHaveBeenCalledWith('set_ai_prompt_template_active',{target_template:id,activate:true});
 await expect(setAiPromptTemplateActive({templateId:id,active:true,createdBy:actor})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 m.rpc.mockResolvedValue({data:row,error:null});expect((await setAiPromptTemplateActive({templateId:id,active:false})).status).toBe('inactive');
});
it('rejects activation response mismatch',async()=>{
 await expect(setAiPromptTemplateActive({templateId:id,active:true})).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('keeps seeds actor-attributed in the database and accepts only bounded counts',async()=>{
 m.rpc.mockResolvedValue({data:8,error:null});expect(await seedAiPromptTemplates()).toBe(8);expect(m.rpc).toHaveBeenCalledWith('seed_ai_prompt_templates');
 m.rpc.mockResolvedValue({data:0,error:null});expect(await seedAiPromptTemplates()).toBe(0);
 m.rpc.mockResolvedValue({data:9,error:null});await expect(seedAiPromptTemplates()).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('matches all eight approved role/activity pairs and rejects other pairs',()=>{
 const pairs=[['STRUCTURED_CREATIVITY_ASSISTANT','scamper'],['BRAINSTORMING_FACILITATOR','brainstorming'],['BRAINSTORMING_FACILITATOR','problem_storming'],['SYSTEM_STRUCTURE_ANALYST','affinity'],['SYSTEM_STRUCTURE_ANALYST','mind_map'],['PATENT_RESEARCH_ASSISTANT','patent_research'],['COMPARATIVE_CRITICAL_ANALYST','comparison'],['CRITICAL_REVIEWER','review']] as const;
 for(const [role,activity] of pairs)expect(isAiPromptPairAllowed(role,activity)).toBe(true);
 for(const role of aiPromptRoleSchema.options)expect(isAiPromptPairAllowed(role,'voting')).toBe(false);
 expect(aiPromptTemplateSchema.safeParse(row).success).toBe(true);expect(createAiPromptTemplateSchema.safeParse(input).success).toBe(true);
});
it.each([{},[],null,{type:'object',properties:{},additionalProperties:true},{type:'object',properties:{},additionalProperties:false,$ref:'https://example.test/remote'},{type:'object',properties:{},additionalProperties:false,$schema:null},{...outputSchema,required:['missing']},{...outputSchema,required:['response','response']},{...outputSchema,properties:{response:{type:'boolean',const:'true'}}},{...outputSchema,properties:{response:{type:'array'}}},{...outputSchema,properties:{response:{type:'integer',enum:[1.5]}}}])('rejects malformed/unsupported structured schema %#',bad=>{
 expect(aiPromptOutputSchema.safeParse(bad).success).toBe(false);
});
it('accepts bounded nested structured schemas and literal human-review requirement',()=>{
 expect(aiPromptOutputSchema.safeParse({type:'object',properties:{notes:{type:'array',items:{type:'string'}},review:{type:'boolean',const:true},count:{type:'integer',enum:[1,2]}},required:['notes','review'],additionalProperties:false}).success).toBe(true);
});
