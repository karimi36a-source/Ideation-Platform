import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {fileSchema,type FileRecord} from "./schema";
/** Logical, identity-bound archive. No provider client or deletion path. */
export async function archiveFile(fileId:unknown):Promise<FileRecord>{try{
 const actor=await getAuthorizationContext();const parsed=z.uuid().safeParse(fileId);
 if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const result=await db.rpc("archive_file",{target_file:parsed.data});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":result.error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");
 const row=fileSchema.safeParse(result.data);
 if(!row.success||row.data.id.toLowerCase()!==parsed.data.toLowerCase()||row.data.status!=="archived"||row.data.archived_at===null)throw new AuthorizationError("NOT_FOUND");
 return row.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
