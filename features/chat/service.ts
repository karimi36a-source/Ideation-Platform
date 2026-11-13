import "server-only";
import {z} from "zod";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getAuthorizationContext,AuthorizationError} from "@/lib/auth/authorization";
import {getTeamChatAccess} from "./access";
import {chatChannelSchema,chatMessageSchema} from "./schema";
import {sendTeamChatMessageSchema,listTeamChatMessagesSchema,chatCursorSchema} from "./message-schema";
function fail(error:unknown):never{
 throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");
}
/** RLS-filtered lookup, then the central capability resolver. No role-based bypass. */
export async function getTeamChatChannel(teamId:unknown){
 try{
  await getAuthorizationContext();const id=z.uuid().safeParse(teamId);if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();const r=await db.from("chat_channels").select("*").eq("team_id",id.data).eq("channel_type","TEAM").eq("status","active").maybeSingle();
  const channel=chatChannelSchema.safeParse(r.data);
  if(r.error||!channel.success||channel.data.team_id!==id.data||channel.data.channel_type!=="TEAM"||channel.data.status!=="active")throw new AuthorizationError("FORBIDDEN");
  await getTeamChatAccess(channel.data.id);return channel.data;
 }catch(error){fail(error);}
}
export async function sendTeamChatMessage(input:unknown){
 try{
  const before=await getAuthorizationContext();const parsed=sendTeamChatMessageSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const channel=await getTeamChatChannel(v.teamId);const access=await getTeamChatAccess(channel.id);if(!access.canPost)throw new AuthorizationError("FORBIDDEN");
  const db=await createServerSupabaseClient();const r=await db.rpc("send_team_chat_message",{target_team:v.teamId,message_content:v.content,reply_parent:v.parentMessageId??null});
  if(r.error)throw new AuthorizationError(r.error.code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","22P02"].includes(r.error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
  const message=chatMessageSchema.safeParse(r.data);const after=await getAuthorizationContext();
  if(!message.success||message.data.chat_channel_id!==channel.id||message.data.sender_user_id!==before.userId||after.userId!==before.userId||message.data.message_type!=="TEXT"||message.data.parent_message_id!==(v.parentMessageId??null))throw new AuthorizationError("FORBIDDEN");
  await getTeamChatAccess(channel.id);return message.data;
 }catch(error){fail(error);}
}
export async function listTeamChatMessages(input:unknown){
 try{
  const before=await getAuthorizationContext();const parsed=listTeamChatMessagesSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const channel=await getTeamChatChannel(v.teamId);
  const db=await createServerSupabaseClient();const r=await db.rpc("list_team_chat_messages",{target_channel:channel.id,page_limit:v.limit,after_time:v.cursor?.createdAt??null,after_id:v.cursor?.id??null});
  if(r.error)throw new AuthorizationError(r.error.code==="28000"?"AUTH_REQUIRED":r.error.code==="22023"?"VALIDATION_ERROR":"FORBIDDEN");
  const page=z.strictObject({items:z.array(chatMessageSchema),nextCursor:chatCursorSchema.nullable()}).safeParse(r.data);const after=await getAuthorizationContext();
  if(!page.success||after.userId!==before.userId||page.data.items.length>v.limit||page.data.items.some(m=>m.chat_channel_id!==channel.id))throw new AuthorizationError("FORBIDDEN");
  await getTeamChatAccess(channel.id);return page.data;
 }catch(error){fail(error);}
}
