import 'server-only';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {listMyNotifications} from './list';
/** No caller recipient/scope input. Identity comes only from verified server auth. */
export async function getNotificationSubscription(){
 const actor=await getAuthorizationContext();
 return {userId:actor.userId,topic:'notifications:'+actor.userId};
}
export async function reloadNotificationPage(input:unknown){
 const before=await getAuthorizationContext();
 const page=await listMyNotifications(input);
 if((await getAuthorizationContext()).userId!==before.userId)throw new AuthorizationError('AUTH_REQUIRED');
 return {userId:before.userId,page};
}
