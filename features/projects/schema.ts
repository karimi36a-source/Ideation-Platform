import {z} from "zod";
export const developmentProjectTypeSchema=z.enum(["individual","team","instructor_case_study"]);
export const developmentProjectStatusSchema=z.enum(["active","paused","completed","archived"]);
const metadata=z.string().refine(v=>v.trim().length>0).nullable();
export const developmentProjectSchema=z.object({
 id:z.uuid(),name:z.string().trim().min(1).max(200),description:z.string().nullable(),
 project_type:developmentProjectTypeSchema,owner_user_id:z.uuid().nullable(),owner_team_id:z.uuid().nullable(),primary_workspace_id:z.uuid(),
 status:developmentProjectStatusSchema,current_stage:metadata,confidentiality_level:metadata,
 created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true}),archived_at:z.iso.datetime({offset:true}).nullable(),
 required_workspace_type:z.enum(["PERSONAL","TEAM","CASE_STUDY"]),
}).refine(v=>v.project_type==="team"?v.owner_team_id!==null&&v.owner_user_id===null:v.owner_user_id!==null&&v.owner_team_id===null)
.refine(v=>v.required_workspace_type===({individual:"PERSONAL",team:"TEAM",instructor_case_study:"CASE_STUDY"} as const)[v.project_type]);
export type DevelopmentProject=z.infer<typeof developmentProjectSchema>;
