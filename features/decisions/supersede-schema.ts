import {z} from "zod";
export const supersedeDecisionSchema=z.strictObject({oldDecisionId:z.uuid(),newDecisionId:z.uuid()}).refine(v=>v.oldDecisionId.toLowerCase()!==v.newDecisionId.toLowerCase());
export type SupersedeDecisionInput=z.infer<typeof supersedeDecisionSchema>;
