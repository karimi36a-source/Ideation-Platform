import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {decisionLinkSchema,type DecisionLink} from "./schema";
import {supersedeDecisionSchema} from "./supersede-schema";
export class DecisionSupersessionError extends Error {
 constructor(readonly code:"CONFLICT"|"INVALID_STATE"|"DEPENDENCY_REQUIRED") {super(code==="CONFLICT"?"Link conflicts with persisted state.":code==="DEPENDENCY_REQUIRED"?"Target dependency is unavailable.":"Decision is not writable.");}
}
/** Canonical persisted Decision Link; identity, authority and retry semantics live in the atomic RPC. */
export async function supersedeDecision(input:unknown):Promise<DecisionLink>{
 try {
  const actor=await getAuthorizationContext();
  const parsed=supersedeDecisionSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response=await db.rpc("supersede_decision",{input:parsed.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error){
   if(response.error.code==="40001")throw new DecisionSupersessionError("CONFLICT");
   if(response.error.code==="55000")throw new DecisionSupersessionError("INVALID_STATE");
   if(response.error.code==="0A000")throw new DecisionSupersessionError("DEPENDENCY_REQUIRED");
   if(response.error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
   throw new AuthorizationError(["22023","22P02"].includes(response.error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=decisionLinkSchema.safeParse(response.data);
  if(!result.success||result.data.decision_id.toLowerCase()!==parsed.data.newDecisionId.toLowerCase()||result.data.linked_entity_type!=="DECISION"||result.data.linked_entity_id.toLowerCase()!==parsed.data.oldDecisionId.toLowerCase()||result.data.relationship_type!=="SUPERSEDES")throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof DecisionSupersessionError)throw new DecisionSupersessionError(error.code);
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
