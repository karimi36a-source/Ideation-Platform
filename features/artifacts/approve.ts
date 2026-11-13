import "server-only";
import {notifyArtifactApproved} from "@/features/notifications/approval";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {submissionSchema} from "./submission-schema";
const inputSchema=z.strictObject({submissionId:z.uuid(),approvalNote:z.string().trim().min(1).optional()});
export async function approveArtifact(input:unknown){try{
 const actor=await getAuthorizationContext();const v=inputSchema.safeParse(input);if(!v.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const result=await db.rpc("approve_artifact",{target_submission:v.data.submissionId,approval_note_input:v.data.approvalNote??null});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":["22023","23505"].includes(result.error.code)?"VALIDATION_ERROR":"FORBIDDEN");
 const s=submissionSchema.safeParse(result.data);if(!s.success||s.data.id!==v.data.submissionId||s.data.reviewer_user_id!==actor.userId||s.data.submitted_by===actor.userId||s.data.status!=="APPROVED")throw new AuthorizationError("FORBIDDEN");await notifyArtifactApproved(s.data.id);return s.data;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");}}
