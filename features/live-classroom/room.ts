import 'server-only';
import {recordLiveClassroomFailure} from './diagnostics';
import {observeDatabase,setLogContext,withOperationLog} from '@/lib/observability/structured-log';
import {createClient} from '@supabase/supabase-js';
import type {Database} from '@/lib/db/database.types';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getServerEnv} from '@/lib/validation/env-server';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createLiveClassroomProvider} from './factory';
import {createLiveRoomMappingRepository} from './mapping-repository';
import type {LiveClassroomProvider} from './provider';
import {liveSessionRoomInputSchema,liveSessionRoomSchema,masterLiveRoomContextSchema,type LiveSessionRoomInput} from './room-schema';

export class LiveSessionRoomUnavailableError extends Error {
 readonly code='LIVE_ROOM_UNAVAILABLE';
 constructor(){super('Live classroom room unavailable.');this.name='LiveSessionRoomUnavailableError';}
}
type RoomPorts={authorize:(v:LiveSessionRoomInput)=>Promise<unknown>;repository:(v:LiveSessionRoomInput,actorId:string)=>ReturnType<typeof createLiveRoomMappingRepository>;provider:()=>LiveClassroomProvider};
const ports:RoomPorts={
 async authorize(v){
  const db=await createServerSupabaseClient();
  const {data,error}=await observeDatabase('authorize_master_live_room',()=>db.rpc('authorize_master_live_room',{target_cohort:v.cohortId,target_session:v.sessionDefinitionId,target_activity:v.activityInstanceId??null}));
  if(error)throw new AuthorizationError('FORBIDDEN');return data;
 },
 repository(v,actorId){
  const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw new LiveSessionRoomUnavailableError();
  const db=createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:'error',cache:'no-store'})}});
  return createLiveRoomMappingRepository({async rpc(name,args){
   if(name!=='manage_live_room_mapping'||args.actor!==actorId||args.target_cohort!==v.cohortId||args.target_session!==v.sessionDefinitionId||args.target_provider!=='DAILY'||args.expected_room!==null||!['FIND_ACTIVE','REUSE_OR_CREATE'].includes(args.command))throw new AuthorizationError('FORBIDDEN');
   return observeDatabase('master_live_room_mapping',()=>db.rpc('master_live_room_mapping',{command:args.command,target_cohort:v.cohortId,target_session:v.sessionDefinitionId,target_activity:v.activityInstanceId??null,room_reference:args.room_reference,actor:actorId}));
  }});
 },
 provider:createLiveClassroomProvider,
};
/** Trusted server composition seam, never a client-controlled policy/identity.
 * Provider calls happen only after current Cohort authorization. Persistence
 * independently checks the same authority in its locked database transaction. */
export function createMasterLiveRoomOperation(dependencies:RoomPorts){
 return async function getOrCreateLiveSessionRoom(input:unknown){
  return withOperationLog('LIVE_ROOM',async()=>{
  const parsed=liveSessionRoomInputSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
  let failurePhase:'ROOM_RESOLUTION'|'MAPPING_SAVE'='ROOM_RESOLUTION';
  try{
   const v=parsed.data,initial=await getAuthorizationContext();
   setLogContext({actorId:initial.userId});
   const authorize=async()=>{
    const current=await getAuthorizationContext();if(current.userId!==initial.userId)throw new AuthorizationError('FORBIDDEN');
    const ctx=masterLiveRoomContextSchema.safeParse(await dependencies.authorize(v));
    if(!ctx.success||ctx.data.actorId!==initial.userId||ctx.data.cohortId!==v.cohortId||ctx.data.sessionDefinitionId!==v.sessionDefinitionId)throw new AuthorizationError('FORBIDDEN');
    return ctx.data;
   };
   const context=await authorize();
   setLogContext({actorId:initial.userId,cohortId:context.cohortId,provider:'DAILY'});
   const repo=dependencies.repository(v,initial.userId),scope={cohortId:v.cohortId,sessionDefinitionId:v.sessionDefinitionId,provider:'DAILY' as const};
   let mapping=await repo.findActive(scope);
   if(!mapping){
    const latest=await authorize();if(latest.roomKey!==context.roomKey)throw new LiveSessionRoomUnavailableError();
    const created=await dependencies.provider().getOrCreateRoom({roomKey:context.roomKey});
    if(!created.success||created.data.providerRoomRef!==context.roomKey)throw new LiveSessionRoomUnavailableError();
    const current=await authorize();if(current.roomKey!==context.roomKey)throw new LiveSessionRoomUnavailableError();
    // The deterministic generation key is unchanged by a failed save. An
    // explicit retry re-reads FICI first, then GETs the same provider room;
    // never delete a possibly committed room or mint a random replacement.
    failurePhase='MAPPING_SAVE';
    mapping=await repo.write({...scope,command:'REUSE_OR_CREATE',providerRoomRef:context.roomKey});
    failurePhase='ROOM_RESOLUTION';
   }
   await authorize();
   // Project only room integration metadata; no URL, token, creator or secret.
   return liveSessionRoomSchema.parse({id:mapping.id,provider:mapping.provider,providerRoomRef:mapping.provider_room_ref,status:mapping.status,cohortId:mapping.cohort_id,sessionDefinitionId:mapping.session_definition_id});
  }catch(error){
   if(error instanceof AuthorizationError)throw new AuthorizationError(error.code);
   recordLiveClassroomFailure(failurePhase,'UNAVAILABLE');
   throw new LiveSessionRoomUnavailableError();
  }
  });
 };
}
export const getOrCreateLiveSessionRoom=createMasterLiveRoomOperation(ports);


