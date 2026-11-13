import 'server-only';
import {notifyCommentReceived} from '@/features/notifications/comment';
import {z} from 'zod';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {resolveSharedEntityAccess} from './access';
import {addSharedCommentSchema,sharedCommentThreadSchema,sharedCommentSchema} from './comment-schema';
const safe=(e:unknown)=>new AuthorizationError(e instanceof AuthorizationError&&['AUTH_REQUIRED','VALIDATION_ERROR'].includes(e.code)?e.code:'FORBIDDEN');
/** Exact frozen Share target only. The database rechecks/locks current authority. */
export async function addSharedComment(input:unknown){try{
 const actor=await getAuthorizationContext(),v=addSharedCommentSchema.safeParse(input);if(!v.success)throw new AuthorizationError('VALIDATION_ERROR');
 const access=await resolveSharedEntityAccess({shareId:v.data.shareId});
 if(!access.allowed||!access.canComment)throw new AuthorizationError('FORBIDDEN');
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');
 const db=await createServerSupabaseClient(),r=await db.rpc('add_share_comment',{input:v.data});
 if(r.error)throw new AuthorizationError(r.error.code==='22023'?'VALIDATION_ERROR':'FORBIDDEN');
 const row=sharedCommentSchema.safeParse(r.data);
 if((await getAuthorizationContext()).userId!==actor.userId||!row.success||row.data.share_id!==v.data.shareId||row.data.author_user_id!==actor.userId||row.data.content!==v.data.content||row.data.target_entity_type!==access.sharedEntityType||row.data.target_entity_id!==access.sharedEntityId||row.data.target_version_id!==access.sourceVersionId)throw new AuthorizationError('FORBIDDEN');await notifyCommentReceived(row.data.id);return row.data;
}catch(e){throw safe(e);}}
/** Source reads and recipient reads share one database-authoritative thread ACL. */
export async function listSharedComments(input:unknown){try{
 const actor=await getAuthorizationContext(),v=sharedCommentThreadSchema.safeParse(input);if(!v.success)throw new AuthorizationError('VALIDATION_ERROR');
 const db=await createServerSupabaseClient();
 const read=async()=>{const r=await db.rpc('list_share_comments',{input:v.data});if(r.error)throw new AuthorizationError('FORBIDDEN');const rows=z.array(sharedCommentSchema).parse(r.data);if(rows.some(c=>c.share_id!==v.data.shareId))throw new AuthorizationError('FORBIDDEN');return rows;};
 await read();if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');return await read();
}catch(e){throw safe(e);}}
