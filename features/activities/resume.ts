import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {activityResumeStateSchema,resumedExecution} from "./resume-schema";
/** Read-only. Scope and identity are never accepted as caller claims. */
export async function resumeActivity(activityInstanceId:unknown){
 try{
  const before=await getAuthorizationContext();
  const id=z.uuid().safeParse(activityInstanceId);if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  const {data,error}=await db.rpc("resume_activity",{target_instance:id.data});
  if(error||data===null)throw new AuthorizationError("NOT_FOUND");
  const result=activityResumeStateSchema.safeParse(data);
  if(!result.success||result.data.activity.id!==id.data)throw new AuthorizationError("NOT_FOUND");
  const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("NOT_FOUND");
  return resumedExecution(result.data);
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"NOT_FOUND");}
}
