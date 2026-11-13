import "server-only";
import {notifySubmissionReceived} from "@/features/notifications/submission";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {submissionSchema,submitArtifactSchema} from "./submission-schema";
/** Caller-bound database transaction is authoritative for Team Lead and reviewer. */
export async function submitArtifact(input:unknown){try{
 const actor=await getAuthorizationContext();const v=submitArtifactSchema.safeParse(input);if(!v.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const result=await db.rpc("submit_artifact",{target_artifact:v.data.artifactId,target_version:v.data.artifactVersionId,target_activity:v.data.activityInstanceId});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":result.error.code==="23505"?"VALIDATION_ERROR":"FORBIDDEN");
 const s=submissionSchema.safeParse(result.data);if(!s.success||s.data.status!=="SUBMITTED"||s.data.artifact_id!==v.data.artifactId||s.data.artifact_version_id!==v.data.artifactVersionId||s.data.activity_instance_id!==v.data.activityInstanceId||s.data.submitted_by!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 // Canonical transaction has committed; notification is never review authority.
 await notifySubmissionReceived(s.data.id);
 return s.data;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");}}
