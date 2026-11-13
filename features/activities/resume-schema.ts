import {z} from "zod";
import {activityInstanceSchema} from "./instance-schema";
import {activityInputSchema,activityOutputSchema} from "./io-schema";
import {activityParticipantSchema} from "./participant-schema";
export const activityResumeStateSchema=z.strictObject({
 activity:activityInstanceSchema,definition:z.strictObject({id:z.uuid(),name:z.string()}),
 inputs:z.array(activityInputSchema),outputs:z.array(activityOutputSchema),participants:z.array(activityParticipantSchema),
}).refine(v=>v.definition.id===v.activity.activity_definition_id&&
 [...v.inputs,...v.outputs,...v.participants].every(x=>x.activity_instance_id===v.activity.id)&&
 [v.inputs,v.outputs,v.participants].every(rows=>new Set(rows.map(x=>x.id)).size===rows.length),{message:"Inconsistent Activity state"});
export type ActivityResumeState=z.infer<typeof activityResumeStateSchema>;
/** No approved input-expectation DSL exists yet. Registered required links retain
 * their explicit flag; an empty expectations list does not assert completeness. */
export function resumedExecution(state:ActivityResumeState){
 const snapshot=state.activity.configuration_snapshot;
 const field=(key:string)=>{const v=snapshot[key];if(v===undefined||v===null)return null;if(typeof v!=="string")throw new Error("Invalid stored execution field");return v;};
 return {...state,instructions:field("instructions"),aiRoleCode:field("ai_role_code"),configurationSnapshot:snapshot,requiredInputExpectations:[] as readonly never[]};
}
export type ResumedActivity=ReturnType<typeof resumedExecution>;
