import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {ArtifactDraftConflictError,ArtifactDraftStateError} from "@/features/artifacts/update-draft";
import {saveMindMapDraftSchema,savedMindMapDraftSchema,type SavedMindMapDraft} from "./draft-schema";
/** Explicit canonical checkpoint; never accepts browser/provider graph state. */
export async function saveMindMapDraft(raw:unknown):Promise<SavedMindMapDraft>{try{
 const actor=await getAuthorizationContext();const input=saveMindMapDraftSchema.safeParse(raw);
 if(!input.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const {data,error}=await db.rpc("save_mind_map_draft",{input:input.data});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(error){if(error.code==="23505")throw new ArtifactDraftConflictError();if(error.code==="55000")throw new ArtifactDraftStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");}
 const result=savedMindMapDraftSchema.safeParse(data);
 if(!result.success||result.data.mindMapId!==input.data.mindMapId||result.data.draftRevision!==input.data.expectedDraftRevision+1)throw new AuthorizationError("NOT_FOUND");
 return result.data;
}catch(error){if(error instanceof ArtifactDraftConflictError||error instanceof ArtifactDraftStateError)throw error;
 throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
