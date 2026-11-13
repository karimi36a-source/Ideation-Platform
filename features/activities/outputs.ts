import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {addActivityOutputSchema} from "./output-schema";
import {activityOutputSchema} from "./io-schema";
export class ActivityOutputStateError extends Error {readonly code="INVALID_STATE";constructor(){super("Activity is not writable.");this.name="ActivityOutputStateError";}}
/** One database transaction derives all context; no caller identity/scope claims. */
export async function addActivityOutput(input:unknown){
 try{
  const before=await getAuthorizationContext();
  const parsed=addActivityOutputSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  const latest=await getAuthorizationContext();if(latest.userId!==before.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}="evidenceId" in v
   ?await db.rpc("add_activity_evidence_output",{target_instance:v.activityInstanceId,target_evidence:v.evidenceId})
   :"developmentObjectId" in v
   ?await db.rpc("add_activity_output",{target_instance:v.activityInstanceId,target_object:v.developmentObjectId})
   :await db.rpc("add_activity_artifact_output",{target_instance:v.activityInstanceId,target_artifact:v.artifactId});
  const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){if(error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");if(error.code==="55000")throw new ActivityOutputStateError();throw new AuthorizationError("NOT_FOUND");}
  const row=activityOutputSchema.safeParse(data);
  if(!row.success||row.data.activity_instance_id!==v.activityInstanceId||("evidenceId" in v
   ?row.data.evidence_id!==v.evidenceId||row.data.output_type!=="evidence"
   :"developmentObjectId" in v
   ?row.data.development_object_id!==v.developmentObjectId||row.data.output_type!=="development_object"
   :row.data.artifact_id!==v.artifactId||row.data.output_type!=="artifact"))throw new AuthorizationError("NOT_FOUND");
  return row.data;
 }catch(error){
  if(error instanceof ActivityOutputStateError)throw new ActivityOutputStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"NOT_FOUND");
 }
}
