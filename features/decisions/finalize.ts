import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {decisionSchema,type Decision} from "./schema";
import {finalizeDecisionSchema} from "./finalize-schema";
export class DecisionFinalizationError extends Error {
 constructor(readonly code:"CONFLICT"|"INVALID_STATE"|"DEPENDENCY_REQUIRED") {super(code==="CONFLICT"?"Finalization conflicts with persisted state.":code==="DEPENDENCY_REQUIRED"?"Required dependency is unavailable.":"Decision is not finalizable.");}
}
/** Canonical persisted Decision; identity, authority and retry semantics live in the atomic RPC. */
export async function finalizeDecision(input:unknown):Promise<Decision>{
 try {
  const actor=await getAuthorizationContext();
  const parsed=finalizeDecisionSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response=await db.rpc("finalize_decision",{input:parsed.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error){
   if(response.error.code==="40001")throw new DecisionFinalizationError("CONFLICT");
   if(response.error.code==="55000")throw new DecisionFinalizationError("INVALID_STATE");
   if(response.error.code==="0A000")throw new DecisionFinalizationError("DEPENDENCY_REQUIRED");
   if(response.error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
   throw new AuthorizationError(["22023","22P02"].includes(response.error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=decisionSchema.safeParse(response.data);
  if(!result.success||result.data.id!==parsed.data.decisionId||result.data.status!=="FINALIZED"||!result.data.decided_at||result.data.outcome!==parsed.data.outcome||result.data.reasoning!==parsed.data.reasoning)throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof DecisionFinalizationError)throw new DecisionFinalizationError(error.code);
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
