import {z} from "zod";
export const removeTeamMemberSchema=z.strictObject({teamId:z.uuid(),userId:z.uuid(),reason:z.string().optional()});
export const removedTeamMemberSchema=z.strictObject({teamId:z.uuid(),membershipId:z.uuid()});
