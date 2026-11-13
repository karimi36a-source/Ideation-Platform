import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {artifactSchema} from "./schema";
import {artifactVersionSchema} from "./version-schema";

const inputSchema=z.strictObject({artifactId:z.uuid()});
const resultSchema=z.strictObject({version:artifactVersionSchema,sourceVersionId:z.uuid(),currentVersionId:z.uuid()});

export async function reopenApprovedArtifact(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=inputSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const found=await db.from("artifacts").select("*").eq("id",parsed.data.artifactId).maybeSingle();const artifact=artifactSchema.safeParse(found.data);
 if(found.error||!artifact.success||artifact.data.status!=="ACTIVE"||artifact.data.archived_at!==null||artifact.data.current_version_id===null)throw new AuthorizationError("FORBIDDEN");
 if(!(await getWorkspaceAccess(artifact.data.workspace_id)).canEdit)throw new AuthorizationError("FORBIDDEN");
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const reopened=await db.rpc("reopen_approved_artifact",{target_artifact:parsed.data.artifactId});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 if(reopened.error)throw new AuthorizationError(reopened.error.code==="28000"?"AUTH_REQUIRED":reopened.error.code==="22023"?"VALIDATION_ERROR":"FORBIDDEN");
 const result=resultSchema.safeParse(reopened.data);if(!result.success)throw new AuthorizationError("FORBIDDEN");const v=result.data.version;
 if(v.artifact_id!==parsed.data.artifactId||v.created_by!==actor.userId||v.status!=="DRAFT"||v.previous_version_id!==result.data.sourceVersionId||result.data.currentVersionId!==result.data.sourceVersionId||v.version_label!==null||v.change_summary!==null||v.approved_by!==null||v.approved_at!==null||v.approval_note!==null)throw new AuthorizationError("FORBIDDEN");
 return v;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");}}
