import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {votingSessionSchema,type VotingSession} from "./schema";
import {VotingConfigurationError} from "./create";
export class VotingCloseConflictError extends Error {readonly code="CONFLICT";constructor(){super("Voting Session cannot be closed.");this.name="VotingCloseConflictError";}}
const sessionIdSchema=z.uuid().transform(value=>value.toLowerCase());
/** Canonical identity-only transition. PostgreSQL serializes and validates every retry. */
export async function closeVotingSession(votingSessionId:unknown):Promise<VotingSession>{
 try {
  const actor=await getAuthorizationContext();
  const parsed=sessionIdSchema.safeParse(votingSessionId);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response=await db.rpc("close_voting_session",{target_session:parsed.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error){
   if(response.error.code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
   if(response.error.code==="0A000")throw new VotingConfigurationError();
   if(response.error.code==="55000")throw new VotingCloseConflictError();
   throw new AuthorizationError(["22023","22P02"].includes(response.error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=votingSessionSchema.safeParse(response.data);
  if(!result.success||result.data.id!==parsed.data||result.data.status!=="CLOSED"||result.data.opened_at===null||result.data.closed_at===null||result.data.voting_type!=="DOT_VOTE")throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof VotingConfigurationError)throw new VotingConfigurationError();
  if(error instanceof VotingCloseConflictError)throw new VotingCloseConflictError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
