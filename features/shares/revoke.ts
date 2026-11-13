import 'server-only';
import {z} from 'zod';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {shareSchema,type Share} from './schema';
/** Current source authority is checked and locked inside the atomic RPC.
 * An authorized retry can retain a different original revoker's identity.
 */
export async function revokeShare(shareId:unknown):Promise<Share>{try{
 const actor=await getAuthorizationContext(),id=z.uuid().transform(s=>s.toLowerCase()).safeParse(shareId);
 if(!id.success)throw new AuthorizationError('VALIDATION_ERROR');
 const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 const result=await db.rpc('revoke_share',{input:{shareId:id.data}});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 if(result.error)throw new AuthorizationError(result.error.code==='28000'?'AUTH_REQUIRED':result.error.code==='22023'?'VALIDATION_ERROR':'NOT_FOUND');
 const row=shareSchema.safeParse(result.data);
 if(!row.success||row.data.id.toLowerCase()!==id.data||row.data.revoked_at===null||row.data.revoked_by===null)throw new AuthorizationError('NOT_FOUND');
 return row.data;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&['AUTH_REQUIRED','VALIDATION_ERROR'].includes(error.code)?error.code:'NOT_FOUND');}}
