import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {activityInstanceSchema} from "./instance-schema";
export class ActivityCompletionError extends Error {
 constructor(readonly code:"INVALID_STATE"|"COMPLETION_RULE_UNSUPPORTED"|"COMPLETION_REQUIREMENTS_NOT_MET"){super("Activity cannot be completed.");this.name="ActivityCompletionError";}
}
/** One canonical transaction; no caller time, counts, roles, or lifecycle overrides. */
export async function completeActivity(activityInstanceId:unknown){
 try{
  const before=await getAuthorizationContext();
  const parsed=z.uuid().safeParse(activityInstanceId);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();const latest=await getAuthorizationContext();
  if(latest.userId!==before.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}=await db.rpc("complete_activity",{target_instance:parsed.data});
  const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){
   if(error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
   if(error.code==="55000")throw new ActivityCompletionError("INVALID_STATE");
   if(error.code==="P7010")throw new ActivityCompletionError("COMPLETION_RULE_UNSUPPORTED");
   if(error.code==="P7011")throw new ActivityCompletionError("COMPLETION_REQUIREMENTS_NOT_MET");
   throw new AuthorizationError("NOT_FOUND");
  }
  const row=activityInstanceSchema.safeParse(data);
  if(!row.success||row.data.id!==parsed.data||row.data.status!=="completed")throw new AuthorizationError("NOT_FOUND");
  return row.data;
 }catch(error){
  if(error instanceof ActivityCompletionError)throw new ActivityCompletionError(error.code);
  throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"NOT_FOUND");
 }
}
