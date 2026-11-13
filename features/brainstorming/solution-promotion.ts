import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {developmentObjectSchema} from "@/features/projects/object-schema";
import {BrainstormActivityStateError} from "./service";
export const promoteBrainstormEntryToSolutionSchema=z.strictObject({entryId:z.uuid().transform(value=>value.toLowerCase()),problemId:z.uuid().transform(value=>value.toLowerCase())});
import {BrainstormPromotionConflictError} from "./promotion";
export async function promoteBrainstormEntryToSolution(input:unknown){
 try{
  const actor=await getAuthorizationContext();const parsed=promoteBrainstormEntryToSolutionSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}=await db.rpc("promote_brainstorm_entry_to_solution",{target_entry:parsed.data.entryId,target_problem:parsed.data.problemId});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){if(error.code==="23505")throw new BrainstormPromotionConflictError();if(error.code==="55000")throw new BrainstormActivityStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":"NOT_FOUND");}
  const result=developmentObjectSchema.safeParse(data);
  if(!result.success||result.data.object_type!=="SOLUTION"||result.data.origin_type!=="BRAINSTORM"||result.data.origin_reference_id!==parsed.data.entryId)throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof BrainstormPromotionConflictError)throw new BrainstormPromotionConflictError();
  if(error instanceof BrainstormActivityStateError)throw new BrainstormActivityStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
