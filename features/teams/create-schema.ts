import {z} from "zod";
export const createTeamSchema=z.strictObject({
 cohortId:z.uuid(),name:z.string().trim().min(1).max(200),description:z.string().optional(),
 projectId:z.uuid().optional(),teamLeadUserId:z.uuid().optional(),
});
export const createdTeamSchema=z.strictObject({teamId:z.uuid(),workspaceId:z.uuid(),chatChannelId:z.uuid()});
export type CreatedTeam=z.infer<typeof createdTeamSchema>;
