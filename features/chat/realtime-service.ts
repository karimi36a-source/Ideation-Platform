import "server-only";
import {getAuthorizationContext,AuthorizationError} from "@/lib/auth/authorization";
import {getTeamChatChannel} from "./service";
import {getTeamChatAccess} from "./access";
/** Claims supplied by browser never determine the subscription identity/topic. */
export async function getTeamChatSubscription(teamId:unknown){
 const before=await getAuthorizationContext();const channel=await getTeamChatChannel(teamId);
 await getTeamChatAccess(channel.id);const after=await getAuthorizationContext();
 if(before.userId!==after.userId)throw new AuthorizationError("FORBIDDEN");
 return {chatChannelId:channel.id,userId:after.userId,topic:`team-chat:${channel.id}:${after.userId}`};
}
