"use server";
import {AuthorizationError} from "@/lib/auth/authorization";
import {MindMapConflictError,MindMapStateError} from "./create";
import {editorOperationSchema,type MindMapEditorResult} from "./editor-schema";
import {getMindMapEditor} from "./editor-service";
import {addMindMapNode,updateMindMapNode} from "./nodes";
import {removeMindMapNode} from "./remove";
import {connectMindMapNodes,removeMindMapEdge,updateMindMapEdge} from "./edges";

import {classifyMindMapNode} from "./classification";

const operations={classifyNode:classifyMindMapNode,addNode:addMindMapNode,updateNode:updateMindMapNode,removeNode:removeMindMapNode,connectEdge:connectMindMapNodes,updateEdge:updateMindMapEdge,removeEdge:removeMindMapEdge} as const;
export async function reloadMindMapEditor(activityInstanceId:unknown):Promise<MindMapEditorResult>{
 try{return {ok:true,data:await getMindMapEditor(activityInstanceId)};}
 catch{return {ok:false,error:{code:"NOT_FOUND",message:"The map is unavailable."}};}
}
function isBoundToActivityMap(operation:typeof editorOperationSchema._output,editor:Awaited<ReturnType<typeof getMindMapEditor>>):boolean{
 const input=operation.input as Record<string,unknown>;
 switch(operation.operation){
  case "addNode":case "connectEdge":return input["mindMapId"]===editor.mindMap.id;
  case "classifyNode":case "updateNode":case "removeNode":return editor.nodes.some(node=>node.id===input["nodeId"]);
  case "updateEdge":case "removeEdge":return editor.edges.some(edge=>edge.id===input["edgeId"]);
 }
}
export async function mutateMindMapEditor(raw:unknown):Promise<MindMapEditorResult>{
 const parsed=editorOperationSchema.safeParse(raw);
 if(!parsed.success)return {ok:false,error:{code:"VALIDATION_ERROR",message:"Check the requested change and try again."}};
 try{
  const editor=await getMindMapEditor(parsed.data.activityInstanceId);
  if(!isBoundToActivityMap(parsed.data,editor))throw new AuthorizationError("NOT_FOUND");
  await operations[parsed.data.operation](parsed.data.input as never);
  return {ok:true,data:await getMindMapEditor(parsed.data.activityInstanceId)};
 }catch(error){
  const code=error instanceof MindMapConflictError?"CONFLICT":error instanceof MindMapStateError?"DEPENDENCY_NOT_READY":error instanceof AuthorizationError?error.code:"NOT_FOUND";
  const message=code==="CONFLICT"?"This map changed elsewhere. The latest saved state has been loaded.":code==="VALIDATION_ERROR"?"That change is not valid for this map.":code==="DEPENDENCY_NOT_READY"?"This map is currently read-only.":"The map is unavailable.";
  try{return {ok:false,error:{code,message},...(code==="CONFLICT"?{data:await getMindMapEditor(parsed.data.activityInstanceId)}:{})} as MindMapEditorResult;}catch{return {ok:false,error:{code,message}};}
 }
}
