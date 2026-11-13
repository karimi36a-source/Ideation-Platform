import {z} from "zod";
const uuid=z.uuid().transform(value=>value.toLowerCase());
export const revealBrainstormInputSchema=z.strictObject({activityInstanceId:uuid,entryIds:z.array(uuid).min(1).refine(ids=>new Set(ids).size===ids.length,"Duplicate entries")});
export const revealBrainstormResultSchema=z.strictObject({activityInstanceId:uuid,entries:z.array(z.strictObject({entryId:uuid,revealedAt:z.iso.datetime({offset:true})})).min(1)});
export type RevealBrainstormInput=z.infer<typeof revealBrainstormInputSchema>;
export type RevealBrainstormResult=z.infer<typeof revealBrainstormResultSchema>;
