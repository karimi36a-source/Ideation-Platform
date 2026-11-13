import "server-only";
import {Liveblocks} from "@liveblocks/node";
import {z} from "zod";
const grantSchema=z.strictObject({token:z.string().min(1)});
/** Shared private-room issuer. Current FICI authorization must bracket I/O. */
export async function authorizePrivateToolRoom({userId,roomId,writable=true}:Readonly<{userId:string;roomId:string;writable?:boolean}>){
 const secret=process.env.LIVEBLOCKS_SECRET_KEY;
 if(!secret||!/^(affinity|mind-map):[a-f0-9-]{36}$/.test(roomId))throw new Error("Provider unavailable.");
 try{
  const provider=new Liveblocks({secret});const room=await provider.getOrCreateRoom(roomId,{defaultAccesses:[]});
  if(room.defaultAccesses.length||Object.keys(room.usersAccesses).length||Object.keys(room.groupsAccesses).length)throw new Error();
  const session=provider.prepareSession(userId);session.allow(roomId,[writable?"*:write":"*:read","comments:none","feeds:none"]);
  const response=await session.authorize();if(response.status!==200)throw new Error();
  return grantSchema.parse(JSON.parse(response.body));
 }catch{throw new Error("Provider unavailable.");}
}
