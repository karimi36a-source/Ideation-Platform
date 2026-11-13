import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {createEvidenceSchema} from "./create-schema";
import {evidenceSchema,type Evidence} from "./schema";
export class EvidenceCreationError extends Error {
 constructor(readonly code:"DEPENDENCY_REQUIRED"){super("Files dependency is unavailable.");}
}
/** User-scoped transport; the narrow RPC independently enforces current authority. */
export async function createEvidence(input:unknown):Promise<Evidence>{try{
 const actor=await getAuthorizationContext();
 const parsed=createEvidenceSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const v=parsed.data;const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const r=await db.rpc("create_evidence",{project_id:v.projectId,workspace_id:v.workspaceId,evidence_type:v.evidenceType,title:v.title,description:v.description,source_name:v.sourceName,source_url:v.sourceUrl??null,file_id:v.fileId??null});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(r.error){if(r.error.code==="0A000")throw new EvidenceCreationError("DEPENDENCY_REQUIRED");throw new AuthorizationError(r.error.code==="28000"?"AUTH_REQUIRED":["22023","22P02","23514"].includes(r.error.code??"")?"VALIDATION_ERROR":"NOT_FOUND");}
 const row=evidenceSchema.safeParse(r.data);
 if(!row.success||row.data.project_id!==v.projectId||row.data.workspace_id!==v.workspaceId||row.data.evidence_type!==v.evidenceType||row.data.title!==v.title||row.data.description!==v.description||row.data.source_name!==v.sourceName||row.data.source_url!==(v.sourceUrl??null)||row.data.file_id!==null||row.data.claim_locator!==null||row.data.created_by!==actor.userId||row.data.updated_by!==actor.userId||row.data.verification_status!=="UNVERIFIED"||row.data.verified_by!==null||row.data.verified_at!==null||row.data.archived_at!==null||Object.keys(row.data.metadata).length!==0)throw new AuthorizationError("NOT_FOUND");
 return row.data;
}catch(error){if(error instanceof EvidenceCreationError)throw new EvidenceCreationError(error.code);throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
