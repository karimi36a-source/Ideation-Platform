import "server-only";
import {authorizePrivateToolRoom} from "@/lib/collaboration/liveblocks-server";
// Preserve the accepted Affinity adapter contract and namespace.
export const liveblocksAffinityProvider={
 async authorize(input:Readonly<{userId:string;roomId:string}>){
  if(!/^affinity:[a-f0-9-]{36}$/.test(input.roomId))throw new Error("Provider unavailable.");
  return authorizePrivateToolRoom(input);
 },
};
