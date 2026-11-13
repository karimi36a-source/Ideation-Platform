import {z} from "zod";
export const workspaceTypeSchema=z.enum(["PERSONAL","TEAM","MASTER","SHARED","CASE_STUDY"]);
export const workspaceStatusSchema=z.enum(["active","inactive","archived"]);
export const workspaceVisibilitySchema=z.enum(["private"]);
export const workspaceSchema=z.object({
 id:z.uuid(),workspace_type:workspaceTypeSchema,name:z.string().trim().min(1).max(200),
 owner_user_id:z.uuid().nullable(),team_id:z.uuid().nullable(),cohort_id:z.uuid().nullable(),project_id:z.uuid().nullable(),
 status:workspaceStatusSchema,visibility:workspaceVisibilitySchema,settings:z.record(z.string(),z.json()),
 created_at:z.iso.datetime({offset:true}),created_by:z.uuid(),updated_at:z.iso.datetime({offset:true}),updated_by:z.uuid(),archived_at:z.iso.datetime({offset:true}).nullable(),
}).refine(v=>v.workspace_type!=="PERSONAL"||v.owner_user_id!==null);
export type Workspace=z.infer<typeof workspaceSchema>;
