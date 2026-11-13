import {z} from "zod";
export const sessionStatusSchema=z.enum(["active","inactive","archived"]);
export const sessionInputSchema=z.strictObject({session_number:z.number().int().positive(),title:z.string().trim().min(1),description:z.string(),learning_goal:z.string().trim().min(1),sequence:z.number().int().positive(),status:sessionStatusSchema});
export const sessionSchema=sessionInputSchema.extend({id:z.uuid(),curriculum_version_id:z.uuid(),created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true})});
export type SessionDefinition=z.infer<typeof sessionSchema>;
