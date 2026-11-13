'use server';
import {getNotificationSubscription,reloadNotificationPage} from './realtime-service';
// Read-only bridges; provider errors and private diagnostics never reach browser.
export async function authorizeNotificationRealtime(){
 try{return {ok:true as const,data:await getNotificationSubscription()};}catch{return {ok:false as const};}
}
export async function loadNotificationRealtimePage(input:unknown){
 try{return {ok:true as const,data:await reloadNotificationPage(input)};}catch{return {ok:false as const};}
}
