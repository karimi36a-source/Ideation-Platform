import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {scamperEntrySchema} from "./schema";
import {createScamperEntrySchema,updateScamperEntrySchema} from "./operation-schema";
export class ScamperEntryStateError extends Error {readonly code="INVALID_STATE";constructor(){super("SCAMPER entry is not writable.");this.name="ScamperEntryStateError";}}
const fail=(code:string)=>{
 if(code==="28000")throw new AuthorizationError("AUTH_REQUIRED");
 if(code==="55000")throw new ScamperEntryStateError();
 if(["22023","22P02"].includes(code))throw new AuthorizationError("VALIDATION_ERROR");
 throw new AuthorizationError("NOT_FOUND");
};
async function execute(input:unknown,mode:"create"|"update"){
 try{
  const actor=await getAuthorizationContext();
  const parsed=(mode==="create"?createScamperEntrySchema:updateScamperEntrySchema).safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response="activityInstanceId" in v
   ?await db.rpc("create_scamper_entry",{target_instance:v.activityInstanceId,lens:v.scamperType,original_value:v.originalElement,proposed_value:v.proposedChange,result_value:v.resultText})
   :await db.rpc("update_scamper_entry",{target_entry:v.entryId,changes:Object.fromEntries(Object.entries(v).filter(([key,value])=>key!=="entryId"&&value!==undefined))});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error)fail(response.error.code);
  const result=scamperEntrySchema.safeParse(response.data);
  if(!result.success)throw new AuthorizationError("NOT_FOUND");
  const row=result.data;
  if(row.status!=="active"||row.archived_at!==null||row.updated_by!==actor.userId
   ||("activityInstanceId" in v?(row.activity_instance_id!==v.activityInstanceId||row.created_by!==actor.userId||row.idea_object_id!==null):row.id!==v.entryId)
   ||(v.scamperType!==undefined&&row.scamper_type!==v.scamperType)
   ||(v.originalElement!==undefined&&row.original_element!==v.originalElement)
   ||(v.proposedChange!==undefined&&row.proposed_change!==v.proposedChange)
   ||(v.resultText!==undefined&&row.result_text!==v.resultText))throw new AuthorizationError("NOT_FOUND");
  return row;
 }catch(error){
  if(error instanceof ScamperEntryStateError)throw new ScamperEntryStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
/** RPC resolves and locks canonical scope; no client-provided identity or table CRUD. */
export const createScamperEntry=(input:unknown)=>execute(input,"create");
export const updateScamperEntry=(input:unknown)=>execute(input,"update");
