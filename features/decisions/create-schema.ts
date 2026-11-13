import {z} from "zod";
import {decisionSchema,decisionOptionSchema,decisionMethodSchema} from "./schema";
const uuid=z.uuid().transform(value=>value.toLowerCase());
export const decisionChoiceSchema=z.strictObject({label:z.string().trim().min(1),description:z.string().optional(),developmentObjectId:uuid.optional()});
export const createDecisionSchema=z.strictObject({projectId:uuid,workspaceId:uuid,activityInstanceId:uuid.optional(),title:z.string().trim().min(1),question:z.string().trim().min(1),method:decisionMethodSchema,options:z.array(decisionChoiceSchema).min(1)}).refine(value=>{
 const ids=value.options.flatMap(option=>option.developmentObjectId?[option.developmentObjectId]:[]);
 return new Set(ids).size===ids.length;
},{message:"Duplicate Object option"});
export const createdDecisionSchema=z.strictObject({decision:decisionSchema,options:z.array(decisionOptionSchema).min(1)});
export type CreatedDecision=z.infer<typeof createdDecisionSchema>;
