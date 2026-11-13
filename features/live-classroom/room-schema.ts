import {z} from 'zod';
export const liveSessionRoomInputSchema=z.strictObject({cohortId:z.uuid(),sessionDefinitionId:z.uuid(),activityInstanceId:z.uuid().optional()});
export const masterLiveRoomContextSchema=z.strictObject({actorId:z.uuid(),cohortId:z.uuid(),sessionDefinitionId:z.uuid(),roomKey:z.string().regex(/^fici-[a-f0-9]{64}$/)});
export const liveSessionRoomSchema=z.strictObject({id:z.uuid(),provider:z.literal('DAILY'),providerRoomRef:z.string().regex(/^[A-Za-z0-9_-]{1,128}$/),status:z.literal('ACTIVE'),cohortId:z.uuid(),sessionDefinitionId:z.uuid()});
export type LiveSessionRoomInput=z.infer<typeof liveSessionRoomInputSchema>;
