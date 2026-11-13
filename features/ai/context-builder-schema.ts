import {z} from 'zod';
import {aiContextEntityTypeSchema,aiContextRoleSchema,aiContextReferenceSchema} from './context-schema';
const selection=z.strictObject({entityType:aiContextEntityTypeSchema,entityId:z.uuid(),contextRole:aiContextRoleSchema,shareId:z.uuid().optional()});
export const aiContextBuilderInputSchema=z.strictObject({projectId:z.uuid(),workspaceId:z.uuid(),activityInstanceId:z.uuid().optional(),taskType:z.string(),selectedContextRefs:z.array(selection).max(32).default([])});
export type AiContextBuilderInput=z.infer<typeof aiContextBuilderInputSchema>;
export const aiContextCandidateSchema=z.strictObject({entity_type:aiContextEntityTypeSchema,entity_id:z.uuid(),context_role:aiContextRoleSchema,included_snapshot_hash:z.string().regex(/^[a-f0-9]{64}$/),share_snapshot_id:z.uuid().nullable(),permission_scope:z.union([z.strictObject({access:z.literal('SOURCE')}),z.strictObject({access:z.literal('SHARE_SNAPSHOT')})])})
 .refine(value=>aiContextReferenceSchema.safeParse({...value,id:'00000000-0000-4000-8000-000000000001',ai_output_id:'00000000-0000-4000-8000-000000000002'}).success);
export type AiContextCandidate=z.infer<typeof aiContextCandidateSchema>;
