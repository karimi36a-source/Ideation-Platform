import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {MindMapConflictError,MindMapStateError} from "./create";
import {mindMapEdgeSchema,type MindMapEdge} from "./schema";
import {connectMindMapNodesSchema,updateMindMapEdgeSchema,removeMindMapEdgeSchema} from "./edge-schema";
async function mutate(input:unknown,operation:"connect"|"update"|"remove"):Promise<MindMapEdge>{
 try{
  const actor=await getAuthorizationContext();
  const schema=operation==="connect"?connectMindMapNodesSchema:operation==="update"?updateMindMapEdgeSchema:removeMindMapEdgeSchema;
  const parsed=schema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const result=operation==="connect"?await db.rpc("connect_mind_map_nodes",{input:connectMindMapNodesSchema.parse(parsed.data)}):operation==="update"?await db.rpc("update_mind_map_edge",{input:updateMindMapEdgeSchema.parse(parsed.data)}):await db.rpc("remove_mind_map_edge",{input:removeMindMapEdgeSchema.parse(parsed.data)});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(result.error){if(["23505","40001"].includes(result.error.code))throw new MindMapConflictError();if(result.error.code==="55000")throw new MindMapStateError();throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":result.error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");}
  const row=mindMapEdgeSchema.safeParse(result.data);if(!row.success)throw new AuthorizationError("NOT_FOUND");
  if(operation==="connect"){const c=connectMindMapNodesSchema.parse(parsed.data);if(row.data.mind_map_id!==c.mindMapId||row.data.source_node_id!==c.sourceNodeId||row.data.target_node_id!==c.targetNodeId||row.data.edge_type!==c.edgeType||row.data.edit_revision!==0)throw new AuthorizationError("NOT_FOUND");}
  else {const c=removeMindMapEdgeSchema.parse({edgeId:(parsed.data as {edgeId:string}).edgeId,expectedRevision:(parsed.data as {expectedRevision:number}).expectedRevision});if(row.data.id!==c.edgeId||!(operation==="remove"?[c.expectedRevision]:[c.expectedRevision,c.expectedRevision+1]).includes(row.data.edit_revision))throw new AuthorizationError("NOT_FOUND");}
  return row.data;
 }catch(error){if(error instanceof MindMapConflictError||error instanceof MindMapStateError)throw error;throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
}
export const connectMindMapNodes=(input:unknown)=>mutate(input,"connect");
export const updateMindMapEdge=(input:unknown)=>mutate(input,"update");
export const removeMindMapEdge=(input:unknown)=>mutate(input,"remove");
