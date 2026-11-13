"use client";
import {createBrowserSupabaseClient} from "@/lib/db/browser";
import {authorizeTeamChatRealtime,loadTeamChatRealtimePage} from "./realtime-actions";
import {createTeamChatRealtimeController} from "./realtime-controller";
import type {ChatMessage} from "./schema";
/** Receive-only adapter. No Presence, client send, or browser authority claims. */
export function createTeamChatRealtime(teamId:string,onMessages:(items:readonly ChatMessage[])=>void,onUnavailable:()=>void){
 const db=createBrowserSupabaseClient();
 return createTeamChatRealtimeController({
  authorize:async()=>{const result=await authorizeTeamChatRealtime(teamId);if(!result.ok)throw new Error("Access unavailable");return result.data;},
  load:async cursor=>{const result=await loadTeamChatRealtimePage({teamId,limit:100,...(cursor?{cursor}:{})});if(!result.ok)throw new Error("Access unavailable");return result.data;},
  subscribe:async(descriptor,event,ready,failed)=>{
   await db.realtime.setAuth();
   const channel=db.channel(descriptor.topic,{config:{private:true}})
    .on("broadcast",{event:"team.message.created"},value=>event(value.payload))
    .subscribe(status=>{if(status==="SUBSCRIBED")ready();else if(status==="CHANNEL_ERROR"||status==="TIMED_OUT"||status==="CLOSED")failed();});
   return async()=>{await db.removeChannel(channel);};
  },messages:onMessages,denied:onUnavailable,
 });
}
