import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {createVotingSessionSchema,createdVotingSessionSchema,type CreatedVotingSession} from "./create-schema";
export class VotingConfigurationError extends Error {readonly code="DEPENDENCY_NOT_MET";constructor(){super("Required Activity configuration is unavailable.");}}
export class VotingActivityStateError extends Error {readonly code="INVALID_STATE";constructor(){super("Activity is not writable.");}}
/** Each explicit call creates a new Session. No automatic retry or content deduplication. */
export async function createVotingSession(input:unknown):Promise<CreatedVotingSession>{
 try {
  const actor=await getAuthorizationContext();
  const parsed=createVotingSessionSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response=await db.rpc("create_voting_session",{target_instance:v.activityInstanceId,kind:v.votingType,dot_limit:v.voteLimit,is_anonymous:v.anonymous,visibility:v.revealMode,choices:v.options});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error){
   if(response.error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
   if(response.error.code==="0A000")throw new VotingConfigurationError();
   if(response.error.code==="55000")throw new VotingActivityStateError();
   throw new AuthorizationError(["22023","22P02","23505"].includes(response.error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=createdVotingSessionSchema.safeParse(response.data);
  if(!result.success)throw new AuthorizationError("NOT_FOUND");
  const {session,options}=result.data;
  if(session.activity_instance_id!==v.activityInstanceId||session.created_by!==actor.userId||session.status!=="DRAFT"||session.opened_at!==null||session.closed_at!==null
   ||session.voting_type!==v.votingType||session.vote_limit!==v.voteLimit||session.anonymous!==v.anonymous||session.reveal_mode!==v.revealMode||options.length!==v.options.length
   ||new Set(options.map(o=>o.id)).size!==options.length||options.some((o,i)=>o.voting_session_id!==session.id||o.sequence!==i+1||o.development_object_id!==(v.options[i].developmentObjectId??null)||o.label!==v.options[i].label||o.description!==(v.options[i].description??null)))throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof VotingConfigurationError)throw new VotingConfigurationError();
  if(error instanceof VotingActivityStateError)throw new VotingActivityStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
