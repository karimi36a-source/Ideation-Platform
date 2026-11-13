"use server";
import {getTeamChatSubscription} from "./realtime-service";
import {listTeamChatMessages} from "./service";
import {AuthorizationError} from "@/lib/auth/authorization";
/** Explicit read-only server-action bridge; never returns provider diagnostics. */
export async function authorizeTeamChatRealtime(teamId:unknown){
 try{return {ok:true as const,data:await getTeamChatSubscription(teamId)};}
 catch(error){return {ok:false as const,error:error instanceof AuthorizationError?error.code:"FORBIDDEN" as const};}
}
export async function loadTeamChatRealtimePage(input:unknown){
 try{return {ok:true as const,data:await listTeamChatMessages(input)};}
 catch(error){return {ok:false as const,error:error instanceof AuthorizationError?error.code:"FORBIDDEN" as const};}
}
