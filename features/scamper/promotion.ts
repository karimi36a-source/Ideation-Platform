import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {developmentObjectSchema} from "@/features/projects/object-schema";
import {ScamperEntryStateError} from "./service";
export const promoteScamperEntrySchema=z.strictObject({entryId:z.uuid().transform(value=>value.toLowerCase())});
export class ScamperPromotionConflictError extends Error {readonly code="CONFLICT";constructor(){super("Promotion integrity conflict.");this.name="ScamperPromotionConflictError";}}
export async function promoteScamperEntryToIdea(input:unknown){
 try{
  const actor=await getAuthorizationContext();const parsed=promoteScamperEntrySchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}=await db.rpc("promote_scamper_entry_to_idea",{target_entry:parsed.data.entryId});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){if(error.code==="23505")throw new ScamperPromotionConflictError();if(error.code==="55000")throw new ScamperEntryStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":"NOT_FOUND");}
  const result=developmentObjectSchema.safeParse(data);
  if(!result.success||result.data.object_type!=="IDEA"||result.data.origin_type!=="SCAMPER"||result.data.origin_reference_id!==parsed.data.entryId)throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof ScamperPromotionConflictError)throw new ScamperPromotionConflictError();
  if(error instanceof ScamperEntryStateError)throw new ScamperEntryStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
