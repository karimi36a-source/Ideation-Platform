import {expect,it} from 'vitest';
import {aiUsageEventSchema,aiUsageModelProfileSchema,aiUsageResultSchema} from '@/features/ai/usage-schema';
const id='00000000-0000-4000-8000-000000006004';
const row={id,user_id:id,project_id:id,workspace_id:id,activity_instance_id:null,task_type:'USAGE_FIXTURE',model_profile:'AI_STANDARD',input_usage:200,output_usage:40,estimated_cost:0.00125,latency_ms:120,success_failure:'SUCCESS',created_at:'2026-11-03T12:00:00Z'};
it('parses minimized metrics with no AI Output, context or provider payload',()=>{
 expect(aiUsageEventSchema.parse(row)).toEqual(row);
 expect(aiUsageEventSchema.parse({...row,success_failure:'FAILURE',input_usage:null,output_usage:null,estimated_cost:null})).toMatchObject({success_failure:'FAILURE',estimated_cost:null});
});
it.each(['prompt_text','response_text','context','metadata','storage_reference','signed_url','api_key','provider_request','error_message','stack_trace','ai_output_id'])('rejects confidential/additional %s fields',key=>{
 expect(aiUsageEventSchema.safeParse({...row,[key]:'forbidden'}).success).toBe(false);
});
it.each(['input_usage','output_usage','latency_ms'])('requires valid nonnegative safe integral %s',key=>{
 for(const v of [-1,1.5,Number.MAX_SAFE_INTEGER+1,'raw provider body',{},Infinity])expect(aiUsageEventSchema.safeParse({...row,[key]:v}).success).toBe(false);
 expect(aiUsageEventSchema.safeParse({...row,[key]:0}).success).toBe(true);
});
it('allows only finite nullable nonnegative cost without pricing inference',()=>{
 for(const v of [-1,NaN,Infinity,'not a cost'])expect(aiUsageEventSchema.safeParse({...row,estimated_cost:v}).success).toBe(false);
 expect(aiUsageEventSchema.safeParse({...row,estimated_cost:null}).success).toBe(true);
 expect(aiUsageEventSchema.parse({...row,estimated_cost:0.000000000125}).estimated_cost).toBe(0.000000000125);
});
it('uses Technical Architecture profile names and two controlled outcomes',()=>{
 expect(aiUsageModelProfileSchema.options).toEqual(['AI_FAST','AI_STANDARD','AI_DEEP','AI_EXTRACTION']);
 expect(aiUsageResultSchema.options).toEqual(['SUCCESS','FAILURE']);
 for(const v of ['GPT-5.6 Terra','STANDARD','DEEP_ANALYSIS','EXTRACTION'])expect(aiUsageEventSchema.safeParse({...row,model_profile:v}).success).toBe(false);
});
it('accepts operational task codes, not payloads or URLs',()=>{
 for(const task_type of ['','secret provider body','https://example.test/private','X'.repeat(65)])expect(aiUsageEventSchema.safeParse({...row,task_type}).success).toBe(false);
});

