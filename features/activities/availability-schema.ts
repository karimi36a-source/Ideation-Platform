import {z} from "zod";
export const activityAvailabilityInputSchema=z.strictObject({activityDefinitionId:z.uuid(),projectId:z.uuid(),workspaceId:z.uuid(),teamId:z.uuid().nullable().optional()});
export const activityAvailabilityReasonSchema=z.enum(["UNAUTHENTICATED","INVALID_CONTEXT","ACTIVITY_NOT_AVAILABLE","NOT_ENROLLED","WORKSPACE_MODE_MISMATCH","LIFECYCLE_NOT_AVAILABLE","DEPENDENCY_NOT_MET","ACTIVE_INSTANCE_EXISTS"]);
export const activityAvailabilitySchema=z.discriminatedUnion("available",[
 z.strictObject({available:z.literal(true)}),
 z.strictObject({available:z.literal(false),reasonCode:activityAvailabilityReasonSchema,existingActiveInstanceId:z.uuid().optional()}).refine(v=>v.existingActiveInstanceId===undefined||v.reasonCode==="ACTIVE_INSTANCE_EXISTS",{message:"Unexpected execution identifier"}),
]);
export type ActivityAvailability=z.infer<typeof activityAvailabilitySchema>;
