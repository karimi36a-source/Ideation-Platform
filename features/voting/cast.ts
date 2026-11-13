import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {voteSchema,type Vote} from "./schema";
import {VotingConfigurationError,VotingActivityStateError} from "./create";
const id=z.uuid().transform(value=>value.toLowerCase());
export const castVoteInputSchema=z.strictObject({votingSessionId:id,votingOptionId:id,value:z.literal(1)});
export class VoteConflictError extends Error {readonly code="CONFLICT";constructor(){super("Vote conflict.");this.name="VoteConflictError";}}
export async function castVote(input:unknown):Promise<Vote>{
 try{
  const actor=await getAuthorizationContext();
  const parsed=castVoteInputSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}=await db.rpc("cast_vote",{target_session:parsed.data.votingSessionId,target_option:parsed.data.votingOptionId,dot_value:parsed.data.value});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){
   if(error.code==="23505")throw new VoteConflictError();
   if(error.code==="0A000")throw new VotingConfigurationError();
   if(error.code==="55000")throw new VotingActivityStateError();
   throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","22P02"].includes(error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=voteSchema.safeParse(data);
  if(!result.success||result.data.user_id!==actor.userId||result.data.voting_session_id!==parsed.data.votingSessionId||result.data.voting_option_id!==parsed.data.votingOptionId||result.data.value!==1||result.data.revealed_at!==null)throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof VoteConflictError)throw new VoteConflictError();
  if(error instanceof VotingConfigurationError)throw new VotingConfigurationError();
  if(error instanceof VotingActivityStateError)throw new VotingActivityStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
