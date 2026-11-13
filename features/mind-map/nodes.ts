import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {MindMapConflictError,MindMapStateError} from "./create";
import {mindMapNodeSchema,type MindMapNode} from "./schema";
import {addMindMapNodeSchema,updateMindMapNodeSchema} from "./node-schema";
async function mutate(input:unknown,update:boolean):Promise<MindMapNode>{
 try{
  const actor=await getAuthorizationContext();
  const parsed=(update?updateMindMapNodeSchema:addMindMapNodeSchema).safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const result=update
   ?await db.rpc("update_mind_map_node",{input:updateMindMapNodeSchema.parse(parsed.data)})
   :await db.rpc("add_mind_map_node",{input:addMindMapNodeSchema.parse(parsed.data)});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(result.error){
   if(["40001","23505"].includes(result.error.code))throw new MindMapConflictError();
   if(result.error.code==="55000")throw new MindMapStateError();
   throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":result.error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const row=mindMapNodeSchema.safeParse(result.data);
  if(!row.success)throw new AuthorizationError("NOT_FOUND");
  if(update){const change=updateMindMapNodeSchema.parse(parsed.data);if(row.data.id!==change.nodeId||![change.expectedRevision,change.expectedRevision+1].includes(row.data.edit_revision))throw new AuthorizationError("NOT_FOUND");}
  else {const add=addMindMapNodeSchema.parse(parsed.data);if(row.data.mind_map_id!==add.mindMapId||row.data.node_type!==add.nodeType||row.data.created_by!==actor.userId||row.data.edit_revision!==0)throw new AuthorizationError("NOT_FOUND");}
  return row.data;
 }catch(error){
  if(error instanceof MindMapConflictError||error instanceof MindMapStateError)throw error;
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
export const addMindMapNode=(input:unknown)=>mutate(input,false);
export const updateMindMapNode=(input:unknown)=>mutate(input,true);
