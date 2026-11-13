import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {MindMapConflictError,MindMapStateError} from "./create";
import {mindMapNodeSchema,type MindMapNode} from "./schema";
import {classifyMindMapNodeSchema} from "./classification-schema";
export async function classifyMindMapNode(raw:unknown):Promise<MindMapNode>{try{
 const actor=await getAuthorizationContext();const parsed=classifyMindMapNodeSchema.safeParse(raw);
 if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const {data,error}=await db.rpc("classify_mind_map_node",{input:parsed.data});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(error){if(["40001","23505"].includes(error.code))throw new MindMapConflictError();if(error.code==="55000")throw new MindMapStateError();throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");}
 const result=mindMapNodeSchema.safeParse(data);
 if(!result.success||result.data.id!==parsed.data.nodeId||result.data.product_classification!==parsed.data.classification||![parsed.data.expectedRevision,parsed.data.expectedRevision+1].includes(result.data.edit_revision))throw new AuthorizationError("NOT_FOUND");
 return result.data;
}catch(error){if(error instanceof MindMapConflictError||error instanceof MindMapStateError)throw error;
 throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
