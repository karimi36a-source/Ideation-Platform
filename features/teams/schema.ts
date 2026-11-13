import {z} from "zod";
export const teamStatusSchema=z.enum(["created","active","completed","archived"]);
export const teamSchema=z.object({
 id:z.uuid(),cohort_id:z.uuid(),name:z.string().trim().min(1).max(200),description:z.string().nullable(),
 status:teamStatusSchema,team_lead_user_id:z.uuid().nullable(),master_user_id:z.uuid(),workspace_id:z.uuid(),
 workspace_type:z.literal("TEAM"),created_by:z.uuid(),created_at:z.iso.datetime({offset:true}),
 updated_at:z.iso.datetime({offset:true}),archived_at:z.iso.datetime({offset:true}).nullable(),
});
export type Team=z.infer<typeof teamSchema>;
