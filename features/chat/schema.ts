import {z} from "zod";
export const chatChannelTypeSchema=z.enum(["TEAM","COHORT","MASTER_TEAM","ACTIVITY","OTHER"]);
export const chatChannelStatusSchema=z.enum(["active","archived"]);
export const chatAccessLevelSchema=z.enum(["read","read_write"]);
export const chatMessageTypeSchema=z.enum(["TEXT","FILE","LINK","SYSTEM"]);
const timestamp=z.iso.datetime({offset:true});
export const chatChannelSchema=z.object({
 id:z.uuid(),channel_type:chatChannelTypeSchema,workspace_id:z.uuid(),team_id:z.uuid().nullable(),cohort_id:z.uuid().nullable(),
 name:z.string().trim().min(1).max(200),status:chatChannelStatusSchema,created_at:timestamp,
}).refine(row=>row.channel_type!=="TEAM"||(row.team_id!==null&&row.cohort_id!==null));
export const chatMembershipSchema=z.object({
 id:z.uuid(),chat_channel_id:z.uuid(),user_id:z.uuid(),access_level:chatAccessLevelSchema,
 joined_at:timestamp,left_at:timestamp.nullable(),
}).refine(row=>row.left_at===null||Date.parse(row.left_at)>=Date.parse(row.joined_at));
export const chatMessageSchema=z.object({
 id:z.uuid(),chat_channel_id:z.uuid(),sender_user_id:z.uuid(),parent_message_id:z.uuid().nullable(),
 content:z.string(),message_type:chatMessageTypeSchema,created_at:timestamp,edited_at:timestamp.nullable(),deleted_at:timestamp.nullable(),
}).refine(row=>row.message_type!=="TEXT"||row.content.replace(/^ +| +$/g,"").length>0);
export type ChatChannel=z.infer<typeof chatChannelSchema>;
export type ChatMembership=z.infer<typeof chatMembershipSchema>;
export type ChatMessage=z.infer<typeof chatMessageSchema>;
