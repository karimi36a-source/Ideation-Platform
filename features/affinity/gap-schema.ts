import { z } from "zod";
import { developmentObjectSchema } from "@/features/projects/object-schema";
import { developmentRelationshipTypeSchema } from "@/features/projects/relationship-schema";
import { artifactSchema } from "@/features/artifacts/schema";
import { artifactVersionSchema } from "@/features/artifacts/version-schema";
const id = z.uuid().transform(v => v.toLowerCase());
const reference = z.union([id, z.literal("CONFIRMED_OBJECT")]);
const common = {
 activityInstanceId: id, idempotencyKey: z.string().trim().min(1).max(200),
 relationships: z.array(z.strictObject({ sourceObjectId: reference, targetObjectId: reference,
  relationshipType: developmentRelationshipTypeSchema })).max(100).optional(),
};
export const captureGapSchema = z.discriminatedUnion("mode", [
 z.strictObject({ ...common, mode: z.literal("ADD_EXISTING"), gapObjectId: id }),
 z.strictObject({ ...common, mode: z.literal("CREATE_NEW"), newGap: z.strictObject({
  title: z.string().trim().min(1).max(200), content: z.string().max(100000).optional(),
 }) }),
]);
export const capturedGapSchema = z.strictObject({ gap: developmentObjectSchema,
 relationshipIds: z.array(id), artifact: artifactSchema, version: artifactVersionSchema,
 activityOutputId: id.nullable(), replayed: z.boolean(), membershipChanged: z.boolean(),
});
export type CapturedGap = z.infer<typeof capturedGapSchema>;
