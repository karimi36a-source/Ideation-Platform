import {z} from "zod";

export const activityParticipantRoleSchema=z.literal("participant");
export const activityParticipantSchema=z.strictObject({
 id:z.uuid(),activity_instance_id:z.uuid(),user_id:z.uuid(),participant_role:activityParticipantRoleSchema,
 joined_at:z.iso.datetime({offset:true}),completed_at:z.iso.datetime({offset:true}).nullable(),
 created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true}),
}).refine(v=>v.completed_at===null||Date.parse(v.completed_at)>=Date.parse(v.joined_at),{message:"Participation completion precedes join"});
export type ActivityParticipant=z.infer<typeof activityParticipantSchema>;
