import "server-only";
import {z} from "zod";
import {getAuthorizationContext,AuthorizationError} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
/** Capabilities only. No send/read message operations or automatic role access. */
export async function getTeamChatAccess(channelId:unknown){
 const id=z.uuid().safeParse(channelId);if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");
 try{
  const before=await getAuthorizationContext();const db=await createServerSupabaseClient();
  const load=async()=>{const r=await db.rpc("get_team_chat_access",{target_channel:id.data});const level=z.enum(["read","read_write"]).safeParse(r.data);if(r.error||!level.success)throw new AuthorizationError("FORBIDDEN");return level.data;};
  await load();const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  const level=await load();return Object.freeze({canView:true,canPost:level==="read_write"});
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&error.code==="AUTH_REQUIRED"?"AUTH_REQUIRED":"FORBIDDEN");}
}
