import {z} from "zod";
export const addTeamMemberSchema=z.strictObject({teamId:z.uuid(),userId:z.uuid(),membershipRole:z.enum(["member","team_lead","mentor"])});
export const addedTeamMemberSchema=z.strictObject({teamId:z.uuid(),membershipId:z.uuid(),chatMembershipId:z.uuid()});
