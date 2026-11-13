import {z} from 'zod';
// Transport is deliberately smaller than canonical retrieval. Never render events.
export const notificationEventSchema=z.strictObject({id:z.uuid(),read_at:z.iso.datetime({offset:true}).nullable()});
export const notificationSubscriptionSchema=z.strictObject({userId:z.uuid(),topic:z.string()})
 .refine(v=>v.topic==='notifications:'+v.userId);
export const notificationCursorSchema=z.strictObject({createdAt:z.iso.datetime({offset:true}),id:z.uuid()});
export const notificationItemSchema=z.strictObject({id:z.uuid(),notification_type:z.string().regex(/^[A-Z][A-Z0-9_]{0,63}$/),
 title:z.string().min(1).max(160),body:z.string().min(1).max(500),entity_type:z.string().nullable(),entity_id:z.uuid().nullable(),
 read_at:z.iso.datetime({offset:true}).nullable(),created_at:z.iso.datetime({offset:true})});
export const notificationReloadSchema=z.strictObject({userId:z.uuid(),page:z.strictObject({items:z.array(notificationItemSchema),nextCursor:notificationCursorSchema.nullable()})});
export type NotificationRealtimeItem=z.infer<typeof notificationItemSchema>;
export type NotificationSubscription=z.infer<typeof notificationSubscriptionSchema>;
export type NotificationCursor=z.infer<typeof notificationCursorSchema>;
