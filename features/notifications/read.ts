import 'server-only';
import {z} from 'zod';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
const idSchema=z.uuid().transform(v=>v.toLowerCase());
const resultSchema=z.strictObject({id:z.uuid(),read_at:z.iso.datetime({offset:true})});
export type NotificationReadState=Readonly<z.infer<typeof resultSchema>>;
/** No client actor/timestamp or arbitrary patch. The normal authenticated RPC
 * owns the timestamp and recipient check; source entity access is unrelated.
 */
export async function markNotificationRead(notificationId:unknown):Promise<NotificationReadState>{
 try{
  const actor=await getAuthorizationContext(),parsed=idSchema.safeParse(notificationId);
  if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
  const result=await db.rpc('mark_notification_read',{target_notification:parsed.data});
  if(result.error)throw new AuthorizationError(result.error.code==='28000'?'AUTH_REQUIRED':result.error.code==='22023'||result.error.code==='22P02'?'VALIDATION_ERROR':'NOT_FOUND');
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
  const row=resultSchema.parse(result.data);
  if(row.id.toLowerCase()!==parsed.data)throw new AuthorizationError('NOT_FOUND');
  return row;
 }catch(e){throw new AuthorizationError(e instanceof AuthorizationError?e.code:'NOT_FOUND');}
}
