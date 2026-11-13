import "server-only";
import {getAuthorizationContext,AuthorizationError} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {activityAvailabilityInputSchema,activityAvailabilitySchema,type ActivityAvailability} from "./availability-schema";

/** Read-only current eligibility, not an authorization token. The eventual start
 * transaction must re-evaluate scope/availability atomically before creating state. */
export async function getActivityAvailability(input:unknown):Promise<ActivityAvailability>{
 try{
  const before=await getAuthorizationContext();
  const parsed=activityAvailabilityInputSchema.safeParse(input);
  if(!parsed.success)return {available:false,reasonCode:"INVALID_CONTEXT"};
  const v=parsed.data;const db=await createServerSupabaseClient();
  const result=await db.rpc("resolve_activity_availability",{target_definition:v.activityDefinitionId,target_project:v.projectId,target_workspace:v.workspaceId,target_team:v.teamId??null});
  if(result.error)return {available:false,reasonCode:"INVALID_CONTEXT"};
  const validated=activityAvailabilitySchema.safeParse(result.data);
  const current=await getAuthorizationContext();
  if(!validated.success||current.userId!==before.userId)return {available:false,reasonCode:"INVALID_CONTEXT"};
  return validated.data;
 }catch(error){
  return {available:false,reasonCode:error instanceof AuthorizationError&&error.code==="AUTH_REQUIRED"?"UNAUTHENTICATED":"INVALID_CONTEXT"};
 }
}
