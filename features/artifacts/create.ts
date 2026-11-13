import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {createArtifactSchema,createdArtifactSchema} from "./create-schema";
/** One caller-bound database transaction; no service key or identity override. */
export async function createArtifact(input:unknown){try{
 const actor=await getAuthorizationContext();
 const parsed=createArtifactSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const v=parsed.data;const db=await createServerSupabaseClient();
 const project=await db.from("development_projects").select("*").eq("id",v.projectId).maybeSingle();
 if(project.error||!project.data||project.data.primary_workspace_id!==v.workspaceId)throw new AuthorizationError("FORBIDDEN");
 if(!(await getWorkspaceAccess(v.workspaceId)).canCreate)throw new AuthorizationError("FORBIDDEN");
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const result=await db.rpc("create_artifact",{target_project:v.projectId,target_workspace:v.workspaceId,kind:v.artifactType,artifact_title:v.title,target_activity:v.activityInstanceId??null,needs_review:v.reviewRequired,needs_approval:v.approvalRequired});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":result.error.code==="22023"?"VALIDATION_ERROR":"FORBIDDEN");
 const created=createdArtifactSchema.safeParse(result.data);if(!created.success)throw new AuthorizationError("FORBIDDEN");
 return created.data;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");}}
