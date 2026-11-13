import {scheduleCommittedNotificationEmails} from './email-delivery';
import 'server-only';
import {createClient} from '@supabase/supabase-js';
import {z} from 'zod';
import type {Database} from '@/lib/db/database.types';
import {getServerEnv} from '@/lib/validation/env-server';
import {getNotificationTypeDefinition,notificationTypeSchema} from './type-registry';

const requestSchema=z.strictObject({
 notificationType:notificationTypeSchema,
 // A canonical membership audit, Share-created audit, submission, or outcome
 // audit ID. For Team fanout, a current exact destination/source membership
 // selects one recipient per call; never an arbitrary user ID.
 recipientContext:z.strictObject({sourceId:z.uuid(),teamMembershipId:z.uuid().optional()}),
 formatterInput:z.strictObject({}),
 entityReference:z.strictObject({entityType:z.enum(['team','share','submission']),entityId:z.uuid()}),
 idempotencyKey:z.string().regex(/^[A-Za-z0-9:_-]{1,160}$/).optional(),
});
export type CreateNotificationInput=z.infer<typeof requestSchema>;
export const notificationRecordSchema=z.object({id:z.uuid(),recipient_user_id:z.uuid(),notification_type:notificationTypeSchema,
 title:z.string().min(1).max(160),body:z.string().min(1).max(500),entity_type:z.enum(['team','share','submission']),entity_id:z.uuid(),
 read_at:z.iso.datetime({offset:true}).nullable(),created_at:z.iso.datetime({offset:true})});
export type NotificationRecord=z.infer<typeof notificationRecordSchema>;
export class NotificationCreationError extends Error{
 constructor(readonly code:'INVALID_NOTIFICATION'|'NOTIFICATION_CONFLICT'|'NOTIFICATION_UNAVAILABLE'){
  super('Notification creation unavailable');this.name='NotificationCreationError';
 }
}
/** Trusted domain/job entry point ONLY; never forward a client request here.
 * No route/action exports this service. Canonical records prove the domain
 * event and recipient; the privileged RPC remains inaccessible to clients.
 * Awaited RPC completion is the commit boundary. M15.7 delivers a private refresh
 * after commit. M5 calls this same database operation transactionally (M15.8).
 */
export async function createNotification(input:unknown):Promise<NotificationRecord>{
 const parsed=requestSchema.safeParse(input);
 if(!parsed.success)throw new NotificationCreationError('INVALID_NOTIFICATION');
 const r=parsed.data,definition=getNotificationTypeDefinition(r.notificationType);
 if(r.entityReference.entityType!==definition.targetEntityType&&!definition.targetEntityTypes?.some(type=>type===r.entityReference.entityType))throw new NotificationCreationError('INVALID_NOTIFICATION');
 const title=definition.titleFormatter(r.formatterInput),body=definition.bodyFormatter(r.formatterInput);
 try{
  const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw new Error('Unavailable');
  const db=createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:'error',cache:'no-store'})}});
  const result=await db.rpc('create_domain_notification',{input:{...r,title,body,recipientStrategy:definition.recipientResolution.strategy}});
  if(result.error)throw new NotificationCreationError(result.error.code==='23505'?'NOTIFICATION_CONFLICT':'NOTIFICATION_UNAVAILABLE');
  const row=notificationRecordSchema.parse(result.data);
  if(row.notification_type!==r.notificationType||row.entity_type!==r.entityReference.entityType||row.entity_id.toLowerCase()!==r.entityReference.entityId.toLowerCase()||row.title!==title||row.body!==body)throw new Error('Unavailable');
  await scheduleCommittedNotificationEmails({notificationId:row.id});
  return row;
 }catch(e){if(e instanceof NotificationCreationError)throw e;throw new NotificationCreationError('NOTIFICATION_UNAVAILABLE');}
}
