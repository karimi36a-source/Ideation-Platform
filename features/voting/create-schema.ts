import {z} from "zod";
import {votingSessionSchema,votingOptionSchema,votingRevealModeSchema} from "./schema";
const uuid=z.uuid().transform(value=>value.toLowerCase());
export const votingChoiceSchema=z.strictObject({developmentObjectId:uuid.optional(),label:z.string().refine(value=>value.trim().length>0),description:z.string().optional()});
export const createVotingSessionSchema=z.strictObject({
 activityInstanceId:uuid,votingType:z.literal("DOT_VOTE"),voteLimit:z.number().int().min(0).max(2147483647),
 anonymous:z.boolean(),revealMode:votingRevealModeSchema,options:z.array(votingChoiceSchema).min(1),
}).refine(value=>{
 const ids=value.options.flatMap(option=>option.developmentObjectId?[option.developmentObjectId]:[]);
 return new Set(ids).size===ids.length;
},{message:"Duplicate Object option"});
export const createdVotingSessionSchema=z.strictObject({session:votingSessionSchema,options:z.array(votingOptionSchema).min(1)});
export type CreatedVotingSession=z.infer<typeof createdVotingSessionSchema>;
