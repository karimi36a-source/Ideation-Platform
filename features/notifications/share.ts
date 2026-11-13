import 'server-only';
import {observeDatabase} from '@/lib/observability/structured-log';
import {withNotificationLog,recordNotificationFallback} from './diagnostics';
import {createClient} from '@supabase/supabase-js';
import {z} from 'zod';
import type {Database} from '@/lib/db/database.types';
import {getServerEnv} from '@/lib/validation/env-server';
import {createNotification} from './service';
const contexts=z.array(z.strictObject({sourceId:z.uuid(),teamMembershipId:z.uuid().optional()}));
/** Trusted post-commit hook only. A failed delivery never changes Share success.
 * Exact Share retries repair missing notices using immutable event/recipient IDs.
 * No route accepts client recipient lists; DB selectors recheck current access.
 */
export async function notifyArtifactShareCreated(shareId:string):Promise<void>{
 return withNotificationLog('NOTIFICATION_SHARE',shareId,async()=>{
 try{
  z.uuid().parse(shareId);
  const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw new Error('Unavailable');
  const db=createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:'error',cache:'no-store'})}});
  const result=await observeDatabase('artifact_share_notification_contexts',()=>db.rpc('artifact_share_notification_contexts',{target_share:shareId}));
  if(result.error)throw new Error('Unavailable');
  const recipients=contexts.parse(result.data);
  let failed=false;
  for(const recipientContext of recipients){
   try{await observeDatabase('create_domain_notification',()=>createNotification({notificationType:'ARTIFACT_SHARED',recipientContext,formatterInput:{},entityReference:{entityType:'share',entityId:shareId}}));}
   catch{failed=true;}
  }
  if(failed)throw new Error('Unavailable');
 }catch{
  // Allowlisted request context only; canonical state is already committed.
  recordNotificationFallback();
 }
 });
}
