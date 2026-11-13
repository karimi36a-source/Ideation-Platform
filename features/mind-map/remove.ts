import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {MindMapConflictError,MindMapStateError} from "./create";
import {mindMapNodeSchema,type MindMapNode} from "./schema";
import {removeMindMapNodeSchema} from "./node-schema";
export async function removeMindMapNode(input:unknown):Promise<MindMapNode>{
 try{
  const actor=await getAuthorizationContext();
  const parsed=removeMindMapNodeSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}=await db.rpc("remove_mind_map_node",{input:parsed.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){if(["40001","23505"].includes(error.code))throw new MindMapConflictError();if(error.code==="55000")throw new MindMapStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");}
  const row=mindMapNodeSchema.safeParse(data);
  if(!row.success||row.data.id!==parsed.data.nodeId||row.data.edit_revision!==parsed.data.expectedRevision||row.data.node_type==="CENTRAL_INVENTION")throw new AuthorizationError("NOT_FOUND");
  return row.data;
 }catch(error){if(error instanceof MindMapConflictError||error instanceof MindMapStateError)throw error;throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
}
