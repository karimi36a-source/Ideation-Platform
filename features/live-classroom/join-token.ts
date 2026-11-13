import 'server-only';
import {recordLiveClassroomFailure} from './diagnostics';
import {observeDatabase,setLogContext,withOperationLog} from '@/lib/observability/structured-log';
import {z} from 'zod';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {canJoinLiveSession} from './join-authorization';
import {createLiveClassroomProvider} from './factory';
import {providerRoomRefSchema,type LiveClassroomProvider} from './provider';
const inputSchema=z.strictObject({liveSessionRoomId:z.uuid()});
const contextSchema=z.strictObject({liveSessionRoomId:z.uuid(),providerRoomRef:providerRoomRefSchema,userId:z.uuid(),displayName:z.string().min(1).max(255),participantRole:z.enum(['STUDENT','MASTER'])});
const tokenSchema=z.strictObject({token:z.string().min(1).max(16384).regex(/^[A-Za-z0-9_.-]+$/),expiresAt:z.number().int().positive()});
// Server-controlled capability, never persisted FICI identity. M16.8 requires
// Daily ejection at expiry; continued participation requires a fresh authorized join.
export const LIVE_SESSION_JOIN_TTL_SECONDS=60;
export class LiveSessionJoinUnavailableError extends Error{readonly code='LIVE_JOIN_UNAVAILABLE';constructor(){super('Live classroom join unavailable.');this.name='LiveSessionJoinUnavailableError';}}
type Ports={resolve:(id:string)=>Promise<unknown>;student:(input:{liveSessionRoomId:string})=>Promise<boolean>;provider:()=>LiveClassroomProvider};
const ports:Ports={async resolve(id){const db=await createServerSupabaseClient();const {data,error}=await observeDatabase('authorize_live_session_join',()=>db.rpc('authorize_live_session_join',{target_room:id}));if(error)throw new AuthorizationError('FORBIDDEN');return data;},student:canJoinLiveSession,provider:createLiveClassroomProvider};
/** Internal server composition seam. No client identity/role/path/TTL accepted. */
export function createLiveSessionJoinOperation(dependencies:Ports){return async(input:unknown)=>{
 return withOperationLog('LIVE_TOKEN',async()=>{
 const parsed=inputSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 try{
  const initial=await getAuthorizationContext();
  setLogContext({actorId:initial.userId});
  const authorize=async()=>{
   const current=await getAuthorizationContext();if(current.userId!==initial.userId)throw new AuthorizationError('FORBIDDEN');
   const ctx=contextSchema.parse(await dependencies.resolve(parsed.data.liveSessionRoomId));
   if(ctx.userId!==initial.userId||ctx.liveSessionRoomId!==parsed.data.liveSessionRoomId)throw new AuthorizationError('FORBIDDEN');
   if(ctx.participantRole==='STUDENT'&&!await dependencies.student(parsed.data))throw new AuthorizationError('FORBIDDEN');
   return ctx;
  };
  const ctx=await authorize(),expiresAt=Math.floor(Date.now()/1000)+LIVE_SESSION_JOIN_TTL_SECONDS;
  setLogContext({actorId:initial.userId,liveSessionRoomId:ctx.liveSessionRoomId,provider:'DAILY'});
  const response=await dependencies.provider().createJoinToken({providerRoomRef:ctx.providerRoomRef,userId:ctx.userId,displayName:ctx.displayName,expiresAt});
  if(!response.success)throw new LiveSessionJoinUnavailableError();
  const capability=tokenSchema.parse(response.data);
  if(capability.expiresAt!==expiresAt||expiresAt<=Math.floor(Date.now()/1000))throw new LiveSessionJoinUnavailableError();
  const latest=await authorize();
  if(latest.providerRoomRef!==ctx.providerRoomRef||latest.participantRole!==ctx.participantRole||latest.displayName!==ctx.displayName)throw new AuthorizationError('FORBIDDEN');
  return {liveSessionRoomId:ctx.liveSessionRoomId,provider:'DAILY' as const,participantRole:ctx.participantRole,token:capability.token,expiresAt};
 }catch(error){if(error instanceof AuthorizationError)throw new AuthorizationError(error.code);recordLiveClassroomFailure('TOKEN_ISSUANCE','UNAVAILABLE');throw new LiveSessionJoinUnavailableError();}
 });
};}
export const getLiveSessionJoinToken=createLiveSessionJoinOperation(ports);


