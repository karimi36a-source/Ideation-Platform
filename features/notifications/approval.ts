import 'server-only';
import {observeDatabase} from '@/lib/observability/structured-log';
import {withNotificationLog,recordNotificationFallback} from './diagnostics';
import {createClient} from '@supabase/supabase-js';
import {z} from 'zod';
import type {Database} from '@/lib/db/database.types';
import {getServerEnv} from '@/lib/validation/env-server';
import {createNotification} from './service';
const contexts=z.array(z.strictObject({recipientContext:z.strictObject({sourceId:z.uuid(),teamMembershipId:z.uuid().optional()}),idempotencyKey:z.string().regex(/^artifact-approved:[0-9a-f-]{36}:[0-9a-f-]{36}$/)}));
/** Canonical notices already commit atomically inside the approval database transaction.
 * This post-commit hook reuses their exact retry identities and schedules email only after commit.
 * A failed post-commit retry/email never changes the committed approval or its canonical notices.
 * Exact retries reuse immutable event/recipient IDs without duplicating canonical notices.
 * No route accepts client recipient lists; DB selectors recheck current access.
 */
export async function notifyArtifactApproved(submissionId:string):Promise<void>{
 return withNotificationLog('NOTIFICATION_APPROVAL',submissionId,async()=>{
 try{
  submissionId=z.uuid().parse(submissionId).toLowerCase();
  const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw new Error('Unavailable');
  const db=createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:'error',cache:'no-store'})}});
  const result=await observeDatabase('approval_notification_contexts',()=>db.rpc('approval_notification_contexts',{target_submission:submissionId}));
  if(result.error)throw new Error('Unavailable');
  const recipients=contexts.parse(result.data);
  let failed=false;
  for(const {recipientContext,idempotencyKey} of recipients){
   try{await observeDatabase('create_domain_notification',()=>createNotification({notificationType:'ARTIFACT_APPROVED',recipientContext,formatterInput:{},entityReference:{entityType:'submission',entityId:submissionId},idempotencyKey}));}
   catch{failed=true;}
  }
  if(failed)throw new Error('Unavailable');
 }catch{
  // Allowlisted request context only; canonical state is already committed.
  recordNotificationFallback();
 }
 });
}
