import 'server-only';
import {recordStructuredFailure,setLogContext,withOperationLog} from '@/lib/observability/structured-log';

/** Keep post-commit delivery failures nonfatal and correlated. Source IDs only;
 * no recipient email, message body, original exception or provider response.
 */
export function withNotificationLog<T>(operation:string,entityId:unknown,work:()=>Promise<T>):Promise<T>{
 return withOperationLog(operation,async()=>{setLogContext({entityId});return work();});
}
export function recordNotificationFallback():void{
 recordStructuredFailure('NOTIFICATION_FALLBACK',{phase:'DELIVERY',code:'UNAVAILABLE',provider:'SUPABASE',task:'create_domain_notification'});
}
