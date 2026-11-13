import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {ArtifactDraftConflictError,ArtifactDraftStateError} from "@/features/artifacts/update-draft";
import {finalizeSession7OutputsSchema,finalizedSession7OutputsSchema,type FinalizedSession7Outputs} from "./session7-schema";
export async function finalizeSession7Outputs(raw:unknown):Promise<FinalizedSession7Outputs>{try{
 const actor=await getAuthorizationContext();const parsed=finalizeSession7OutputsSchema.safeParse(raw);
 if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const {data,error}=await db.rpc("finalize_session7_outputs",{input:parsed.data});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(error){if(["23505","40001"].includes(error.code))throw new ArtifactDraftConflictError();if(error.code==="55000")throw new ArtifactDraftStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");}
 const result=finalizedSession7OutputsSchema.safeParse(data);
 if(!result.success||result.data.mindMapId!==parsed.data.mindMapId||result.data.sourceDraftRevision!==parsed.data.expectedDraftRevision
 ||[result.data.mindMap,result.data.essentialStructure,result.data.inventionConcept].some(o=>o.artifact.activity_instance_id!==parsed.data.activityInstanceId||o.artifact.status!=="ACTIVE"||o.artifact.archived_at!==null)
 ||(!result.data.replayed&&[result.data.essentialStructure,result.data.inventionConcept].some(o=>o.version.status!=="DRAFT"||o.version.created_by!==actor.userId||o.version.draft_revision!==0)))throw new AuthorizationError("NOT_FOUND");
 return result.data;
}catch(error){if(error instanceof ArtifactDraftConflictError||error instanceof ArtifactDraftStateError)throw error;
 throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
