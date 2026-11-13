import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {ArtifactDraftConflictError,ArtifactDraftStateError} from "@/features/artifacts/update-draft";
import {createMindMapVersionSchema,createdMindMapVersionSchema,type CreatedMindMapVersion} from "./version-schema";
export async function createMindMapVersion(raw:unknown):Promise<CreatedMindMapVersion>{try{
 const actor=await getAuthorizationContext();const parsed=createMindMapVersionSchema.safeParse(raw);
 if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const {data,error}=await db.rpc("create_mind_map_version",{input:parsed.data});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(error){if(error.code==="23505")throw new ArtifactDraftConflictError();if(error.code==="55000")throw new ArtifactDraftStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");}
 const result=createdMindMapVersionSchema.safeParse(data);
 if(!result.success||result.data.mindMap.id===parsed.data.mindMapId||result.data.version.artifact_id!==result.data.mindMap.artifact_id||result.data.version.id!==result.data.mindMap.artifact_version_id||result.data.version.status!=="DRAFT"||result.data.version.created_by!==actor.userId||result.data.version.draft_revision!==0)throw new AuthorizationError("NOT_FOUND");
 return result.data;
}catch(error){if(error instanceof ArtifactDraftConflictError||error instanceof ArtifactDraftStateError)throw error;
 throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
