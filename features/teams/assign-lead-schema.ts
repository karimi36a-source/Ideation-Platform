import {z} from "zod";
export const assignTeamLeadSchema=z.strictObject({teamId:z.uuid(),userId:z.uuid()});
export const assignedTeamLeadSchema=z.strictObject({teamId:z.uuid(),userId:z.uuid(),membershipId:z.uuid()});
