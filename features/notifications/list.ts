import 'server-only';
import {z} from 'zod';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {notificationTypeSchema} from './type-registry';

// Preserve PostgreSQL timestamp precision; never round cursors via JS Date.
const cursorSchema=z.strictObject({createdAt:z.iso.datetime({offset:true}),id:z.uuid().transform(v=>v.toLowerCase())});
const requestSchema=z.strictObject({unreadOnly:z.boolean().default(false),limit:z.number().int().min(1).max(100).default(50),cursor:cursorSchema.optional()});
// Existing M15.1 permits extensible historical codes. Unknown codes are inert
// stored labels, never aliases for another registry type or authorization.
const storedCode=notificationTypeSchema.or(z.string().regex(/^[A-Z][A-Z0-9_]{0,63}$/));
const rowSchema=z.strictObject({id:z.uuid(),recipient_user_id:z.uuid(),notification_type:storedCode,
 title:z.string().min(1).max(160),body:z.string().min(1).max(500),
 entity_type:z.string().regex(/^[A-Za-z][A-Za-z0-9_]{0,63}$/).nullable(),entity_id:z.uuid().nullable(),
 read_at:z.iso.datetime({offset:true}).nullable(),created_at:z.iso.datetime({offset:true}),
}).refine(r=>(r.entity_type===null)===(r.entity_id===null));
export type NotificationListItem=Omit<z.infer<typeof rowSchema>,'recipient_user_id'>;
export type NotificationPage=Readonly<{items:NotificationListItem[];nextCursor:z.infer<typeof cursorSchema>|null}>;
const columns='id,recipient_user_id,notification_type,title,body,entity_type,entity_id,read_at,created_at';
/** Read only. References are not expanded and confer no target authority.
 * Normal user-scoped SELECT + existing recipient-only RLS are both required.
 */
export async function listMyNotifications(input:unknown={}):Promise<NotificationPage>{
 try{
  const actor=await getAuthorizationContext(),parsed=requestSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
  const {limit,unreadOnly,cursor}=parsed.data,db=await createServerSupabaseClient();
  let query=db.from('notifications').select(columns).eq('recipient_user_id',actor.userId)
   .order('created_at',{ascending:false}).order('id',{ascending:false});
  if(unreadOnly)query=query.is('read_at',null);
  // Both interpolation components pass strict timestamp/UUID validation. No
  // arbitrary filter syntax or confidential content is accepted in the cursor.
  if(cursor)query=query.or('created_at.lt.'+cursor.createdAt+',and(created_at.eq.'+cursor.createdAt+',id.lt.'+cursor.id+')');
  const result=await query.limit(limit+1);
  if(result.error)throw new AuthorizationError('NOT_FOUND');
  const rows=z.array(rowSchema).max(limit+1).parse(result.data);
  if(rows.some(r=>r.recipient_user_id.toLowerCase()!==actor.userId.toLowerCase()))throw new AuthorizationError('NOT_FOUND');
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
  const selected=rows.slice(0,limit),last=selected.at(-1);
  const items=selected.map(r=>({id:r.id,notification_type:r.notification_type,title:r.title,body:r.body,
   entity_type:r.entity_type,entity_id:r.entity_id,read_at:r.read_at,created_at:r.created_at}));
  return {items,nextCursor:rows.length>limit&&last?{createdAt:last.created_at,id:last.id}:null};
 }catch(e){
  throw new AuthorizationError(e instanceof AuthorizationError?e.code:'NOT_FOUND');
 }
}
