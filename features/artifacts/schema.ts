import {z} from "zod";
export const artifactTypeSchema=z.enum(["DEVELOPED_CONCEPT","PROBLEM_BANK","SOLUTION_BANK","TEAM_DECISION_RECORD","INVENTION_STRUCTURE","GAP_LIST","MIND_MAP","MINIMUM_ESSENTIAL_STRUCTURE","INVENTION_CONCEPT","PATENT_LANDSCAPE","VALIDATION_PLAN","RISK_MAP","PRODUCT_ROADMAP","BUSINESS_FEASIBILITY_ASSESSMENT","TEAM_DEVELOPMENT_MAP","PITCH_DECK_RECORD","PATENT_READING_FRAMEWORK"]);
export const artifactStatusSchema=z.enum(["ACTIVE","ARCHIVED"]);
/** Stable identity only. Content and Version workflow remain separate. */
export const artifactSchema=z.strictObject({
 id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),artifact_type:artifactTypeSchema,
 title:z.string().refine(v=>v.trim().length>0),status:artifactStatusSchema,
 current_version_id:z.uuid().nullable(),created_by:z.uuid(),activity_instance_id:z.uuid().nullable(),
 review_required:z.boolean(),approval_required:z.boolean(),
 created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true}),archived_at:z.iso.datetime({offset:true}).nullable(),
}).refine(v=>v.status==="ACTIVE"?v.archived_at===null:v.archived_at!==null,{message:"Invalid Artifact archive state"});
export type Artifact=z.infer<typeof artifactSchema>;
