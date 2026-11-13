import {z} from "zod";
export const collaborationRequestSchema=z.strictObject({activityInstanceId:z.uuid()});
export const movementSchema=z.strictObject({type:z.literal("mind-map-move"),nodeId:z.uuid(),revision:z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER),x:z.number().finite(),y:z.number().finite()});
export const collaborationEventSchema=z.union([movementSchema,z.strictObject({type:z.literal("mind-map-reload")})]);
export type MindMapCollaborationEvent=z.infer<typeof collaborationEventSchema>;
export const mindMapRoomId=(id:string)=>`mind-map:${z.uuid().parse(id).toLowerCase()}`;
