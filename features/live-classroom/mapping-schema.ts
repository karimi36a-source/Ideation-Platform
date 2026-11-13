import {z} from 'zod';
export const liveRoomMappingSchema=z.strictObject({
 id:z.uuid(),cohort_id:z.uuid(),session_definition_id:z.uuid(),provider:z.literal('DAILY'),
 provider_room_ref:z.string().regex(/^[A-Za-z0-9_-]{1,128}$/),status:z.enum(['ACTIVE','EXPIRED']),created_by:z.uuid(),
 created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true}),ended_at:z.iso.datetime({offset:true}).nullable(),
}).refine(r=>(r.status==='ACTIVE')===(r.ended_at===null));
export type LiveRoomMapping=z.infer<typeof liveRoomMappingSchema>;
