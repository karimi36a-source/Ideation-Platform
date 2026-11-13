import {z} from "zod";
const id=z.uuid().transform(v=>v.toLowerCase());
const position=z.number().int().min(1).max(2147483647);
export const addAffinityItemSchema=z.strictObject({affinityGroupId:id,developmentObjectId:id.optional(),brainstormEntryId:id.optional(),position:position.optional()}).refine(v=>(v.developmentObjectId!==undefined)!==(v.brainstormEntryId!==undefined));
export const moveAffinityItemSchema=z.strictObject({itemId:id,targetGroupId:id,position,expectedRevision:z.number().int().min(0).max(2147483647)});
