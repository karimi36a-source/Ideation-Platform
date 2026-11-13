import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {affinityGroupSchema,type AffinityGroup} from "./schema";
import {createAffinityGroupSchema,renameAffinityGroupSchema} from "./operations-schema";
export class AffinityActivityStateError extends Error {readonly code="INVALID_STATE";constructor(){super("Activity is not editable.");}}
async function execute(input:unknown,rename:boolean):Promise<AffinityGroup>{
 try{
  const actor=await getAuthorizationContext();
  const parsed=(rename?renameAffinityGroupSchema:createAffinityGroupSchema).safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}="affinityGroupId" in parsed.data
   ?await db.rpc("rename_affinity_group",{input:parsed.data})
   :await db.rpc("create_affinity_group",{input:parsed.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){if(error.code==="55000")throw new AffinityActivityStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","22P02"].includes(error.code)?"VALIDATION_ERROR":"NOT_FOUND");}
  const row=affinityGroupSchema.safeParse(data);
  if(!row.success||row.data.name!==parsed.data.name||(!rename&&row.data.created_by!==actor.userId)
   ||("affinityGroupId" in parsed.data&&row.data.id!==parsed.data.affinityGroupId)
   ||("activityInstanceId" in parsed.data&&row.data.activity_instance_id!==parsed.data.activityInstanceId))throw new AuthorizationError("NOT_FOUND");
  return row.data;
 }catch(error){if(error instanceof AffinityActivityStateError)throw error;throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
}
export const createAffinityGroup=(input:unknown)=>execute(input,false);
export const renameAffinityGroup=(input:unknown)=>execute(input,true);
