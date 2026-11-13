import {z} from "zod";
export const artifactObjectLinkSchema=z.strictObject({
 id:z.uuid(),artifact_id:z.uuid(),artifact_version_id:z.uuid(),development_object_id:z.uuid(),
 role_in_artifact:z.string().min(1).refine(v=>v===v.trim(),{message:"Role must be trimmed"}).nullable(),
 sequence:z.number().int().nonnegative().max(2147483647).nullable(),
 metadata:z.record(z.string(),z.json()),
});
export type ArtifactObjectLink=z.infer<typeof artifactObjectLinkSchema>;
