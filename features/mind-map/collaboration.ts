import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {authorizePrivateToolRoom} from "@/lib/collaboration/liveblocks-server";
import {getMindMapEditor} from "./editor-service";
import {collaborationRequestSchema,mindMapRoomId} from "./collaboration-schema";
export class MindMapProviderUnavailableError extends Error{
 readonly code="DEPENDENCY_NOT_READY";
 constructor(){super("Collaboration provider unavailable.");}
}
export function createMindMapRoomAuthorizer(provider:typeof authorizePrivateToolRoom){
 return async(raw:unknown)=>{
  const actor=await getAuthorizationContext();const parsed=collaborationRequestSchema.safeParse(raw);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const before=await getMindMapEditor(parsed.data.activityInstanceId);
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  let grant:Awaited<ReturnType<typeof provider>>;
  try{grant=await provider({userId:actor.userId,roomId:mindMapRoomId(before.mindMap.id),writable:before.editable});}
  catch{throw new MindMapProviderUnavailableError();}
  const after=await getMindMapEditor(parsed.data.activityInstanceId);
  if(after.mindMap.id!==before.mindMap.id||after.editable!==before.editable||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  return grant;
 };
}
export const authorizeMindMapCollaboration=createMindMapRoomAuthorizer(authorizePrivateToolRoom);
