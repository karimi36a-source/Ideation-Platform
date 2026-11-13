import {z} from "zod";
import {artifactTypeSchema} from "./schema";
export const createArtifactSchema=z.strictObject({
 projectId:z.uuid(),workspaceId:z.uuid(),artifactType:artifactTypeSchema,title:z.string().trim().min(1),
 activityInstanceId:z.uuid().nullable().optional(),reviewRequired:z.boolean(),approvalRequired:z.boolean(),
});
export const createdArtifactSchema=z.strictObject({artifactId:z.uuid(),initialVersionId:z.uuid(),versionNumber:z.literal(1),versionStatus:z.literal("DRAFT"),artifactStatus:z.literal("ACTIVE"),currentVersionId:z.null()});
export type CreatedArtifact=z.infer<typeof createdArtifactSchema>;
