import "server-only";
import {createClient,type SupabaseClient} from "@supabase/supabase-js";
import type {Database} from "@/lib/db/database.types";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getServerEnv} from "@/lib/validation/env-server";
import {fileSchema,PRIVATE_FILE_BUCKET} from "./schema";
import {fileAccessLifetime,getFileAccessSchema} from "./access-schema";
/** Temporary bearer capability only. Never log, cache or persist the result. */
export async function getFileAccess(input:unknown):Promise<{signedUrl:string;expiresAt:string;expiresIn:number}>{try{
 const actor=await getAuthorizationContext();const parsed=getFileAccessSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();
 let provider:SupabaseClient<Database>|undefined;
 const signingProvider=()=>{
  if(provider)return provider;
  const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw new AuthorizationError("NOT_FOUND");
  provider=createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:"error",cache:"no-store"})}});
  return provider;
 };
 const resolve=async()=>{
  // User-scoped SELECT invokes existing File lifecycle, Workspace, Project and Team RLS.
  const result=await db.from("files").select("*").eq("id",parsed.data.fileId).maybeSingle();
  let data=result.data;
  if(result.error||!data){
   // A non-FILE Share never authorizes this fallback. RPC exposes boolean only;
   // privileged canonical lookup stays inside this server-only signing service.
   const access=await db.rpc("authorize_shared_file_access",{target_file:parsed.data.fileId});
   if(access.error||access.data!==true)throw new AuthorizationError("NOT_FOUND");
   const canonical=await signingProvider().rpc("get_file_signing_record",{target_file:parsed.data.fileId});
   if(canonical.error)throw new AuthorizationError("NOT_FOUND");
   data=canonical.data;
  }
  const row=fileSchema.safeParse(data);
  if(!row.success||row.data.id.toLowerCase()!==parsed.data.fileId.toLowerCase()||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  return row.data;
 };
 const file=await resolve();const expiresIn=fileAccessLifetime(process.env.FICI_FILE_ACCESS_TTL_SECONDS);
 const signer=signingProvider();const env=getServerEnv();
 const bucket=await signer.storage.getBucket(PRIVATE_FILE_BUCKET);
 if(bucket.error||bucket.data.public!==false)throw new AuthorizationError("NOT_FOUND");
 // Conservative expiry metadata starts before signing, never extending provider lifetime.
 const issuedAt=Date.now();
 const result=await signer.storage.from(PRIVATE_FILE_BUCKET).createSignedUrl(file.storage_reference,expiresIn);
 if(result.error||!result.data?.signedUrl)throw new AuthorizationError("NOT_FOUND");
 const url=new URL(result.data.signedUrl);
 if(url.origin!==new URL(env.NEXT_PUBLIC_SUPABASE_URL).origin||url.pathname!==`/storage/v1/object/sign/${PRIVATE_FILE_BUCKET}/${file.storage_reference}`||!url.searchParams.get("token"))throw new AuthorizationError("NOT_FOUND");
 // Recheck current RLS after the provider call; do not return a capability after observed revocation.
 const current=await resolve();
 if(current.storage_reference!==file.storage_reference||Date.now()>=issuedAt+expiresIn*1000)throw new AuthorizationError("NOT_FOUND");
 return {signedUrl:result.data.signedUrl,expiresAt:new Date(issuedAt+expiresIn*1000).toISOString(),expiresIn};
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}

