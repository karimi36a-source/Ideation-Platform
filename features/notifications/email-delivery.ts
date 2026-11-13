import 'server-only';
import {after} from 'next/server';
import {createClient} from '@supabase/supabase-js';
import {z} from 'zod';
import type {Database} from '@/lib/db/database.types';
import {getServerEnv} from '@/lib/validation/env-server';
import {createEmailProvider} from '@/features/email/factory';
import type {EmailProvider} from '@/features/email/provider';
import {createEmailEligibilityPolicy} from './email-policy-config';
import {notificationEmailTemplate} from './email-template';

const selectorSchema=z.union([
 z.strictObject({notificationId:z.uuid()}),
 z.strictObject({membershipId:z.uuid(),membershipType:z.enum(['MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED'])}),
]);
export type NotificationEmailSelector=z.infer<typeof selectorSchema>;
const contextsSchema=z.array(z.strictObject({notificationId:z.uuid(),notificationType:z.string().max(64),recipientUserId:z.uuid(),recipientEmail:z.email().max(254),accountStatus:z.literal('active')}));
const outcomes=['INVALID_INPUT','CONFIGURATION','AUTHENTICATION','RATE_LIMIT','TIMEOUT','NETWORK','UNAVAILABLE','REJECTED','CONFLICT','MALFORMED_RESPONSE','UNKNOWN'] as const;
type DeliveryLog=Readonly<{notificationId?:string;outcome:typeof outcomes[number]|'ACCEPTED'|'CONTEXT_UNAVAILABLE'|'SCHEDULING_UNAVAILABLE';messageId?:string}>;
type DeliveryPorts=Readonly<{read:(selector:NotificationEmailSelector)=>Promise<unknown>;provider:()=>EmailProvider;schedule:(work:()=>Promise<void>)=>void;log:(event:DeliveryLog)=>void}>;
const policy=createEmailEligibilityPolicy();
async function readCommitted(selector:NotificationEmailSelector):Promise<unknown>{
 const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw new Error('Unavailable');
 const db=createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:'error',cache:'no-store'})}});
 const result=await db.rpc('notification_email_contexts',{input:selector});if(result.error)throw new Error('Unavailable');return result.data;
}
/** Trusted server composition/testing seam only, never a Server Action or route.
 * after() extends the request lifecycle, not durability. If the runtime dies
 * before the callback completes, email may be lost. Canonical in-app records
 * remain recovery/source-of-truth. No automatic retries or exactly-once claim. */
export function createNotificationEmailDelivery(ports:DeliveryPorts){
 const log=(event:DeliveryLog)=>{try{ports.log(Object.freeze(event));}catch{/* Observability cannot alter canonical state. */}};
 const read=async(selector:NotificationEmailSelector)=>{
  const rows=contextsSchema.parse(await ports.read(selector));
  if('notificationId' in selector&&rows.some(r=>r.notificationId.toLowerCase()!==selector.notificationId.toLowerCase()))throw new Error('Unavailable');
  return rows;
 };
 const dispatch=async(notificationId:string):Promise<void>=>{
  try{
   for(const row of await read({notificationId})){
    if(!policy.isEligible(row.notificationType))continue;
    const result=await ports.provider().send({to:row.recipientEmail,template:'FICI_NOTIFICATION',variables:{notificationType:row.notificationType},idempotencyKey:'notification-email:'+row.notificationId.toLowerCase()+':'+row.recipientUserId.toLowerCase()});
    if(result.success){const id=z.uuid().safeParse(result.messageId);log({notificationId,outcome:id.success?'ACCEPTED':'MALFORMED_RESPONSE',...(id.success?{messageId:id.data}:{})});}
    else{const code=z.enum(outcomes).safeParse(result.error?.code);log({notificationId,outcome:code.success?code.data:'UNKNOWN'});}
   }
  }catch{log({notificationId,outcome:'UNAVAILABLE'});}
 };
 return Object.freeze({async schedule(input:unknown):Promise<void>{
  const parsed=selectorSchema.safeParse(input);if(!parsed.success){log({outcome:'INVALID_INPUT'});return;}
  const notificationId='notificationId' in parsed.data?parsed.data.notificationId:undefined;
  try{
   // A separate read observes only committed notifications. Disabled records do
   // not register background work. Capture IDs only, not account/content data.
   const ids=[...new Set((await read(parsed.data)).filter(r=>policy.isEligible(r.notificationType)).map(r=>r.notificationId))];
   if(ids.length===0)return;
   try{ports.schedule(async()=>{for(const id of ids)await dispatch(id);});}
   catch{log({notificationId,outcome:'SCHEDULING_UNAVAILABLE'});}
  }catch{log({notificationId,outcome:'CONTEXT_UNAVAILABLE'});}
 }});
}
const delivery=createNotificationEmailDelivery({read:readCommitted,provider:()=>createEmailProvider([notificationEmailTemplate]),schedule:work=>after(work),log:event=>console.info('Notification email outcome',event)});
export const scheduleCommittedNotificationEmails=delivery.schedule;
