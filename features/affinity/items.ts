import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {affinityGroupItemSchema,type AffinityGroupItem} from "./schema";
import {addAffinityItemSchema,moveAffinityItemSchema} from "./item-operations-schema";
import {AffinityActivityStateError} from "./service";
export class AffinityItemConflictError extends Error{readonly code="CONFLICT";constructor(){super("Affinity item conflict.");}}
async function execute(input:unknown,move:boolean):Promise<AffinityGroupItem>{
 try{
  const actor=await getAuthorizationContext();const parsed=(move?moveAffinityItemSchema:addAffinityItemSchema).safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}="itemId" in parsed.data?await db.rpc("move_affinity_item",{input:parsed.data}):await db.rpc("add_affinity_item",{input:parsed.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){if(["23505","40001"].includes(error.code))throw new AffinityItemConflictError();if(error.code==="55000")throw new AffinityActivityStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","22P02","22003"].includes(error.code)?"VALIDATION_ERROR":"NOT_FOUND");}
  const row=affinityGroupItemSchema.safeParse(data);
  if(!row.success)throw new AuthorizationError("NOT_FOUND");
  if("itemId" in parsed.data){if(row.data.id!==parsed.data.itemId||row.data.affinity_group_id!==parsed.data.targetGroupId||row.data.position!==parsed.data.position||![parsed.data.expectedRevision,parsed.data.expectedRevision+1].includes(row.data.move_revision))throw new AuthorizationError("NOT_FOUND");}
  else if(row.data.added_by!==actor.userId||row.data.affinity_group_id!==parsed.data.affinityGroupId||row.data.development_object_id!==(parsed.data.developmentObjectId??null)||row.data.brainstorm_entry_id!==(parsed.data.brainstormEntryId??null)||(parsed.data.position!==undefined&&row.data.position!==parsed.data.position))throw new AuthorizationError("NOT_FOUND");
  return row.data;
 }catch(error){if(error instanceof AffinityItemConflictError||error instanceof AffinityActivityStateError)throw error;throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
}
export const addAffinityItem=(input:unknown)=>execute(input,false);
export const moveItemToAffinityGroup=(input:unknown)=>execute(input,true);
