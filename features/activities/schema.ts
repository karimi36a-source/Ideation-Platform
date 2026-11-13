import {z} from "zod";
export const activityMethodSchema=z.enum(["teaching", "reflection", "scamper", "brainstorming", "problem_storming", "voting", "affinity", "mind_map", "patent_research", "comparison", "validation", "roadmap", "kanban", "decision", "review", "custom"]);
export const activityStatusSchema=z.enum(["active","inactive","archived"]);
const optionalText=z.string().nullable().default(null);
export const activityInputSchema=z.strictObject({name:z.string().trim().min(1),description:optionalText,method_type:activityMethodSchema,workspace_mode:optionalText,sequence:z.number().int().positive(),instructions:optionalText,ai_role_code:optionalText,requires_review:z.boolean().default(false),requires_approval:z.boolean().default(false),completion_rule:optionalText,configuration:z.record(z.string(),z.json()).default({}),status:activityStatusSchema.default("active")});
export const activitySchema=activityInputSchema.extend({id:z.uuid(),session_definition_id:z.uuid(),created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true})});
export type ActivityDefinition=z.infer<typeof activitySchema>;
