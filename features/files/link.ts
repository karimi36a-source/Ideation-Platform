import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {fileLinkSchema,type FileLink} from "./schema";
import {linkFileSchema} from "./link-schema";
/** Identity-bound graph mutation; never signs, returns or transfers File access. */
export async function linkFile(input:unknown):Promise<FileLink>{try{
 const actor=await getAuthorizationContext();const parsed=linkFileSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const result=await db.rpc("link_file",{input:parsed.data});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":["22023","22P02"].includes(result.error.code??"")?"VALIDATION_ERROR":"NOT_FOUND");
 const row=fileLinkSchema.safeParse(result.data);const v=parsed.data;
 if(!row.success||row.data.archived_at!==null||row.data.file_id.toLowerCase()!==v.fileId.toLowerCase()||row.data.entity_id.toLowerCase()!==v.entityId.toLowerCase()||row.data.entity_type!==v.entityType||row.data.relationship_type!==v.relationshipType)throw new AuthorizationError("NOT_FOUND");
 return row.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
