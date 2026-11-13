import {z} from 'zod';
// Persisted provenance only, never a source-access or write contract.
export const aiContextEntityTypeSchema=z.enum(['PROJECT','ARTIFACT_VERSION','DEVELOPMENT_OBJECT','DECISION','FEEDBACK_ITEM','EVIDENCE','PATENT_RECORD','ACTIVITY_INSTANCE','BRAINSTORM_ENTRY']);
export const aiContextRoleSchema=z.enum(['CURRENT_PROJECT','CURRENT_ARTIFACT','PRIOR_APPROVED_OUTPUT','TEAM_DECISION','INSTRUCTOR_FEEDBACK','EVIDENCE','PATENT','GAP','COURSE_CONTEXT','BRAINSTORM']);
const sources={CURRENT_PROJECT:'PROJECT',CURRENT_ARTIFACT:'ARTIFACT_VERSION',PRIOR_APPROVED_OUTPUT:'ARTIFACT_VERSION',TEAM_DECISION:'DECISION',INSTRUCTOR_FEEDBACK:'FEEDBACK_ITEM',EVIDENCE:'EVIDENCE',PATENT:'PATENT_RECORD',GAP:'DEVELOPMENT_OBJECT',COURSE_CONTEXT:'ACTIVITY_INSTANCE',BRAINSTORM:'BRAINSTORM_ENTRY'} as const;
export const aiContextReferenceSchema=z.strictObject({
 id:z.uuid(),ai_output_id:z.uuid(),entity_type:aiContextEntityTypeSchema,entity_id:z.uuid(),context_role:aiContextRoleSchema,
 included_snapshot_hash:z.string().regex(/^[0-9a-f]{64}$/),share_snapshot_id:z.uuid().nullable(),
 permission_scope:z.union([z.strictObject({access:z.literal('SOURCE')}),z.strictObject({access:z.literal('SHARE_SNAPSHOT')})]),
}).refine(row=>sources[row.context_role]===row.entity_type,'Incompatible canonical source')
 .refine(row=>row.entity_type!=='BRAINSTORM_ENTRY'||row.share_snapshot_id===null,'Brainstorm Sharing is unsupported')
 .refine(row=>(row.share_snapshot_id!==null)===(row.permission_scope.access==='SHARE_SNAPSHOT'),'Incompatible frozen provenance');
export type AIContextReference=z.infer<typeof aiContextReferenceSchema>;
