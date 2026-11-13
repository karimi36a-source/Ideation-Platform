import {z} from "zod";

export const baselineTypeSchema=z.string().trim().regex(/^[A-Z][A-Z0-9_]*$/);
export const setProjectBaselineInputSchema=z.strictObject({projectId:z.uuid(),baselineType:baselineTypeSchema,artifactId:z.uuid(),artifactVersionId:z.uuid()});
export const projectBaselineItemSchema=z.strictObject({id:z.uuid(),project_id:z.uuid(),baseline_type:baselineTypeSchema,artifact_id:z.uuid(),artifact_version_id:z.uuid(),effective_from:z.iso.datetime({offset:true}),effective_to:z.iso.datetime({offset:true}).nullable(),set_by:z.uuid()}).refine(row=>row.effective_to===null||Date.parse(row.effective_to)>=Date.parse(row.effective_from));
export type ProjectBaselineItem=z.infer<typeof projectBaselineItemSchema>;
