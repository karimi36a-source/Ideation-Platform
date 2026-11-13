import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {VotingConfigurationError} from "./create";
import {votingResultsSchema,type VotingResults} from "./results-schema";
const idSchema=z.uuid().transform(value=>value.toLowerCase());
/** Aggregate-only read; the database owns identity, scope, visibility and snapshot. */
export async function getVotingResults(votingSessionId:unknown):Promise<VotingResults>{
 try{
  const actor=await getAuthorizationContext();const input=idSchema.safeParse(votingSessionId);
  if(!input.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response=await db.rpc("get_voting_results",{target_session:input.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error){
   if(response.error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
   if(response.error.code==="0A000")throw new VotingConfigurationError();
   throw new AuthorizationError(["22023","22P02"].includes(response.error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=votingResultsSchema.safeParse(response.data);
  if(!result.success||result.data.session.id!==input.data)throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof VotingConfigurationError)throw new VotingConfigurationError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
