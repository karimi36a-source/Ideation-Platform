import 'server-only';
import {createHmac} from 'node:crypto';
import {isIP} from 'node:net';
import {headers} from 'next/headers';
import {createClient} from '@supabase/supabase-js';
import {z} from 'zod';
import type {Database} from '@/lib/db/database.types';
import {getServerEnv} from '@/lib/validation/env-server';

export class FileUploadRateLimitError extends Error {
 readonly code='RATE_LIMIT';
 readonly status=429;
 readonly headers:Readonly<Record<string,string>>;
 constructor(readonly retryAfterSeconds:number){
  super('Too many upload requests. Try again later.');this.name='FileUploadRateLimitError';
  this.headers=Object.freeze({'Retry-After':String(retryAfterSeconds)});
 }
}
const positive=z.coerce.number().int().min(1).max(1_000_000);
const resultSchema=z.strictObject({allowed:z.boolean(),retryAfterSeconds:z.number().int().min(0).max(86400)})
 .refine(v=>v.allowed?v.retryAfterSeconds===0:v.retryAfterSeconds>=1);

/** Admission only, never authorization. Counters are shared across server instances.
 * Configure an IP header only when the ingress proxy strips/overwrites it with
 * one canonical client IP. Arbitrary forwarded headers are never trusted.
 */
export async function enforceFileUploadRateLimit(actorId:string):Promise<void>{
 const userLimit=positive.parse(process.env.FICI_UPLOAD_RATE_USER_LIMIT??60);
 const sourceLimit=positive.parse(process.env.FICI_UPLOAD_RATE_SOURCE_LIMIT??300);
 const windowSeconds=positive.max(86400).parse(process.env.FICI_UPLOAD_RATE_WINDOW_SECONDS??60);
 const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw Error('Upload admission unavailable');
 let sourceHash:string|null=null;
 const configuredHeader=process.env.FICI_UPLOAD_RATE_IP_HEADER;
 if(configuredHeader!==undefined){
  const name=z.string().regex(/^[a-z][a-z0-9-]{0,63}$/).parse(configuredHeader);
  const source=(await headers()).get(name)?.trim();
  if(!source||!isIP(source))throw Error('Upload admission unavailable');
  const canonical=isIP(source)===6?new URL(`http://[${source}]/`).hostname.toLowerCase():source;
  sourceHash=createHmac('sha256',env.SUPABASE_SECRET_KEY).update('file-upload-source-v1\0'+canonical).digest('hex');
 }
 const db=createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:'error',cache:'no-store'})}});
 const result=await db.rpc('consume_file_upload_rate_limit',{target_actor:actorId,target_source_hash:sourceHash,user_limit:userLimit,source_limit:sourceLimit,window_seconds:windowSeconds});
 if(result.error)throw Error('Upload admission unavailable');
 const decision=resultSchema.parse(result.data);
 if(!decision.allowed)throw new FileUploadRateLimitError(decision.retryAfterSeconds);
}
