import "server-only";
import {getAuthorizationContext,AuthorizationError} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {activityAvailabilityInputSchema} from "./availability-schema";
import {activityDependenciesSchema,type ActivityDependencies} from "./dependencies-schema";

/** Read-only current eligibility, not an authorization token. The eventual start
 * transaction must re-evaluate scope/availability atomically before creating state. */
export async function evaluateActivityDependencies(input:unknown):Promise<ActivityDependencies>{
 try{
  const before=await getAuthorizationContext();
  const parsed=activityAvailabilityInputSchema.safeParse(input);
  if(!parsed.success)return {satisfied:false,blockingReason:"INVALID_CONTEXT",missingRequiredDependencies:[],optionalUnsatisfiedDependencies:[]};
  const v=parsed.data;const db=await createServerSupabaseClient();
  const result=await db.rpc("evaluate_activity_dependencies",{target_definition:v.activityDefinitionId,target_project:v.projectId,target_workspace:v.workspaceId,target_team:v.teamId??null});
  if(result.error)return {satisfied:false,blockingReason:"INVALID_CONTEXT",missingRequiredDependencies:[],optionalUnsatisfiedDependencies:[]};
  const validated=activityDependenciesSchema.safeParse(result.data);
  const current=await getAuthorizationContext();
  if(!validated.success||current.userId!==before.userId)return {satisfied:false,blockingReason:"INVALID_CONTEXT",missingRequiredDependencies:[],optionalUnsatisfiedDependencies:[]};
  return validated.data;
 }catch(error){
  return {satisfied:false,blockingReason:error instanceof AuthorizationError&&error.code==="AUTH_REQUIRED"?"UNAUTHENTICATED":"INVALID_CONTEXT",missingRequiredDependencies:[],optionalUnsatisfiedDependencies:[]};
 }
}
