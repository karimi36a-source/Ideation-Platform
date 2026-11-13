import 'server-only';
import {observeDatabase} from '@/lib/observability/structured-log';
import {withNotificationLog,recordNotificationFallback} from './diagnostics';
import {z} from 'zod';
import {createNotification} from './service';
/** Trusted canonical Submission hook, called only after the M8 RPC commits.
 * M15.3 derives and rechecks the exact current assigned reviewer in PostgreSQL.
 * Delivery failure cannot undo the Submission; stable retries repair delivery.
 */
export async function notifySubmissionReceived(submissionId:string):Promise<void>{
 return withNotificationLog('NOTIFICATION_SUBMISSION',submissionId,async()=>{
 try{
  const id=z.uuid().parse(submissionId).toLowerCase();
  await observeDatabase('create_domain_notification',()=>createNotification({notificationType:'SUBMISSION_RECEIVED',recipientContext:{sourceId:id},formatterInput:{},
   entityReference:{entityType:'submission',entityId:id},idempotencyKey:'submission-received:'+id}));
 }catch{
  // No recipient/source/provider diagnostics or credentials in operator logs.
  recordNotificationFallback();
 }
 });
}
