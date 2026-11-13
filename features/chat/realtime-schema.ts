import {z} from "zod";
export const teamChatEventSchema=z.strictObject({chatChannelId:z.uuid(),messageId:z.uuid()});
export const teamChatSubscriptionSchema=z.strictObject({chatChannelId:z.uuid(),userId:z.uuid(),topic:z.string()}).refine(v=>v.topic===`team-chat:${v.chatChannelId}:${v.userId}`);
