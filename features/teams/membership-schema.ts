import {z} from "zod";
export const teamMembershipRoleSchema=z.enum(["member","team_lead","mentor"]);
export const teamMembershipStatusSchema=z.enum(["active","removed"]);
export const teamMembershipSchema=z.object({
 id:z.uuid(),team_id:z.uuid(),user_id:z.uuid(),membership_role:teamMembershipRoleSchema,
 joined_at:z.iso.datetime({offset:true}),left_at:z.iso.datetime({offset:true}).nullable(),status:teamMembershipStatusSchema,
 added_by:z.uuid(),removed_by:z.uuid().nullable(),created_at:z.iso.datetime({offset:true}),
}).refine(row=>row.status==="active"?row.left_at===null&&row.removed_by===null:
 row.left_at!==null&&row.removed_by!==null&&Date.parse(row.left_at)>=Date.parse(row.joined_at));
export type TeamMembership=z.infer<typeof teamMembershipSchema>;
