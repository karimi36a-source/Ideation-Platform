import {z} from "zod";
import {shareabilityInputSchema} from "./shareability-schema";
export const shareEntityInputSchema=shareabilityInputSchema.extend({sourceVersionId:z.uuid().nullable().optional()})
 .refine(v=>v.entityType==="ARTIFACT"?v.sourceVersionId!=null:v.sourceVersionId==null,"Invalid source Version selection");
export type ShareEntityInput=z.infer<typeof shareEntityInputSchema>;
