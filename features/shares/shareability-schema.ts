import {z} from "zod";
import {shareEntityTypes,shareDestinationTypes,sharePermissionLevels,shareModes} from "./schema";
export const shareabilityInputSchema=z.strictObject({entityType:z.enum(shareEntityTypes),entityId:z.uuid(),destinationType:z.enum(shareDestinationTypes),destinationId:z.uuid(),permissionLevel:z.enum(sharePermissionLevels),shareMode:z.enum(shareModes)});
export const shareabilityDeniedReasons=["UNAUTHENTICATED","VALIDATION_ERROR","ENTITY_NOT_SHAREABLE","SOURCE_ACCESS_DENIED","SHARE_AUTHORITY_DENIED","SOURCE_RESTRICTED","DESTINATION_INVALID","DESTINATION_SCOPE_DENIED","PERMISSION_NOT_ALLOWED","MODE_NOT_ALLOWED"] as const;
export const shareabilityResultSchema=z.discriminatedUnion("allowed",[
 z.strictObject({allowed:z.literal(false),deniedReason:z.enum(shareabilityDeniedReasons)}),
 z.strictObject({allowed:z.literal(true),sourceWorkspaceId:z.uuid(),normalizedEntityType:z.enum(shareEntityTypes),normalizedDestination:z.strictObject({type:z.enum(["TEAM","MASTER"]),id:z.uuid()}),allowedPermissionLevels:z.tuple([z.literal("VIEW"),z.literal("COMMENT")]),allowedModes:z.tuple([z.literal("SNAPSHOT")])}),
]);
export type ShareabilityResult=z.infer<typeof shareabilityResultSchema>;
