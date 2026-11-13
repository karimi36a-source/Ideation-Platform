import "server-only";
import {isDeepStrictEqual} from "node:util";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {artifactVersionSchema} from "./version-schema";
export const updateArtifactDraftSchema=z.strictObject({artifactVersionId:z.uuid(),expectedDraftRevision:z.number().int().min(0).max(2147483647),contentSnapshot:z.json(),changeSummary:z.string().trim().nullable().optional()});
export class ArtifactDraftConflictError extends Error{readonly code="CONFLICT";constructor(){super("Draft changed. Reload before saving.");this.name="ArtifactDraftConflictError";}}
export class ArtifactDraftStateError extends Error{readonly code="INVALID_STATE";constructor(){super("Version is not a writable Draft.");this.name="ArtifactDraftStateError";}}
/** Scope and CAS are revalidated inside the single canonical database command. */
export async function updateArtifactDraft(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=updateArtifactDraftSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const v=parsed.data;const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const {data,error}=await db.rpc("update_artifact_draft",{target_version:v.artifactVersionId,expected_revision:v.expectedDraftRevision,snapshot:v.contentSnapshot,summary:v.changeSummary??null,set_summary:v.changeSummary!==undefined});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(error){if(error.code==="23505")throw new ArtifactDraftConflictError();if(error.code==="55000")throw new ArtifactDraftStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","22003"].includes(error.code)?"VALIDATION_ERROR":"NOT_FOUND");}
 const row=artifactVersionSchema.safeParse(data);if(!row.success||row.data.id!==v.artifactVersionId||row.data.status!=="DRAFT"||row.data.draft_revision!==v.expectedDraftRevision+1||!isDeepStrictEqual(row.data.content_snapshot,v.contentSnapshot)||(v.changeSummary!==undefined&&row.data.change_summary!==v.changeSummary))throw new AuthorizationError("NOT_FOUND");return row.data;
}catch(error){if(error instanceof ArtifactDraftConflictError)throw new ArtifactDraftConflictError();if(error instanceof ArtifactDraftStateError)throw new ArtifactDraftStateError();throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
