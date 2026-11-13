import "server-only";
import {notifyArtifactShareCreated} from "@/features/notifications/share";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {shareEntityInputSchema} from "./create-schema";
import {shareSchema,type Share} from "./schema";
import {shareRuntimePolicyDenial} from "./runtime-policy";
export class ActiveShareDifferentVersionError extends Error {
 readonly code="ACTIVE_SHARE_DIFFERENT_VERSION";
 constructor(){super("ACTIVE_SHARE_DIFFERENT_VERSION");}
}
/** Caller-bound atomic creation. Eligibility is rechecked inside the transaction. */
export async function shareEntity(input:unknown):Promise<Share>{
 try{
  const actor=await getAuthorizationContext(),parsed=shareEntityInputSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  if(shareRuntimePolicyDenial(parsed.data))throw new AuthorizationError("NOT_FOUND");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const result=await db.rpc("share_entity",{input:parsed.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(result.error){
   if(result.error.code==="P1304")throw new ActiveShareDifferentVersionError();
   throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":["22023","22P02"].includes(result.error.code??"")?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const row=shareSchema.safeParse(result.data),v=parsed.data;
  if(!row.success||row.data.shared_entity_type!==v.entityType||row.data.shared_entity_id.toLowerCase()!==v.entityId.toLowerCase()
   ||row.data.destination_type!==v.destinationType||row.data.destination_id.toLowerCase()!==v.destinationId.toLowerCase()
   ||row.data.permission_level!==v.permissionLevel||row.data.share_mode!=="SNAPSHOT"||row.data.revoked_at!==null||row.data.revoked_by!==null)
   throw new AuthorizationError("NOT_FOUND");
  // Retry may return a Share created by a different previously authorized Lead.
  // The user-scoped RPC has committed. Delivery is informational and cannot
  // roll back or change this canonical Share. Non-Artifact Shares stay silent.
  if(row.data.shared_entity_type==='ARTIFACT')await notifyArtifactShareCreated(row.data.id);
  return row.data;
 }catch(error){
  if(error instanceof ActiveShareDifferentVersionError)throw error;
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
