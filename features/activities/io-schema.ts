import {z} from "zod";
const common={id:z.uuid(),activity_instance_id:z.uuid(),evidence_id:z.null(),created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true})};
export const activityInputSchema=z.discriminatedUnion("input_type",[
 z.strictObject({...common,input_type:z.literal("evidence"),evidence_id:z.uuid(),development_object_id:z.null(),artifact_id:z.null(),artifact_version_id:z.null(),required:z.boolean()}),
 z.strictObject({...common,input_type:z.literal("development_object"),development_object_id:z.uuid(),artifact_id:z.null(),artifact_version_id:z.null(),required:z.boolean()}),
 z.strictObject({...common,input_type:z.literal("artifact"),development_object_id:z.null(),artifact_id:z.uuid(),artifact_version_id:z.null(),required:z.boolean()}),
 z.strictObject({...common,input_type:z.literal("artifact_version"),development_object_id:z.null(),artifact_id:z.uuid(),artifact_version_id:z.uuid(),required:z.boolean()}),
]);
export const activityOutputSchema=z.discriminatedUnion("output_type",[
 z.strictObject({...common,output_type:z.literal("evidence"),evidence_id:z.uuid(),development_object_id:z.null(),artifact_id:z.null(),decision_id:z.null()}),
 z.strictObject({...common,output_type:z.literal("development_object"),development_object_id:z.uuid(),artifact_id:z.null(),decision_id:z.null()}),
 z.strictObject({...common,output_type:z.literal("artifact"),development_object_id:z.null(),artifact_id:z.uuid(),decision_id:z.null()}),
]);
export type ActivityInput=z.infer<typeof activityInputSchema>;
export type ActivityOutput=z.infer<typeof activityOutputSchema>;
