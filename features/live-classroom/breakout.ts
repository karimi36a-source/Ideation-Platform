import 'server-only';
import {observeDatabase,setLogContext,withOperationLog} from '@/lib/observability/structured-log';
import {z} from 'zod';
import {createClient} from '@supabase/supabase-js';
import type {Database} from '@/lib/db/database.types';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getServerEnv} from '@/lib/validation/env-server';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createLiveClassroomProvider} from './factory';
import {createLiveSessionJoinOperation} from './join-token';
import {safeDailyRoomUrl} from './classroom-schema';
const inputSchema=z.strictObject({liveSessionRoomId:z.uuid(),teamId:z.uuid()});
const mapping=z.object({id:z.uuid(),live_session_room_id:z.uuid(),team_id:z.uuid(),provider:z.literal('DAILY'),provider_room_ref:z.string().regex(/^fici-[a-f0-9]{64}$/),status:z.literal('ACTIVE')});
const contextSchema=z.strictObject({breakoutRoomId:z.uuid(),liveSessionRoomId:z.uuid(),teamId:z.uuid(),cohortId:z.uuid(),sessionDefinitionId:z.uuid(),providerRoomRef:z.string().regex(/^fici-[a-f0-9]{64}$/),userId:z.uuid(),displayName:z.string(),participantRole:z.enum(['STUDENT','MASTER'])});
export async function getMasterBreakoutTeams(parent:unknown){const id=z.uuid().parse(parent),db=await createServerSupabaseClient();await getAuthorizationContext();const r=await db.rpc('list_live_breakout_teams',{parent_room:id});if(r.error)throw new AuthorizationError('FORBIDDEN');return z.array(z.strictObject({id:z.uuid(),name:z.string()})).parse(r.data);}
export async function getOrCreateTeamBreakout(input:unknown){
 return withOperationLog('LIVE_BREAKOUT',async()=>{
 const v=inputSchema.parse(input),actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
 const authorize=async()=>{if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');const r=await observeDatabase('authorize_master_live_breakout',()=>db.rpc('authorize_master_live_breakout',{parent_room:v.liveSessionRoomId,target_team:v.teamId}));if(r.error)throw new AuthorizationError('FORBIDDEN');const c=z.strictObject({actorId:z.uuid(),liveSessionRoomId:z.uuid(),teamId:z.uuid(),roomKey:z.string().regex(/^fici-[a-f0-9]{64}$/)}).parse(r.data);if(c.actorId!==actor.userId||c.teamId!==v.teamId||c.liveSessionRoomId!==v.liveSessionRoomId)throw new AuthorizationError('FORBIDDEN');return c;};
 const ctx=await authorize();setLogContext({actorId:actor.userId,teamId:ctx.teamId,liveSessionRoomId:ctx.liveSessionRoomId,provider:'DAILY'});const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw Error('Breakout unavailable');
 const internal=createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,redirect:'error',cache:'no-store',signal:AbortSignal.timeout(15000)})}});
 const persist=async(command:'FIND_ACTIVE'|'REUSE_OR_CREATE')=>{const r=await observeDatabase('manage_live_breakout_mapping',()=>internal.rpc('manage_live_breakout_mapping',{command,parent_room:v.liveSessionRoomId,target_team:v.teamId,actor:actor.userId,room_reference:command==='REUSE_OR_CREATE'?ctx.roomKey:null}));if(r.error)throw Error('Breakout unavailable');if(r.data===null)return null;const row=mapping.parse(r.data);if(row.live_session_room_id!==v.liveSessionRoomId||row.team_id!==v.teamId)throw Error('Breakout unavailable');return row;};
 let row=await persist('FIND_ACTIVE');if(!row){const provider=await createLiveClassroomProvider().getOrCreateRoom({roomKey:ctx.roomKey});if(!provider.success||provider.data.providerRoomRef!==ctx.roomKey)throw Error('Breakout unavailable');const latest=await authorize();if(latest.roomKey!==ctx.roomKey)throw Error('Breakout unavailable');row=await persist('REUSE_OR_CREATE');}
 await authorize();if(!row)throw Error('Breakout unavailable');return {id:row.id};
 });
}
export async function getBreakoutContext(id:unknown){return withOperationLog('LIVE_BREAKOUT',async()=>{const target=z.uuid().parse(id),actor=await getAuthorizationContext(),db=await createServerSupabaseClient();const r=await observeDatabase('authorize_live_breakout_join',()=>db.rpc('authorize_live_breakout_join',{target_breakout:target}));if(r.error)throw new AuthorizationError('FORBIDDEN');const c=contextSchema.parse(r.data);if(c.breakoutRoomId!==target||c.userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');setLogContext({actorId:c.userId,teamId:c.teamId,cohortId:c.cohortId,liveSessionRoomId:c.liveSessionRoomId,provider:'DAILY'});return c;});}
const issue=createLiveSessionJoinOperation({async resolve(id){const c=await getBreakoutContext(id);return {liveSessionRoomId:c.breakoutRoomId,providerRoomRef:c.providerRoomRef,userId:c.userId,displayName:c.displayName,participantRole:c.participantRole};},async student(input){return (await getBreakoutContext(input.liveSessionRoomId)).participantRole==='STUDENT';},provider:createLiveClassroomProvider});
export async function getBreakoutJoin(input:unknown){
 return withOperationLog('LIVE_BREAKOUT',async()=>{
 const v=z.strictObject({breakoutRoomId:z.uuid()}).parse(input),before=await getBreakoutContext(v.breakoutRoomId);setLogContext({actorId:before.userId,teamId:before.teamId,cohortId:before.cohortId,liveSessionRoomId:before.liveSessionRoomId,provider:'DAILY'});const status=await createLiveClassroomProvider().getRoomStatus(before.providerRoomRef);
 if(!status.success||status.data.status!=='available'||!status.data.url)throw Error('Breakout unavailable');const url=safeDailyRoomUrl(status.data.url,before.providerRoomRef),token=await issue({liveSessionRoomId:v.breakoutRoomId}),after=await getBreakoutContext(v.breakoutRoomId);
 if(after.providerRoomRef!==before.providerRoomRef||after.userId!==before.userId||after.participantRole!==before.participantRole)throw new AuthorizationError('FORBIDDEN');return {url,token:token.token,expiresAt:token.expiresAt};
 });
}
