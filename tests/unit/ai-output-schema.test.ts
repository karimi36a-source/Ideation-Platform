import {expect,it} from 'vitest';
import {aiOutputSchema,aiOutputTypeSchema,aiOutputDispositionSchema,aiOutputVerificationStatusSchema} from '@/features/ai/schema';
const id='00000000-0000-4000-8000-000000006004';
const row={id,project_id:id,workspace_id:id,activity_instance_id:null,requested_by:id,ai_role:'CRITICAL_REVIEWER',task_type:'SCHEMA_FIXTURE',prompt_text:'Prompt',response_text:'Response',output_type:'ANALYSIS',verification_status:'UNVERIFIED',disposition:'KEEP_FOR_REVIEW',created_at:'2026-11-02T12:00:00Z',model_provider_reference:null,metadata:{},disposition_revision:0};
it('parses only a canonical immutable AI Output row, never an Evidence or write contract',()=>{
 expect(aiOutputSchema.parse(row)).toEqual(row);
 for(const field of ['id','project_id','workspace_id','requested_by','output_type'])expect(aiOutputSchema.safeParse({...row,[field]:undefined}).success).toBe(false);
 expect(aiOutputSchema.safeParse({...row,providerApiKey:'not-accepted'}).success).toBe(false);
 expect(aiOutputSchema.safeParse({...row,metadata:[]}).success).toBe(false);
});
it('keeps controlled AI vocabularies separate from Evidence verification',()=>{
 expect(aiOutputTypeSchema.options).toHaveLength(8);
 expect(aiOutputDispositionSchema.options).toHaveLength(6);
 expect(aiOutputVerificationStatusSchema.options).toHaveLength(6);
 for(const v of ['VERIFIED','APPROVED','SOURCE_EVIDENCE'])expect(aiOutputVerificationStatusSchema.safeParse(v).success).toBe(false);
});

