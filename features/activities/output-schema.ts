import {z} from "zod";
export const addActivityOutputSchema=z.union([
 z.strictObject({activityInstanceId:z.uuid(),evidenceId:z.uuid()}),
 z.strictObject({activityInstanceId:z.uuid(),developmentObjectId:z.uuid()}),
 z.strictObject({activityInstanceId:z.uuid(),artifactId:z.uuid()}),
]);
export type AddActivityOutput=z.infer<typeof addActivityOutputSchema>;
