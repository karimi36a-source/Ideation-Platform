import { z } from "zod";
import { artifactSchema } from "@/features/artifacts/schema";
import { artifactVersionSchema } from "@/features/artifacts/version-schema";
import { developmentRelationshipTypeSchema } from "@/features/projects/relationship-schema";
const id = z.uuid().transform(v => v.toLowerCase());
const reference = z.union([id, z.literal("CONFIRMED_OBJECT")]);
const common = {
 activityInstanceId: id, affinityGroupId: id,
 idempotencyKey: z.string().trim().min(1).max(200),
 relationships: z.array(z.strictObject({ sourceObjectId: reference, targetObjectId: reference,
  relationshipType: developmentRelationshipTypeSchema })).max(100).optional(),
};
export const confirmAffinityStructureSchema = z.discriminatedUnion("mode", [
 z.strictObject({ ...common, mode: z.literal("LINK_EXISTING"), targetObjectId: id }),
 z.strictObject({ ...common, mode: z.literal("CREATE_NEW"), newObject: z.strictObject({
  objectType: z.enum(["SYSTEM", "SUBSYSTEM", "COMPONENT", "FUNCTION", "GAP"]),
  title: z.string().trim().min(1).max(200), content: z.string().max(100000).optional(),
 }) }),
]);
export const affinityStructureResultSchema = z.strictObject({
 resolvedDevelopmentObjectId: id, relationshipIds: z.array(id), artifact: artifactSchema,
 version: artifactVersionSchema, activityOutputId: id.nullable(), replayed: z.boolean(),
});
export type AffinityStructureResult = z.infer<typeof affinityStructureResultSchema>;
