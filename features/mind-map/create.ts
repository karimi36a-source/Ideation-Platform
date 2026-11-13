import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {createMindMapSchema,createdMindMapSchema,type CreatedMindMap} from "./create-schema";
export class MindMapConflictError extends Error {readonly code="CONFLICT";constructor(){super("Mind Map initialization conflict.");}}
export class MindMapStateError extends Error {readonly code="DEPENDENCY_NOT_READY";constructor(){super("Mind Map initialization unavailable.");}}
export async function createMindMap(input:unknown):Promise<CreatedMindMap>{
 try{
  const actor=await getAuthorizationContext();
  const parsed=createMindMapSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}=await db.rpc("create_mind_map",{input:parsed.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){
   if(["23505","40001"].includes(error.code))throw new MindMapConflictError();
   if(error.code==="55000")throw new MindMapStateError();
   throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=createdMindMapSchema.safeParse(data);
  if(!result.success)throw new AuthorizationError("NOT_FOUND");
  const {artifact,version,mindMap,rootNode,replayed}=result.data;
  if(artifact.artifact_type!=="MIND_MAP"||artifact.activity_instance_id!==parsed.data.activityInstanceId
   ||artifact.status!=="ACTIVE"||artifact.archived_at!==null||version.artifact_id!==artifact.id
   ||mindMap.artifact_id!==artifact.id||mindMap.artifact_version_id!==version.id||mindMap.root_node_id!==rootNode.id
   ||rootNode.mind_map_id!==mindMap.id||rootNode.node_type!=="CENTRAL_INVENTION"||rootNode.development_object_id!==null||rootNode.parent_node_id!==null
   ||(!replayed&&(rootNode.created_by!==actor.userId||version.created_by!==actor.userId||artifact.created_by!==actor.userId||version.status!=="DRAFT"||version.version_number!==1||artifact.current_version_id!==null)))throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof MindMapConflictError||error instanceof MindMapStateError)throw error;
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
