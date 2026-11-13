import {z} from "zod";
export const addActivityInputSchema=z.union([
 z.strictObject({activityInstanceId:z.uuid(),evidenceId:z.uuid(),required:z.boolean()}),
 z.strictObject({activityInstanceId:z.uuid(),developmentObjectId:z.uuid(),required:z.boolean()}),
 z.strictObject({activityInstanceId:z.uuid(),artifactId:z.uuid(),artifactVersionId:z.uuid().optional(),required:z.boolean()}),
]);
export type AddActivityInput=z.infer<typeof addActivityInputSchema>;
