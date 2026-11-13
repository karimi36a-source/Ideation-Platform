import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {addActivityInputSchema} from "./input-schema";
import {activityInputSchema} from "./io-schema";
export class ActivityInputConflictError extends Error {readonly code="CONFLICT";constructor(){super("Activity input conflict.");this.name="ActivityInputConflictError";}}
export class ActivityInputStateError extends Error {readonly code="INVALID_STATE";constructor(){super("Activity is not writable.");this.name="ActivityInputStateError";}}
/** One database transaction derives all context; no caller identity/scope claims. */
export async function addActivityInput(input:unknown){
 try{
  const before=await getAuthorizationContext();
  const parsed=addActivityInputSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  const latest=await getAuthorizationContext();if(latest.userId!==before.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}="evidenceId" in v
   ?await db.rpc("add_activity_evidence_input",{target_instance:v.activityInstanceId,target_evidence:v.evidenceId,is_required:v.required})
   :"developmentObjectId" in v
   ?await db.rpc("add_activity_input",{target_instance:v.activityInstanceId,target_object:v.developmentObjectId,is_required:v.required})
   :await db.rpc("add_activity_artifact_input",{target_instance:v.activityInstanceId,target_artifact:v.artifactId,target_version:v.artifactVersionId??null,is_required:v.required});
  const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){if(error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");if(error.code==="23505")throw new ActivityInputConflictError();if(error.code==="55000")throw new ActivityInputStateError();throw new AuthorizationError("NOT_FOUND");}
  const row=activityInputSchema.safeParse(data);
  if(!row.success||row.data.activity_instance_id!==v.activityInstanceId||row.data.required!==v.required||("evidenceId" in v
   ?row.data.evidence_id!==v.evidenceId||row.data.input_type!=="evidence"
   :"developmentObjectId" in v
   ?row.data.development_object_id!==v.developmentObjectId||row.data.input_type!=="development_object"
   :row.data.artifact_id!==v.artifactId||row.data.artifact_version_id!==(v.artifactVersionId??null)||row.data.input_type!==(v.artifactVersionId?"artifact_version":"artifact")))throw new AuthorizationError("NOT_FOUND");
  return row.data;
 }catch(error){
  if(error instanceof ActivityInputConflictError)throw new ActivityInputConflictError();
  if(error instanceof ActivityInputStateError)throw new ActivityInputStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"NOT_FOUND");
 }
}
