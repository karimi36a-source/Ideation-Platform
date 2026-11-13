import {z} from "zod";
export const chatCursorSchema=z.strictObject({createdAt:z.iso.datetime({offset:true}),id:z.uuid()});
export const sendTeamChatMessageSchema=z.strictObject({teamId:z.uuid(),content:z.string().trim().min(1),parentMessageId:z.uuid().optional()});
export const listTeamChatMessagesSchema=z.strictObject({teamId:z.uuid(),limit:z.number().int().min(1).max(100).default(50),cursor:chatCursorSchema.optional()});
