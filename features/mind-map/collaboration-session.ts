"use client";
import {createMindMapLiveClient} from "./collaboration-client";
import {collaborationEventSchema,type MindMapCollaborationEvent} from "./collaboration-schema";

/** Event-only transport: no shared Storage, labels, Object graph, or durable IDs.
 * Every canonical hint is a request to reload FICI, never an acknowledgement. */
export function openMindMapCollaboration(activityId:string,mapId:string,callbacks:{
 event:(event:MindMapCollaborationEvent)=>void;
 status:(status:"connected"|"offline")=>void;
}){
 const {client,roomId,prepare}=createMindMapLiveClient(activityId,mapId);
 let disposed=false,leave=()=>{},send:((event:MindMapCollaborationEvent)=>void)=()=>{};
 void prepare().then(grant=>{
 if(disposed)return;if("error" in grant){callbacks.status("offline");return;}
 const connection=client.enterRoom(roomId,{initialPresence:{}}),room=connection.room;
 const unsubscribe=room.subscribe("event",({event,user})=>{
  const parsed=collaborationEventSchema.safeParse(event);
  // Sender permission is provider-authenticated metadata, never event content.
  // A view-only token must not manufacture transient writer interactions.
  if(parsed.success&&(parsed.data.type==="mind-map-reload"||user?.canWrite===true))callbacks.event(parsed.data);
 });
 const status=room.subscribe("status",value=>{callbacks.status(value==="connected"?"connected":"offline");if(value==="connected")callbacks.event({type:"mind-map-reload"});});
 const error=room.subscribe("error",()=>callbacks.status("offline"));
 send=event=>{if(room.getStatus()==="connected")try{room.broadcastEvent(event);}catch{callbacks.status("offline");}};
 leave=()=>{unsubscribe();status();error();connection.leave();};
 }).catch(()=>{if(!disposed)callbacks.status("offline");});
 return {send(event:MindMapCollaborationEvent){send(event);},close(){disposed=true;leave();}};
}
