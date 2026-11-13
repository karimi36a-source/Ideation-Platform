import 'server-only';
import {z} from 'zod';
import {recordLiveClassroomFailure} from '../diagnostics';
import {setLogContext,withOperationLog} from '@/lib/observability/structured-log';
import {joinContextSchema,providerRoomRefSchema,roomContextSchema,type JoinContext,type LiveClassroomErrorCode,type LiveClassroomProvider,type LiveClassroomResult,type ProviderRoom,type RoomContext} from '../provider';

const configuration=z.strictObject({apiKey:z.string().min(1).refine(v=>v.trim()===v&&!/[\r\n]/.test(v)),timeoutMs:z.number().int().min(1).max(60000).default(10000)});
const roomSchema=z.object({name:providerRoomRefSchema,privacy:z.literal('private'),url:z.string(),config:z.object({exp:z.number().int().positive().optional()}).optional()});
const fail=(code:LiveClassroomErrorCode,retryable=false):LiveClassroomResult<never>=>{if(!['INVALID_INPUT','NOT_FOUND','CONFLICT'].includes(code))recordLiveClassroomFailure('PROVIDER',code);return {success:false,error:{code,message:'Live classroom provider unavailable.',retryable}};};
/** Daily REST transport only; no FICI persistence, roles, routes or domain state.
 * https://docs.daily.co/reference/rest-api/rooms/create-room
 * https://docs.daily.co/reference/rest-api/meeting-tokens/create-meeting-token */
export class DailyLiveClassroomProvider implements LiveClassroomProvider {
 #config:ReturnType<typeof configuration.safeParse>;
 #transport:typeof fetch;
 constructor(config:unknown,transport:typeof fetch=fetch){this.#config=configuration.safeParse(config);this.#transport=transport;}
 async #request(path:string,body?:unknown):Promise<LiveClassroomResult<unknown>>{
  return withOperationLog('LIVE_PROVIDER',async()=>{
  setLogContext({provider:'DAILY',task:path==='meeting-tokens'?'TOKEN_CREATE':body===undefined?'ROOM_LOOKUP':'ROOM_CREATE'});
  if(!this.#config.success)return fail('CONFIGURATION');
  const {apiKey,timeoutMs}=this.#config.data;
  if((path+JSON.stringify(body??null)).includes(apiKey))return fail('INVALID_INPUT');
  const controller=new AbortController();let timer:ReturnType<typeof setTimeout>|undefined;
  try{
   const work=async():Promise<LiveClassroomResult<unknown>>=>{
    const response=await this.#transport('https://api.daily.co/v1/'+path,{method:body===undefined?'GET':'POST',headers:{Authorization:'Bearer '+apiKey,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)}),redirect:'error',cache:'no-store',signal:controller.signal});
    if(!response.ok){
     // Provider diagnostics may contain credentials; never read or return them.
     if(response.status===401||response.status===403)return fail('AUTHENTICATION');
     if(response.status===404)return fail('NOT_FOUND');
     if(response.status===409)return fail('CONFLICT');
     if(response.status===429)return fail('RATE_LIMIT',true);
     if(response.status===408||response.status===504)return fail('TIMEOUT',true);
     return response.status>=500?fail('UNAVAILABLE',true):fail('REJECTED');
    }
    let data:unknown;try{data=await response.json();}catch{return fail('MALFORMED_RESPONSE');}
    if(JSON.stringify(data)?.includes(apiKey))return fail('MALFORMED_RESPONSE');
    return {success:true,data};
   };
   return await Promise.race([work(),new Promise<LiveClassroomResult<never>>(resolve=>{timer=setTimeout(()=>{controller.abort();resolve(fail('TIMEOUT',true));},timeoutMs);})]);
  }catch(error){return controller.signal.aborted?fail('TIMEOUT',true):error instanceof TypeError?fail('NETWORK',true):fail('UNKNOWN');}
  finally{if(timer)clearTimeout(timer);}
  });
 }
 #room(data:unknown,expected:string):LiveClassroomResult<ProviderRoom>{
  const parsed=roomSchema.safeParse(data);if(!parsed.success||parsed.data.name!==expected)return fail('MALFORMED_RESPONSE');
  try{
   const url=new URL(parsed.data.url);
   if(url.protocol!=='https:'||!url.hostname.endsWith('.daily.co')||url.username||url.password||url.port||url.search||url.hash||url.pathname!=='/'+expected)return fail('MALFORMED_RESPONSE');
   if(parsed.data.config?.exp!==undefined&&parsed.data.config.exp<=Math.floor(Date.now()/1000))return fail('REJECTED');
   return {success:true,data:{providerRoomRef:expected,url:url.href}};
  }catch{return fail('MALFORMED_RESPONSE');}
 }
 async getOrCreateRoom(context:RoomContext):Promise<LiveClassroomResult<ProviderRoom>>{
  const parsed=roomContextSchema.safeParse(context);if(!parsed.success)return fail('INVALID_INPUT');
  const name=parsed.data.roomKey,path='rooms/'+encodeURIComponent(name);
  const existing=await this.#request(path);
  if(existing.success)return this.#room(existing.data,name);
  if(existing.error.code!=='NOT_FOUND')return existing;
  const created=await this.#request('rooms',{name,privacy:'private'});
  if(created.success)return this.#room(created.data,name);
  if(created.error.code==='CONFLICT'){
   const concurrent=await this.#request(path);return concurrent.success?this.#room(concurrent.data,name):concurrent;
  }
  return created;
 }
 async createJoinToken(context:JoinContext):Promise<LiveClassroomResult<{token:string;expiresAt:number}>>{
  const parsed=joinContextSchema.safeParse(context);if(!parsed.success||parsed.data.expiresAt<=Math.floor(Date.now()/1000))return fail('INVALID_INPUT');
  const {providerRoomRef,userId,displayName,expiresAt}=parsed.data;
  // Expiry ends an existing meeting capability as well as blocking rejoin.
  const response=await this.#request('meeting-tokens',{properties:{room_name:providerRoomRef,user_id:userId,...(displayName===undefined?{}:{user_name:displayName}),exp:expiresAt,eject_at_token_exp:true,is_owner:false}});
  if(!response.success)return response;
  const token=z.object({token:z.string().min(1).max(16384).regex(/^[A-Za-z0-9_.-]+$/)}).safeParse(response.data);
  return token.success?{success:true,data:{token:token.data.token,expiresAt}}:fail('MALFORMED_RESPONSE');
 }
 async getRoomStatus(providerRoomRef:string):Promise<LiveClassroomResult<{status:'available'|'missing'|'expired';url?:string}>>{
  if(!providerRoomRefSchema.safeParse(providerRoomRef).success)return fail('INVALID_INPUT');
  const response=await this.#request('rooms/'+encodeURIComponent(providerRoomRef));
  if(!response.success)return response.error.code==='NOT_FOUND'?{success:true,data:{status:'missing'}}:response;
  const room=roomSchema.safeParse(response.data);if(!room.success)return fail('MALFORMED_RESPONSE');
  if(room.data.name!==providerRoomRef)return fail('MALFORMED_RESPONSE');
  if(room.data.config?.exp!==undefined&&room.data.config.exp<=Math.floor(Date.now()/1000))return {success:true,data:{status:'expired'}};
  const validated=this.#room(response.data,providerRoomRef);return validated.success?{success:true,data:{status:'available',url:validated.data.url}}:validated;
 }
}




