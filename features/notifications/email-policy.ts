import 'server-only';
import {z} from 'zod';
import {requireActivePlatformUser} from '@/features/users/service';
import {createServerSupabaseClient} from '@/lib/db/server';
import {createEmailEligibilityPolicy,type EmailPolicyOverrides} from './email-policy-config';
import {notificationTypeSchema,type NotificationType} from './type-registry';

const requestSchema=z.strictObject({notificationId:z.uuid()});
const storedSchema=z.object({id:z.uuid(),recipient_user_id:z.uuid(),notification_type:z.string().max(64)});
export type NotificationEmailEligibility=Readonly<{eligible:false}>|Readonly<{
 eligible:true;notificationId:string;notificationType:NotificationType;recipientUserId:string;recipientEmail:string;
}>;
export class NotificationEmailPolicyError extends Error{
 constructor(readonly code:'INVALID_INPUT'|'UNAVAILABLE'){super('Notification email eligibility unavailable');this.name='NotificationEmailPolicyError';}
}
/** Read-only server seam for existing canonical notifications. The current
 * recipient's own RLS-scoped notification and active account establish identity.
 * No route/action exports this function, and no email address/configuration is
 * accepted in input. M15.16 owns future async dispatch; this never sends, queues,
 * expands audiences, resolves source entities, or modifies canonical state. */
export function createNotificationEmailPolicy(overrides:EmailPolicyOverrides={}){
 const policy=createEmailEligibilityPolicy(overrides);
 return Object.freeze({isEligible:policy.isEligible,async evaluate(input:unknown):Promise<NotificationEmailEligibility>{
  const parsed=requestSchema.safeParse(input);if(!parsed.success)throw new NotificationEmailPolicyError('INVALID_INPUT');
  try{
   const recipient=await requireActivePlatformUser(),db=await createServerSupabaseClient();
   const result=await db.from('notifications').select('id,recipient_user_id,notification_type')
    .eq('id',parsed.data.notificationId).eq('recipient_user_id',recipient.id).maybeSingle();
   const row=storedSchema.safeParse(result.data);
   if(result.error||!row.success||row.data.id.toLowerCase()!==parsed.data.notificationId.toLowerCase()||row.data.recipient_user_id!==recipient.id)throw new Error('Unavailable');
   if(!policy.isEligible(row.data.notification_type))return Object.freeze({eligible:false});
   const account=await requireActivePlatformUser(),email=z.email().max(254).safeParse(account.email);
   if(account.id!==row.data.recipient_user_id||!email.success)throw new Error('Unavailable');
   return Object.freeze({eligible:true,notificationId:row.data.id,notificationType:notificationTypeSchema.parse(row.data.notification_type),recipientUserId:account.id,recipientEmail:email.data});
  }catch{throw new NotificationEmailPolicyError('UNAVAILABLE');}
 }});
}
export const pilotNotificationEmailPolicy=createNotificationEmailPolicy();
