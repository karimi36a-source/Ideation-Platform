import {z} from "zod";
import {developmentObjectTypeSchema} from "@/features/projects/object-schema";
import {votingSessionStatusSchema,votingRevealModeSchema} from "./schema";
const count=z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER);
const timestamp=z.iso.datetime({offset:true}).nullable();
export const votingResultsSchema=z.strictObject({
 session:z.strictObject({id:z.uuid(),status:votingSessionStatusSchema,votingType:z.literal("DOT_VOTE"),voteLimit:count,anonymous:z.boolean(),revealMode:votingRevealModeSchema,openedAt:timestamp,closedAt:timestamp,revealed:z.boolean()}),
 options:z.array(z.strictObject({id:z.uuid(),sequence:count.positive(),label:z.string().min(1),description:z.string().nullable(),developmentObject:z.strictObject({id:z.uuid(),objectType:developmentObjectTypeSchema,title:z.string().min(1),status:z.string().nullable()}).nullable(),voteCount:count.nullable()})),
 totalVotes:count.nullable(),
}).refine(value=>{
 const s=value.session;
 const visible=(s.revealMode==="LIVE"&&s.status!=="DRAFT")||s.revealed;
 return (!s.revealed||(s.revealMode==="HIDDEN_UNTIL_REVEAL"&&s.status==="CLOSED"))
 &&new Set(value.options.map(o=>o.id)).size===value.options.length
 &&value.options.every((o,i)=>i===0||o.sequence>value.options[i-1].sequence)
 &&(visible?value.totalVotes!==null&&value.options.every(o=>o.voteCount!==null)&&value.options.reduce((sum,o)=>sum+(o.voteCount??0),0)===value.totalVotes:value.totalVotes===null&&value.options.every(o=>o.voteCount===null));
});
export type VotingResults=z.infer<typeof votingResultsSchema>;
