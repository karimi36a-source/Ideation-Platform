import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {artifactSchema,artifactTypeSchema} from "@/features/artifacts/schema";
import {artifactVersionSchema} from "@/features/artifacts/version-schema";

export const teamDecisionRecordSchema=z.strictObject({artifact:artifactSchema,version:artifactVersionSchema});
export type TeamDecisionRecord=z.infer<typeof teamDecisionRecordSchema>;
export const decisionArtifactSourceSchema=z.strictObject({artifact_id:z.uuid(),artifact_version_id:z.uuid(),decision_id:z.uuid(),activity_instance_id:z.uuid()});
/** Uses the existing execution snapshot nesting; no Definition reread or aliases. */
export function expectsTeamDecisionRecord(snapshot:unknown):boolean {
 const parsed=z.object({configuration:z.object({outputs:z.object({artifact_types:z.array(artifactTypeSchema)})}),requires_review:z.boolean(),requires_approval:z.boolean()}).safeParse(snapshot);
 return parsed.success&&parsed.data.configuration.outputs.artifact_types.includes("TEAM_DECISION_RECORD");
}
export class DecisionArtifactStateError extends Error {
 readonly code="INVALID_STATE";
 constructor(){super("Decision output is not applicable in the current state.");}
}
/** Public UUID-only composition contract. Ownership is never accepted as input. */
export async function createTeamDecisionRecordArtifact(decisionId:unknown):Promise<TeamDecisionRecord> {
 try {
  const actor=await getAuthorizationContext();
  const parsed=z.uuid().safeParse(decisionId);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const response=await db.rpc("create_team_decision_record_artifact",{target_decision:parsed.data});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(response.error){
   if(response.error.code==="55000")throw new DecisionArtifactStateError();
   throw new AuthorizationError(response.error.code==="28000"?"AUTH_REQUIRED":["22023","22P02"].includes(response.error.code)?"VALIDATION_ERROR":"NOT_FOUND");
  }
  const result=teamDecisionRecordSchema.safeParse(response.data);
  if(!result.success||result.data.artifact.artifact_type!=="TEAM_DECISION_RECORD"||result.data.version.artifact_id!==result.data.artifact.id||result.data.version.version_number!==1||!result.data.artifact.activity_instance_id)throw new AuthorizationError("NOT_FOUND");
  return result.data;
 }catch(error){
  if(error instanceof DecisionArtifactStateError)throw new DecisionArtifactStateError();
  throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
 }
}
