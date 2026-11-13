import {z} from "zod";
import {activityAvailabilityReasonSchema} from "./availability-schema";
const requirement=z.strictObject({dependencyId:z.uuid(),requiredActivityDefinitionId:z.uuid()});
export const activityDependenciesSchema=z.discriminatedUnion("satisfied",[
 z.strictObject({satisfied:z.literal(true),missingRequiredDependencies:z.array(requirement).max(0),optionalUnsatisfiedDependencies:z.array(requirement)}),
 z.strictObject({satisfied:z.literal(false),blockingReason:activityAvailabilityReasonSchema.exclude(["ACTIVE_INSTANCE_EXISTS"]),missingRequiredDependencies:z.array(requirement),optionalUnsatisfiedDependencies:z.array(requirement)}).refine(v=>v.blockingReason==="DEPENDENCY_NOT_MET"?v.missingRequiredDependencies.length>0:v.missingRequiredDependencies.length===0&&v.optionalUnsatisfiedDependencies.length===0),
]);
export type ActivityDependencies=z.infer<typeof activityDependenciesSchema>;
