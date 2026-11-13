import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {artifactVersionSchema} from "./version-schema";
const inputSchema=z.strictObject({submissionId:z.uuid(),contentSnapshot:z.json(),changeSummary:z.string().nullable()});
/** Current edit authority is revalidated atomically by the caller-bound RPC. */
export async function createRevisionDraft(input:unknown){try{
 const actor=await getAuthorizationContext();const v=inputSchema.safeParse(input);if(!v.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const result=await db.rpc("create_revision_draft",{target_submission:v.data.submissionId,snapshot:v.data.contentSnapshot,summary:v.data.changeSummary});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":["22023","23505"].includes(result.error.code)?"VALIDATION_ERROR":"FORBIDDEN");
 const row=artifactVersionSchema.safeParse(result.data);
 if(!row.success||row.data.created_by!==actor.userId||row.data.status!=="DRAFT"||row.data.previous_version_id===null||row.data.version_label!==null||row.data.approved_by!==null||row.data.approved_at!==null||row.data.approval_note!==null)throw new AuthorizationError("FORBIDDEN");
 return row.data;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");}}
