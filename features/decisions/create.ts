import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {createDecisionSchema,createdDecisionSchema,type CreatedDecision} from "./create-schema";
export class DecisionActivityStateError extends Error {readonly code="INVALID_STATE";constructor(){super("Activity is not writable.");}}
/** Explicit new human-authored Draft; no automatic retries or content deduplication. */
export async function createDecision(input:unknown):Promise<CreatedDecision>{
 try {
  const actor=await getAuthorizationContext();
  const parsed=createDecisionSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response=await db.rpc("create_decision",{input:v});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error){
   if(response.error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
   if(response.error.code==="55000")throw new DecisionActivityStateError();
   throw new AuthorizationError(["22023","22P02"].includes(response.error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=createdDecisionSchema.safeParse(response.data);
  if(!result.success)throw new AuthorizationError("NOT_FOUND");
  const {decision:d,options}=result.data;
  if(d.project_id!==v.projectId||d.workspace_id!==v.workspaceId||d.activity_instance_id!==(v.activityInstanceId??null)||d.decision_owner_user_id!==actor.userId
   ||d.status!=="DRAFT"||d.outcome!==null||d.reasoning!==null||d.decided_at!==null||d.title!==v.title||d.question!==v.question||d.method!==v.method
   ||options.length!==v.options.length||new Set(options.map(o=>o.id)).size!==options.length
   ||options.some((o,i)=>o.decision_id!==d.id||o.selected||o.label!==v.options[i].label||o.description!==(v.options[i].description??null)||o.development_object_id!==(v.options[i].developmentObjectId??null)))throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof DecisionActivityStateError)throw new DecisionActivityStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
