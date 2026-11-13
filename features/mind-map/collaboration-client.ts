"use client";
import {createClient} from "@liveblocks/client";
import {z} from "zod";
import {collaborationRequestSchema,mindMapRoomId} from "./collaboration-schema";
export function createMindMapLiveClient(activityInstanceId:string,mapId:string){
 const input=collaborationRequestSchema.parse({activityInstanceId}),roomId=mindMapRoomId(mapId);
 const authorize=async()=>{
  try{
   const response=await fetch("/api/v1/mind-map/collaboration-auth",{method:"POST",credentials:"same-origin",cache:"no-store",headers:{"Content-Type":"application/json"},body:JSON.stringify(input)});
   if(!response.ok)return {error:"forbidden" as const,reason:"Resource unavailable."};
   return z.strictObject({ok:z.literal(true),data:z.strictObject({token:z.string().min(1)})}).parse(await response.json()).data;
  }catch{return {error:"forbidden" as const,reason:"Resource unavailable."};}
 };
 let primed:Awaited<ReturnType<typeof authorize>>|null=null;
 const client=createClient({throttle:50,authEndpoint:async requested=>{
  if(requested!==roomId)return {error:"forbidden" as const,reason:"Resource unavailable."};
  const first=primed;primed=null;return first??authorize();
 }});
 // Complete FICI's before/after-provider checks before starting the SDK's
 // short connection/auth deadline. Refreshes still re-enter FICI authorization.
 return {client,roomId,prepare:async()=>{primed=await authorize();return primed;}};
}
