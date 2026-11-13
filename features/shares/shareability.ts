import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {shareEntityTypes} from "./schema";
import {shareRuntimePolicyDenial} from "./runtime-policy";
import {shareabilityInputSchema,shareabilityResultSchema,type ShareabilityResult} from "./shareability-schema";
/** Eligibility only. Call again inside any future Share transaction; this result grants no access. */
export async function resolveShareability(input:unknown):Promise<ShareabilityResult>{
 try{
  const before=await getAuthorizationContext();
  const parsed=shareabilityInputSchema.safeParse(input);
  if(!parsed.success){
   const unsupported=input!==null&&typeof input==="object"&&"entityType" in input&&typeof input.entityType==="string"&&!shareEntityTypes.some(t=>t===input.entityType);
   return {allowed:false,deniedReason:unsupported?"ENTITY_NOT_SHAREABLE":"VALIDATION_ERROR"};
  }
  const deniedReason=shareRuntimePolicyDenial(parsed.data);
  if(deniedReason)return {allowed:false,deniedReason};
  const db=await createServerSupabaseClient();
  // User-scoped RPC derives actor and canonical source/destination; no admin key.
  const call=async()=>{const r=await db.rpc("resolve_shareability",{input:parsed.data});if(r.error)throw new AuthorizationError("FORBIDDEN");return shareabilityResultSchema.parse(r.data);};
  const result=await call();
  if(!result.allowed)return result;
  if((await getAuthorizationContext()).userId!==before.userId)return {allowed:false,deniedReason:"SOURCE_ACCESS_DENIED"};
  // Recheck after awaited identity I/O; do not reuse stale Team authority.
  const current=await call();
  if(current.allowed&&(current.sourceWorkspaceId!==result.sourceWorkspaceId||current.normalizedEntityType!==parsed.data.entityType||current.normalizedDestination.type!==parsed.data.destinationType||current.normalizedDestination.id.toLowerCase()!==parsed.data.destinationId.toLowerCase()))return {allowed:false,deniedReason:"SOURCE_ACCESS_DENIED"};
  return current;
 }catch(error){return {allowed:false,deniedReason:error instanceof AuthorizationError&&error.code==="AUTH_REQUIRED"?"UNAUTHENTICATED":"SOURCE_ACCESS_DENIED"};}
}
