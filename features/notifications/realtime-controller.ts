import {notificationEventSchema,notificationSubscriptionSchema,notificationReloadSchema} from './realtime-schema';
import type {NotificationRealtimeItem,NotificationSubscription,NotificationCursor} from './realtime-schema';
export type NotificationRealtimePorts={
 authorize:()=>Promise<unknown>;
 load:(cursor?:NotificationCursor)=>Promise<unknown>;
 subscribe:(access:NotificationSubscription,event:(value:unknown)=>void,ready:()=>void,failed:()=>void)=>Promise<()=>Promise<void>>;
 items:(items:readonly NotificationRealtimeItem[])=>void;
 unavailable:()=>void;
};
/** Event data is never rendered or persisted. Rejoin always restores M15.4 state. */
export function createNotificationRealtimeController(ports:NotificationRealtimePorts){
 let generation=0,access:NotificationSubscription|null=null,stop:(()=>Promise<void>)|null=null;
 let queue:Promise<void>=Promise.resolve();
 async function clear(){
  generation++;access=null;ports.items([]);const old=stop;stop=null;
  if(old)await old();
 }
 function refresh(){
  const current=generation;
  queue=queue.then(async()=>{
   if(current!==generation||!access)return;
   try{
    const checked=notificationSubscriptionSchema.parse(await ports.authorize());
    if(current!==generation)return;
    if(checked.userId!==access?.userId)throw new Error('Unavailable');
    const canonical=new Map<string,NotificationRealtimeItem>(),seen=new Set<string>();let cursor:NotificationCursor|undefined;
    do{
     const result=notificationReloadSchema.parse(await ports.load(cursor));
     if(current!==generation)return;
     if(result.userId!==checked.userId)throw new Error('Unavailable');
     for(const row of result.page.items)canonical.set(row.id,row);
     cursor=result.page.nextCursor??undefined;
     if(cursor){const key=JSON.stringify(cursor);if(seen.has(key))throw new Error('Invalid page');seen.add(key);}
    }while(cursor);
    // Preserve database order, including PostgreSQL timestamp precision.
    ports.items([...canonical.values()]);
   }catch{if(current===generation){await clear();ports.unavailable();}}
  });
  return queue;
 }
 async function connect(){
  const clearing=clear(),current=generation;await clearing;if(current!==generation)return;
  try{
   const checked=notificationSubscriptionSchema.parse(await ports.authorize());
   if(current!==generation)return;access=checked;
   await refresh();if(current!==generation||!access)return;
   const unsubscribe=await ports.subscribe(checked,value=>{
    if(current===generation&&notificationEventSchema.safeParse(value).success)void refresh();
   },()=>{if(current===generation)void refresh();},()=>{if(current===generation)void clear().then(()=>ports.unavailable());});
   if(current!==generation){await unsubscribe();return;}stop=unsubscribe;
  }catch{if(current===generation){await clear();ports.unavailable();}}
 }
 return {connect,reconnect:connect,refresh,disconnect:clear};
}
