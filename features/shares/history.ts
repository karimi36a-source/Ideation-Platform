import 'server-only';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {listEntitySharesInputSchema,entityShareHistorySchema,type ShareHistoryRecord} from './history-schema';
/** Source authority only. No caching or recipient-derived enumeration rights. */
export async function listEntityShares(input:unknown):Promise<ShareHistoryRecord[]>{try{
 const actor=await getAuthorizationContext(),v=listEntitySharesInputSchema.safeParse(input);
 if(!v.success)throw new AuthorizationError('VALIDATION_ERROR');
 const db=await createServerSupabaseClient();
 const read=async()=>{
  const r=await db.rpc('list_entity_shares',{input:v.data});
  if(r.error)throw new AuthorizationError(r.error.code==='28000'?'AUTH_REQUIRED':r.error.code==='22023'?'VALIDATION_ERROR':'NOT_FOUND');
  const rows=entityShareHistorySchema.safeParse(r.data);
  if(!rows.success||rows.data.entityType!==v.data.entityType||rows.data.entityId.toLowerCase()!==v.data.entityId)throw new AuthorizationError('NOT_FOUND');
  return rows.data.shares;
 };
 await read();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 return await read();
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&['AUTH_REQUIRED','VALIDATION_ERROR'].includes(error.code)?error.code:'NOT_FOUND');}}
