import {z} from "zod";
export const votingTypeSchema=z.enum(["DOT_VOTE","FIST_TO_FIVE","PLANNING_POKER"]);
export const votingSessionStatusSchema=z.enum(["DRAFT","OPEN","CLOSED"]);
export const votingRevealModeSchema=z.enum(["LIVE","HIDDEN_UNTIL_REVEAL"]);
const timestamp=z.iso.datetime({offset:true});
const integer=z.number().int().min(-2147483648).max(2147483647);
/** Canonical stored rows only. These schemas do not authorize runtime commands. */
export const votingSessionSchema=z.strictObject({
 id:z.uuid(),activity_instance_id:z.uuid(),voting_type:votingTypeSchema,status:votingSessionStatusSchema,
 vote_limit:integer.nonnegative(),anonymous:z.boolean(),reveal_mode:votingRevealModeSchema,
 created_by:z.uuid(),opened_at:timestamp.nullable(),closed_at:timestamp.nullable(),
});
export const votingOptionSchema=z.strictObject({
 id:z.uuid(),voting_session_id:z.uuid(),development_object_id:z.uuid().nullable(),
 label:z.string().refine(value=>value.trim().length>0),description:z.string().nullable(),sequence:integer.positive(),
});
export const voteSchema=z.strictObject({
 id:z.uuid(),voting_session_id:z.uuid(),voting_option_id:z.uuid(),user_id:z.uuid(),value:integer,
 created_at:timestamp,revealed_at:timestamp.nullable(),
});
export type VotingSession=z.infer<typeof votingSessionSchema>;
export type VotingOption=z.infer<typeof votingOptionSchema>;
export type Vote=z.infer<typeof voteSchema>;
