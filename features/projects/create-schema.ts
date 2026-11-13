import {z} from "zod";
const shared={name:z.string().trim().min(1).max(200),description:z.string().optional(),primaryWorkspaceId:z.uuid()};
export const createDevelopmentProjectSchema=z.discriminatedUnion("projectType",[
 z.strictObject({...shared,projectType:z.literal("individual"),ownerUserId:z.uuid().nullable().optional(),ownerTeamId:z.null().optional()}),
 z.strictObject({...shared,projectType:z.literal("team"),ownerTeamId:z.uuid(),ownerUserId:z.null().optional()}),
 z.strictObject({...shared,projectType:z.literal("instructor_case_study"),ownerUserId:z.uuid(),ownerTeamId:z.null().optional()}),
]);
