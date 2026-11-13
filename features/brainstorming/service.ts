import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {brainstormEntrySchema,type BrainstormEntry} from "./schema";
import {createBrainstormEntrySchema} from "./create-schema";
export class BrainstormConfigurationError extends Error {readonly code="DEPENDENCY_NOT_MET";constructor(){super("Required Activity configuration is unavailable.");this.name="BrainstormConfigurationError";}}
export class BrainstormActivityStateError extends Error {readonly code="INVALID_STATE";constructor(){super("Activity is not writable.");this.name="BrainstormActivityStateError";}}
/** Canonical scope and parent privacy are checked atomically by the caller-bound RPC. */
export async function createBrainstormEntry(input:unknown):Promise<BrainstormEntry>{
 try{
  const actor=await getAuthorizationContext();
  const parsed=createBrainstormEntrySchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response=await db.rpc("create_brainstorm_entry",{target_instance:v.activityInstanceId,entry_content:v.content,visibility_state:v.visibilityState,parent_entry:v.parentEntryId??null});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error){
   if(response.error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
   if(response.error.code==="0A000")throw new BrainstormConfigurationError();
   if(response.error.code==="55000")throw new BrainstormActivityStateError();
   throw new AuthorizationError(["22023","22P02"].includes(response.error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=brainstormEntrySchema.safeParse(response.data);
  if(!result.success)throw new AuthorizationError("NOT_FOUND");
  const row=result.data;
  if(row.created_by!==actor.userId||row.updated_by!==actor.userId||row.activity_instance_id!==v.activityInstanceId||row.content!==v.content
   ||row.parent_entry_id!==(v.parentEntryId??null)||row.status!=="active"||row.revealed_at!==null||row.archived_at!==null||row.development_object_id!==null)throw new AuthorizationError("NOT_FOUND");
  return row;
 }catch(error){
  if(error instanceof BrainstormConfigurationError)throw new BrainstormConfigurationError();
  if(error instanceof BrainstormActivityStateError)throw new BrainstormActivityStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
