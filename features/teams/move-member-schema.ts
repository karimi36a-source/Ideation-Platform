import {z} from "zod";
export const moveTeamMemberSchema=z.strictObject({userId:z.uuid(),fromTeamId:z.uuid(),toTeamId:z.uuid(),reason:z.string().optional()}).refine(v=>v.fromTeamId!==v.toTeamId);
export const movedTeamMemberSchema=z.strictObject({fromTeamId:z.uuid(),toTeamId:z.uuid(),sourceMembershipId:z.uuid(),targetMembershipId:z.uuid(),chatMembershipId:z.uuid()});
