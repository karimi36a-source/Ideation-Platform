import {z} from "zod";
const canonicalUuid=z.uuid().transform(value=>value.toLowerCase());
export const createBrainstormEntrySchema=z.strictObject({activityInstanceId:canonicalUuid,content:z.string(),visibilityState:z.literal("private"),parentEntryId:canonicalUuid.optional()});
export type CreateBrainstormEntryInput=z.infer<typeof createBrainstormEntrySchema>;
