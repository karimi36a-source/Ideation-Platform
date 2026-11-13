import {teamChatEventSchema,teamChatSubscriptionSchema} from "./realtime-schema";
import {chatMessageSchema,type ChatMessage} from "./schema";
import {chatCursorSchema} from "./message-schema";
import {z} from "zod";
type Descriptor=z.infer<typeof teamChatSubscriptionSchema>;
type Cursor=z.infer<typeof chatCursorSchema>;
export type TeamChatRealtimePorts={
 authorize:()=>Promise<unknown>;
 load:(cursor?:Cursor)=>Promise<unknown>;
 subscribe:(descriptor:Descriptor,event:(value:unknown)=>void,ready:()=>void,failed:()=>void)=>Promise<()=>Promise<void>>;
 messages:(items:readonly ChatMessage[])=>void;
 denied:()=>void;
};
const pageSchema=z.strictObject({items:z.array(chatMessageSchema),nextCursor:chatCursorSchema.nullable()});
/** Notifications only invalidate canonical reads. Never write/render event data. */
export function createTeamChatRealtimeController(ports:TeamChatRealtimePorts){
 let generation=0;let descriptor:Descriptor|null=null;let stop:(()=>Promise<void>)|null=null;
 let messages=new Map<string,ChatMessage>();let queue:Promise<void>=Promise.resolve();
 async function clear(){generation++;descriptor=null;messages.clear();ports.messages([]);const old=stop;stop=null;if(old)await old();}
 function refresh(){
  const current=generation;
  queue=queue.then(async()=>{
   if(current!==generation)return;
   try{
    const access=teamChatSubscriptionSchema.parse(await ports.authorize());
    if(current!==generation)return;
    if(!descriptor||access.topic!==descriptor.topic)throw new Error("Access unavailable");
    const canonical=new Map<string,ChatMessage>();const cursors=new Set<string>();let cursor:Cursor|undefined;
    do{
     const page=pageSchema.parse(await ports.load(cursor));
     if(current!==generation)return;
     for(const message of page.items){if(message.chat_channel_id!==access.chatChannelId)throw new Error("Access unavailable");canonical.set(message.id,message);}
     cursor=page.nextCursor??undefined;
     if(cursor){const key=JSON.stringify(cursor);if(cursors.has(key))throw new Error("Invalid page");cursors.add(key);}
    }while(cursor);
    messages=canonical;ports.messages([...canonical.values()]);
   }catch{if(current===generation){await clear();ports.denied();}}
  });
  return queue;
 }
 async function connect(){
  await clear();const current=generation;
  try{
   const access=teamChatSubscriptionSchema.parse(await ports.authorize());if(current!==generation)return;
   descriptor=access;
   // Restore canonical storage BEFORE subscribing; refresh again on SUBSCRIBED
   // closes the load/join race and reauthorizes SDK automatic reconnects.
   await refresh();if(current!==generation||!descriptor)return;
   const unsubscribe=await ports.subscribe(access,value=>{
    const event=teamChatEventSchema.safeParse(value);
    if(current!==generation||!descriptor||!event.success||event.data.chatChannelId!==descriptor.chatChannelId||messages.has(event.data.messageId))return;
    void refresh();
   },()=>{if(current===generation)void refresh();},()=>{if(current===generation)void clear().then(()=>ports.denied());});
   if(current!==generation){await unsubscribe();return;}stop=unsubscribe;
  }catch{if(current===generation){await clear();ports.denied();}}
 }
 return {connect,reconnect:connect,disconnect:clear};
}
