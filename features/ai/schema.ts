import {z} from 'zod';
// Persisted row vocabulary only. Parsing never authorizes creation or verification.
export const aiOutputTypeSchema=z.enum(['ANALYSIS','SUGGESTION','HYPOTHESIS','DRAFT','COMPARISON','CLASSIFICATION','SUMMARY','CANDIDATE_SOLUTION']);
export const aiOutputVerificationStatusSchema=z.enum(['UNVERIFIED','UNDER_REVIEW','PARTIALLY_VERIFIED','VERIFIED_AGAINST_SOURCES','CONTRADICTED','REJECTED']);
export const aiOutputDispositionSchema=z.enum(['KEEP_FOR_REVIEW','ACCEPT_AS_CANDIDATE','MODIFIED','REJECTED','INVESTIGATE_FURTHER','CONVERTED_TO_PROJECT_OBJECT']);
const text=z.string().refine(value=>value.trim().length>0);
export const aiOutputSchema=z.strictObject({
 id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),activity_instance_id:z.uuid().nullable(),requested_by:z.uuid(),
 ai_role:text,task_type:text,prompt_text:text,response_text:text,output_type:aiOutputTypeSchema,
 verification_status:aiOutputVerificationStatusSchema,disposition:aiOutputDispositionSchema,
 disposition_revision:z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER).default(0),
 created_at:z.iso.datetime({offset:true}),model_provider_reference:text.nullable(),metadata:z.record(z.string(),z.json()),
});
export type AIOutput=z.infer<typeof aiOutputSchema>;

