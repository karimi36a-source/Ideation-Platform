import {z} from "zod";
export const projectMembershipRoleSchema=z.enum(["participant"]);
export const projectMembershipStatusSchema=z.enum(["active","inactive"]);
export const projectMembershipSchema=z.object({id:z.uuid(),project_id:z.uuid(),user_id:z.uuid(),project_role:projectMembershipRoleSchema,
 starts_at:z.iso.datetime({offset:true}),ends_at:z.iso.datetime({offset:true}).nullable(),status:projectMembershipStatusSchema,
 created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true}),
}).refine(v=>v.ends_at===null||Date.parse(v.ends_at)>=Date.parse(v.starts_at)).refine(v=>v.status!=="inactive"||v.ends_at!==null);
export type ProjectMembership=z.infer<typeof projectMembershipSchema>;
