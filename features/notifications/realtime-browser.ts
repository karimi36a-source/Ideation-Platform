'use client';
import {createBrowserSupabaseClient} from '@/lib/db/browser';
import {authorizeNotificationRealtime,loadNotificationRealtimePage} from './realtime-actions';
import {createNotificationRealtimeController} from './realtime-controller';
import type {NotificationRealtimeItem} from './realtime-schema';
/** Receive only; no send, presence, caller recipient or durable client event state. */
export function createNotificationRealtime(onItems:(items:readonly NotificationRealtimeItem[])=>void,onUnavailable:()=>void){
 const db=createBrowserSupabaseClient();
 const controller=createNotificationRealtimeController({
  authorize:async()=>{const r=await authorizeNotificationRealtime();if(!r.ok)throw new Error('Unavailable');return r.data;},
  load:async cursor=>{const r=await loadNotificationRealtimePage({limit:100,...(cursor?{cursor}:{})});if(!r.ok)throw new Error('Unavailable');return r.data;},
  subscribe:async(access,event,ready,failed)=>{
   await db.realtime.setAuth();
   const channel=db.channel(access.topic,{config:{private:true}})
    .on('broadcast',{event:'notification.changed'},value=>event(value.payload))
    .subscribe(status=>{if(status==='SUBSCRIBED')ready();else if(status==='CHANNEL_ERROR'||status==='TIMED_OUT'||status==='CLOSED')failed();});
   return async()=>{await db.removeChannel(channel);};
  },items:onItems,unavailable:onUnavailable,
 });
 let authStop:(()=>void)|null=null,closed=true,revision=0;
 async function connect(){
  closed=false;
  if(!authStop){
   const {data}=db.auth.onAuthStateChange((event)=>{
    if(event==='INITIAL_SESSION'||event==='TOKEN_REFRESHED')return;
    // Clear synchronously, then defer Supabase calls outside its auth callback.
    const current=++revision;void controller.disconnect();
    if(event!=='SIGNED_OUT')setTimeout(()=>{if(!closed&&current===revision)void controller.connect();},0);
   });
   authStop=()=>data.subscription.unsubscribe();
  }
  await controller.connect();
 }
 async function disconnect(){closed=true;revision++;authStop?.();authStop=null;await controller.disconnect();}
 return {connect,reconnect:connect,refresh:controller.refresh,disconnect};
}
