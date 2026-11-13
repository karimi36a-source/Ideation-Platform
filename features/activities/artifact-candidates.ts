import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {artifactTypeSchema} from "@/features/artifacts/schema";
import {activityAvailabilityInputSchema} from "./availability-schema";
export const activityArtifactCandidateSchema=z.strictObject({dependencyId:z.uuid(),dependencyType:z.enum(["approved_output","artifact_available"]),artifactId:z.uuid(),artifactVersionId:z.uuid().nullable(),artifactType:artifactTypeSchema}).refine(row=>row.dependencyType!=="approved_output"||row.artifactVersionId!==null);
export type ActivityArtifactCandidate=z.infer<typeof activityArtifactCandidateSchema>;
/** Authorized references only; no source content and no implicit input selection. */
export async function listActivityArtifactCandidates(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=activityAvailabilityInputSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const p=parsed.data;const db=await createServerSupabaseClient();const result=await db.rpc("list_activity_artifact_candidates",{target_definition:p.activityDefinitionId,target_project:p.projectId,target_workspace:p.workspaceId,target_team:p.teamId??null});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const rows=z.array(activityArtifactCandidateSchema).safeParse(result.data);if(result.error||!rows.success)throw new AuthorizationError("NOT_FOUND");return rows.data;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
