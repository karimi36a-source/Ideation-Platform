import "server-only";
import {getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {sharedEntityAccessInputSchema,sharedEntityAccessResultSchema,deniedSharedEntityAccess,type SharedEntityAccess} from "./access-schema";
/** One caller-bound authority for frozen recipient access. Never hydrate source IDs. */
export async function resolveSharedEntityAccess(input:unknown):Promise<SharedEntityAccess>{
 try{
  const actor=await getAuthorizationContext(),parsed=sharedEntityAccessInputSchema.safeParse(input);
  if(!parsed.success)return {...deniedSharedEntityAccess};
  const db=await createServerSupabaseClient();
  const call=async()=>{
   const r=await db.rpc("resolve_shared_entity_access",{input:parsed.data});
   if(r.error)throw Error("Shared access unavailable");
   const result=sharedEntityAccessResultSchema.parse(r.data);
   if(result.allowed&&result.shareId.toLowerCase()!==parsed.data.shareId.toLowerCase())throw Error("Shared access unavailable");
   return result;
  };
  const first=await call();if(!first.allowed)return first;
  if((await getAuthorizationContext()).userId!==actor.userId)return {...deniedSharedEntityAccess};
  // Fresh call after awaited identity I/O: no cached membership/revocation result.
  const current=await call();
  if(current.allowed&&(current.sharedEntityType!==first.sharedEntityType||current.sharedEntityId!==first.sharedEntityId||current.sourceVersionId!==first.sourceVersionId))return {...deniedSharedEntityAccess};
  return current;
 }catch{return {...deniedSharedEntityAccess};}
}
