import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {activityAvailabilityInputSchema,type ActivityAvailability} from "./availability-schema";
import {activityStartResultSchema} from "./start-schema";
/** Safe eligibility failure; optional existing ID is returned only by the
 * centrally authorized duplicate path. Never includes provider diagnostics. */
export class ActivityStartUnavailableError extends Error {
 readonly code:Extract<ActivityAvailability,{available:false}>["reasonCode"];
 readonly existingActiveInstanceId?:string;
 constructor(code:ActivityStartUnavailableError["code"],existingActiveInstanceId?:string){super("Activity cannot be started.");this.name="ActivityStartUnavailableError";this.code=code;this.existingActiveInstanceId=existingActiveInstanceId;}
}
/** One RPC owns all checks and writes. No external availability result is used
 * as an authorization token; a duplicate start never becomes a resume. */
export async function startActivity(input:unknown){
 try{
  const before=await getAuthorizationContext();
  const parsed=activityAvailabilityInputSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  const latest=await getAuthorizationContext();if(latest.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  const {data,error}=await db.rpc("start_activity",{target_definition:v.activityDefinitionId,target_project:v.projectId,target_workspace:v.workspaceId,target_team:v.teamId??null});
  if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":"FORBIDDEN");
  const result=activityStartResultSchema.safeParse(data);if(!result.success)throw new AuthorizationError("FORBIDDEN");
  const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  if(!result.data.started){if(result.data.reasonCode==="UNAUTHENTICATED")throw new AuthorizationError("AUTH_REQUIRED");throw new ActivityStartUnavailableError(result.data.reasonCode,result.data.existingActiveInstanceId);}
  const row=result.data.activity;
  if(row.started_by!==before.userId||row.activity_definition_id!==v.activityDefinitionId||row.project_id!==v.projectId||row.workspace_id!==v.workspaceId||row.team_id!==(v.teamId??null))throw new AuthorizationError("FORBIDDEN");
  return row;
 }catch(error){
  if(error instanceof ActivityStartUnavailableError)throw new ActivityStartUnavailableError(error.code,error.existingActiveInstanceId);
  throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");
 }
}
