import {z} from 'zod';
// Technical Architecture vocabulary; no provider/model mapping or resolver.
export const aiUsageModelProfileSchema=z.enum(['AI_FAST','AI_STANDARD','AI_DEEP','AI_EXTRACTION']);
export const aiUsageResultSchema=z.enum(['SUCCESS','FAILURE']);
const count=z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);
// Persistence only. Parsing supplies no write authority or source capability.
export const aiUsageEventSchema=z.strictObject({
 id:z.uuid(),user_id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),activity_instance_id:z.uuid().nullable(),
 task_type:z.string().regex(/^[A-Z][A-Z0-9_]{0,63}$/),model_profile:aiUsageModelProfileSchema,
 input_usage:count.nullable(),output_usage:count.nullable(),estimated_cost:z.number().min(0).nullable(),
 latency_ms:count,success_failure:aiUsageResultSchema,created_at:z.iso.datetime({offset:true}),
});
export type AiUsageEvent=z.infer<typeof aiUsageEventSchema>;

