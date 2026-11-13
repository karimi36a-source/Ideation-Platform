import "server-only";
import {notifyCommentReceived} from "@/features/notifications/comment";
import {notifyRevisionRequested} from "@/features/notifications/revision";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {submissionSchema} from "./submission-schema";
import {addFeedbackSchema,feedbackSchema,requestRevisionSchema} from "./review-schema";
const safe=(error:unknown)=>new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");
const rpcError=(code:string)=>new AuthorizationError(code==="28000"?"AUTH_REQUIRED":code==="22023"||code==="23505"?"VALIDATION_ERROR":"FORBIDDEN");
export async function requestRevision(input:unknown){try{
 const actor=await getAuthorizationContext();const v=requestRevisionSchema.safeParse(input);if(!v.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const result=await db.rpc("request_revision",{target_submission:v.data.submissionId,revision_note:v.data.note});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");if(result.error)throw rpcError(result.error.code);
 const s=submissionSchema.safeParse(result.data);if(!s.success||s.data.id!==v.data.submissionId||s.data.reviewer_user_id!==actor.userId||s.data.status!=="REVISION_REQUESTED")throw new AuthorizationError("FORBIDDEN");
 await notifyRevisionRequested(s.data.id);
 return s.data;
}catch(error){throw safe(error);}}
export async function startReview(submissionId:unknown){try{
 const actor=await getAuthorizationContext();const id=z.uuid().safeParse(submissionId);if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const result=await db.rpc("start_review",{target_submission:id.data});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");if(result.error)throw rpcError(result.error.code);
 const s=submissionSchema.safeParse(result.data);if(!s.success||s.data.id!==id.data||s.data.reviewer_user_id!==actor.userId||s.data.status!=="UNDER_REVIEW")throw new AuthorizationError("FORBIDDEN");return s.data;
}catch(error){throw safe(error);}}
export async function addFeedback(input:unknown){try{
 const actor=await getAuthorizationContext();const v=addFeedbackSchema.safeParse(input);if(!v.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const result=await db.rpc("add_feedback",{target_kind:v.data.targetEntityType,target_entity:v.data.targetEntityId,target_version:v.data.targetVersionId??null,kind:v.data.feedbackType,body:v.data.content});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");if(result.error)throw rpcError(result.error.code);
 const f=feedbackSchema.safeParse(result.data);if(!f.success||f.data.author_user_id!==actor.userId||f.data.target_entity_type!==v.data.targetEntityType||f.data.target_entity_id!==v.data.targetEntityId||f.data.target_version_id!==(v.data.targetVersionId??null)||f.data.feedback_type!==v.data.feedbackType||f.data.content!==v.data.content||f.data.status!=="OPEN"||f.data.resolved_at!==null)throw new AuthorizationError("FORBIDDEN");await notifyCommentReceived(f.data.id);return f.data;
}catch(error){throw safe(error);}}
