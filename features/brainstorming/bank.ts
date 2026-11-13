import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {composeSolutionBankSchema,composedSolutionBankSchema,type ComposedSolutionBank} from "./bank-schema";
export async function composeSolutionBank(input:unknown):Promise<ComposedSolutionBank>{
 try{
  const actor=await getAuthorizationContext();const parsed=composeSolutionBankSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}=await db.rpc("compose_solution_bank",{target_instance:v.activityInstanceId,solution_ids:v.solutionIds,bank_title:v.title??null});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");
  const result=composedSolutionBankSchema.safeParse(data);
  if(!result.success)throw new AuthorizationError("NOT_FOUND");
  const {artifact:a,version:d}=result.data;
  if(a.artifact_type!=="SOLUTION_BANK"||a.activity_instance_id!==v.activityInstanceId||a.status!=="ACTIVE"||a.archived_at!==null||d.artifact_id!==a.id||d.status!=="DRAFT"||d.created_by!==actor.userId||d.approved_by!==null||d.approved_at!==null||d.draft_revision!==0||JSON.stringify(d.content_snapshot)!==JSON.stringify({solution_count:v.solutionIds.length}))throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
}
