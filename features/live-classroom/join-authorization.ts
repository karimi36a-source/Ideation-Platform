import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
const inputSchema=z.strictObject({liveSessionRoomId:z.uuid()});
/** Request identity and room scope are resolved server-side. This is current
 * eligibility, never a cached capability or token. M16.5 must recheck at issuance. */
export async function canJoinLiveSession(input:unknown):Promise<boolean>{
 const parsed=inputSchema.safeParse(input);if(!parsed.success)return false;
 try{
  const before=await getAuthorizationContext(),db=await createServerSupabaseClient();
  const args={target_room:parsed.data.liveSessionRoomId};
  const first=await db.rpc('can_join_live_session',args);
  if(first.error||first.data!==true)return false;
  const after=await getAuthorizationContext();if(after.userId!==before.userId)return false;
  // Match the existing enrollment-access pattern: re-read current DB authority
  // after identity/profile resolution, rather than replaying an earlier result.
  const latest=await db.rpc('can_join_live_session',args);
  return !latest.error&&latest.data===true;
 }catch{return false;}
}
