import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {mindMapEditorSchema,type MindMapEditorState} from "./editor-schema";

export async function getMindMapEditor(activityInstanceId:unknown):Promise<MindMapEditorState>{
 try{
  const id=typeof activityInstanceId==="string"?activityInstanceId:"";const before=await getAuthorizationContext();
  const db=await createServerSupabaseClient();const {data,error}=await db.rpc("get_mind_map_editor",{target_activity:id});
  const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("NOT_FOUND");
  const parsed=mindMapEditorSchema.safeParse(data);
  if(error||!parsed.success)throw new AuthorizationError(error?.code==="28000"?"AUTH_REQUIRED":"NOT_FOUND");
  return parsed.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&error.code==="AUTH_REQUIRED"?"AUTH_REQUIRED":"NOT_FOUND");}
}
