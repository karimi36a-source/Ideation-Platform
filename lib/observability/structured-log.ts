import 'server-only';
import {AsyncLocalStorage} from 'node:async_hooks';
import {randomUUID} from 'node:crypto';
import {headers} from 'next/headers';
import {z} from 'zod';

const operations=new Set(['LIVE_ROOM','LIVE_JOIN','LIVE_TOKEN','LIVE_BREAKOUT','LIVE_PROVIDER','NOTIFICATION_SUBMISSION','NOTIFICATION_APPROVAL','NOTIFICATION_REVISION','NOTIFICATION_SHARE','NOTIFICATION_COMMENT']);
const codes=new Set(['CONFIGURATION','AUTHENTICATION','AUTH_REQUIRED','FORBIDDEN','RATE_LIMIT','TIMEOUT','NETWORK','UNAVAILABLE','REJECTED','MALFORMED_RESPONSE','UNKNOWN','DATABASE_UNAVAILABLE']);
const phases=new Set(['PROVIDER','ROOM_RESOLUTION','MAPPING_SAVE','TOKEN_ISSUANCE','DATABASE','DELIVERY','APPLICATION']);
const events=new Set(['LIVE_FAILURE','DATABASE_FAILURE','NOTIFICATION_FALLBACK']);
const tasks=new Set(['ROOM_LOOKUP','ROOM_CREATE','TOKEN_CREATE','authorize_master_live_room','master_live_room_mapping','authorize_live_session_join','authorize_master_live_breakout','manage_live_breakout_mapping','authorize_live_breakout_join','approval_notification_contexts','revision_notification_contexts','artifact_share_notification_contexts','comment_notification_contexts','create_domain_notification']);
const ids=['actorId','cohortId','teamId','workspaceId','projectId','liveSessionRoomId','entityId'] as const;
type SafeFields=Partial<Record<typeof ids[number],string>> & {provider?:'DAILY'|'SUPABASE';task?:string};
type Context=SafeFields & {correlationId:string;operation:string;started:number};
const contexts=new AsyncLocalStorage<Context>();
function safeFields(input:Record<string,unknown>):SafeFields{
 const result:SafeFields={};
 for(const name of ids){const parsed=z.uuid().safeParse(input[name]);if(parsed.success)result[name]=parsed.data.toLowerCase();}
 if(input.provider==='DAILY'||input.provider==='SUPABASE')result.provider=input.provider;
 if(typeof input.task==='string'&&tasks.has(input.task))result.task=input.task;
 return result;
}
/** Only verified server context belongs here. Unknown fields/content are dropped. */
export function setLogContext(input:Record<string,unknown>):void{
 try{const current=contexts.getStore();if(current)Object.assign(current,safeFields(input));}catch{/* Logging cannot affect the operation. */}
}
/** The ingress proxy overwrites this header; nested operations inherit it.
 * Standalone/background operations get a fresh application-generated ID.
 */
export async function withOperationLog<T>(operation:string,work:()=>Promise<T>):Promise<T>{
 const parent=contexts.getStore();let correlationId=parent?.correlationId;
 if(!correlationId){try{const value=(await headers()).get('x-fici-correlation-id');const parsed=z.uuid().safeParse(value);if(parsed.success)correlationId=parsed.data.toLowerCase();}catch{/* No HTTP context, e.g. a background operation. */}}
 return contexts.run({...parent,correlationId:correlationId??randomUUID(),operation:operations.has(operation)?operation:'UNKNOWN',started:performance.now()},work);
}
/** One JSON event, never a raw Error/object dump. Content and arbitrary strings
 * cannot reach the sink. Runtime sink failure remains nonfatal.
 */
export function recordStructuredFailure(event:'LIVE_FAILURE'|'DATABASE_FAILURE'|'NOTIFICATION_FALLBACK',input:Record<string,unknown>):void{
 try{
  const ctx=contexts.getStore();
  const duration=typeof input.durationMs==='number'&&Number.isFinite(input.durationMs)?input.durationMs:ctx?performance.now()-ctx.started:0;
  const value={timestamp:new Date().toISOString(),level:'warn',event:events.has(event)?event:'LIVE_FAILURE',correlationId:ctx?.correlationId??randomUUID(),operation:ctx?.operation??'UNKNOWN',
   ...safeFields(ctx??{}),...safeFields(input),
   phase:typeof input.phase==='string'&&phases.has(input.phase)?input.phase:'APPLICATION',
   code:typeof input.code==='string'&&codes.has(input.code)?input.code:'UNKNOWN',durationMs:Math.round(Math.max(0,Math.min(86400000,duration)))};
  console.warn(JSON.stringify(value));
 }catch{/* Diagnostics must never change canonical state or the original error. */}
}
/** Log only the surfaced DB failure classification, not SQL/provider details. */
export async function observeDatabase<T>(task:string,work:()=>PromiseLike<T>):Promise<T>{
 const started=performance.now();
 try{
  const result=await work();
  if(result&&typeof result==='object'&&'error' in result&&result.error)recordStructuredFailure('DATABASE_FAILURE',{phase:'DATABASE',code:'DATABASE_UNAVAILABLE',provider:'SUPABASE',task,durationMs:performance.now()-started});
  return result;
 }catch(error){recordStructuredFailure('DATABASE_FAILURE',{phase:'DATABASE',code:'DATABASE_UNAVAILABLE',provider:'SUPABASE',task,durationMs:performance.now()-started});throw error;}
}
