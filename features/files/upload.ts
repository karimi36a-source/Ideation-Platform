import "server-only";
import {createClient} from "@supabase/supabase-js";
import {getServerEnv} from "@/lib/validation/env-server";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {fileSchema,PRIVATE_FILE_BUCKET} from "./schema";
import {requestUploadSchema,registerUploadedFileSchema,uploadRequestSchema,MAX_UPLOAD_BYTES} from "./upload-schema";
import {enforceFileUploadRateLimit,FileUploadRateLimitError} from './upload-rate-limit';
/** Elevated provider client only signs an authorized exact path. */
function signingClient(){
 const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw new AuthorizationError("NOT_FOUND");
 return createClient(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:"error"})}});
}
function safeError(error:unknown):never{if(error instanceof FileUploadRateLimitError)throw error;throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
export async function requestUpload(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=requestUploadSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 await enforceFileUploadRateLimit(actor.userId);
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 const v=parsed.data;const db=await createServerSupabaseClient();
 const result=await db.rpc("request_file_upload",{target_workspace:v.workspaceId,target_project:v.projectId??null,upload_filename:v.filename,upload_mime:v.mimeType,upload_size:v.size});
 if(result.error)throw new AuthorizationError(["22023","23514"].includes(result.error.code??"")?"VALIDATION_ERROR":"NOT_FOUND");
 const r=uploadRequestSchema.safeParse(result.data);
 if(!r.success||r.data.requested_by!==actor.userId||r.data.workspace_id!==v.workspaceId||r.data.project_id!==(v.projectId??null)||r.data.filename!==v.filename||r.data.mime_type!==v.mimeType||r.data.expected_size!==v.size||r.data.registered_at!==null||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 // Bearer capability: never log/persist it. Upsert must remain false.
 const provider=signingClient();const bucket=await provider.storage.getBucket(PRIVATE_FILE_BUCKET);
 if(bucket.error||bucket.data.public!==false||(bucket.data.file_size_limit!==null&&Number(bucket.data.file_size_limit)<MAX_UPLOAD_BYTES))throw new AuthorizationError("NOT_FOUND");
 const target=await provider.storage.from(PRIVATE_FILE_BUCKET).createSignedUploadUrl(r.data.storage_reference,{upsert:false});
 if(target.error||!target.data||target.data.path!==r.data.storage_reference)throw new AuthorizationError("NOT_FOUND");
 const current=await db.rpc("get_file_upload_request",{target_request:r.data.id});
 if(current.error||!uploadRequestSchema.safeParse(current.data).success||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 return {uploadRequestId:r.data.id,path:r.data.storage_reference,token:target.data.token,signedUrl:target.data.signedUrl,expiresAt:r.data.expires_at};
 }catch(error){safeError(error);}}
export async function registerUploadedFile(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=registerUploadedFileSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const result=await db.rpc("register_uploaded_file",{target_request:parsed.data.uploadRequestId});
 if(result.error)throw new AuthorizationError(result.error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");
 const f=fileSchema.safeParse(result.data);if(!f.success||f.data.uploaded_by!==actor.userId||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 return f.data;
 }catch(error){safeError(error);}}
