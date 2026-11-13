import {z} from "zod";
import {activityAvailabilityReasonSchema} from "./availability-schema";
import {activityInstanceSchema} from "./instance-schema";
import {activityMethodSchema} from "./schema";
export const activityStartSnapshotSchema=z.strictObject({method_type:activityMethodSchema,workspace_mode:z.enum(["Personal Workspace","Team Workspace"]),instructions:z.string().nullable(),ai_role_code:z.string().nullable(),requires_review:z.boolean(),requires_approval:z.boolean(),completion_rule:z.string().nullable(),configuration:z.record(z.string(),z.json())});
export const startedActivitySchema=activityInstanceSchema.refine(v=>v.status==="active"&&v.started_by!==null&&v.started_at!==null&&v.completed_at===null&&activityStartSnapshotSchema.safeParse(v.configuration_snapshot).success);
export const activityStartResultSchema=z.discriminatedUnion("started",[
 z.strictObject({started:z.literal(true),activity:startedActivitySchema}),
 z.strictObject({started:z.literal(false),reasonCode:activityAvailabilityReasonSchema,existingActiveInstanceId:z.uuid().optional()}).refine(v=>v.existingActiveInstanceId===undefined||v.reasonCode==="ACTIVE_INSTANCE_EXISTS"),
]);
export type ActivityStartResult=z.infer<typeof activityStartResultSchema>;
