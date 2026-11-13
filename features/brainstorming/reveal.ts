import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {BrainstormConfigurationError,BrainstormActivityStateError} from "./service";
import {revealBrainstormInputSchema,revealBrainstormResultSchema,type RevealBrainstormResult} from "./reveal-schema";
/** The identity-bound RPC validates authority, locks all targets and reveals atomically. */
export async function revealBrainstormEntries(input:unknown):Promise<RevealBrainstormResult>{
 try{
  const actor=await getAuthorizationContext();
  const parsed=revealBrainstormInputSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response=await db.rpc("reveal_brainstorm_entries",{target_instance:v.activityInstanceId,target_entries:v.entryIds});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error){
   if(response.error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
   if(response.error.code==="0A000")throw new BrainstormConfigurationError();
   if(response.error.code==="55000")throw new BrainstormActivityStateError();
   throw new AuthorizationError(["22023","22P02"].includes(response.error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=revealBrainstormResultSchema.safeParse(response.data);
  if(!result.success)throw new AuthorizationError("NOT_FOUND");
  const expected=[...v.entryIds].sort();const actual=result.data.entries.map(e=>e.entryId);
  if(result.data.activityInstanceId!==v.activityInstanceId||actual.length!==expected.length||actual.some((id,i)=>id!==expected[i]))throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof BrainstormConfigurationError)throw new BrainstormConfigurationError();
  if(error instanceof BrainstormActivityStateError)throw new BrainstormActivityStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
