import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {artifactSchema} from "./schema";
import {artifactVersionSchema} from "./version-schema";
import {createArtifactVersionSchema} from "./create-version-schema";
export class DeferredArtifactSourceError extends AuthorizationError {constructor(){super("VALIDATION_ERROR");this.name="DeferredArtifactSourceError";this.message="Decision, Evidence and AI source references are deferred until their canonical integrations exist.";}}
/** Current auth in the server and database transaction; no client lineage. */
export async function createArtifactVersion(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=createArtifactVersionSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const v=parsed.data;if([v.sourceDecisionIds,v.sourceEvidenceIds,v.sourceAiOutputIds].some(ids=>ids&&ids.length>0))throw new DeferredArtifactSourceError();
 const db=await createServerSupabaseClient();const result=await db.from("artifacts").select("*").eq("id",v.artifactId).maybeSingle();const a=artifactSchema.safeParse(result.data);
 if(result.error||!a.success||a.data.id!==v.artifactId||a.data.status!=="ACTIVE"||a.data.archived_at!==null)throw new AuthorizationError("FORBIDDEN");
 if(!(await getWorkspaceAccess(a.data.workspace_id)).canEdit)throw new AuthorizationError("FORBIDDEN");
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const created=await db.rpc("create_artifact_version",{target_artifact:v.artifactId,snapshot:v.contentSnapshot,summary:v.changeSummary,decision_ids:[],evidence_ids:[],ai_output_ids:[]});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 if(created.error)throw new AuthorizationError(created.error.code==="28000"?"AUTH_REQUIRED":created.error.code==="22023"?"VALIDATION_ERROR":"FORBIDDEN");
 const row=artifactVersionSchema.safeParse(created.data);
 if(!row.success||row.data.artifact_id!==v.artifactId||row.data.created_by!==actor.userId||row.data.status!=="DRAFT"||row.data.version_label!==null||row.data.approved_by!==null||row.data.approved_at!==null||row.data.approval_note!==null)throw new AuthorizationError("FORBIDDEN");return row.data;
}catch(error){if(error instanceof DeferredArtifactSourceError)throw new DeferredArtifactSourceError();throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");}}
