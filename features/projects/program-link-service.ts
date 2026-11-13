import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {linkProjectToProgramSchema,projectProgramLinkSchema} from "./program-link-schema";
export class ProjectArtifactDependencyError extends Error{readonly code="DEPENDENCY_NOT_MET";constructor(){super("Artifact Version validation is unavailable until M8.");this.name="ProjectArtifactDependencyError";}}
/** One narrow transaction preserves Project identity and previous participation. */
export async function linkProjectToProgram(input:unknown){
 try{
  const before=await getAuthorizationContext();const parsed=linkProjectToProgramSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  const access=await db.rpc("can_read_development_project",{target_project:v.projectId});if(access.error||access.data!==true)throw new AuthorizationError("FORBIDDEN");
  if(v.entryArtifactVersionId!=null)throw new ProjectArtifactDependencyError();
  const latest=await getAuthorizationContext();if(latest.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  const r=await db.rpc("link_project_to_program",{target_project:v.projectId,target_program:v.programId,target_cohort:v.cohortId,entry_version:null});
  if(r.error){if(r.error.code==="0A000")throw new ProjectArtifactDependencyError();throw new AuthorizationError(r.error.code==="28000"?"AUTH_REQUIRED":["22023","23505","23503","23514","22P02"].includes(r.error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");}
  const link=projectProgramLinkSchema.safeParse(r.data);const after=await getAuthorizationContext();
  if(!link.success||after.userId!==before.userId||link.data.project_id!==v.projectId||link.data.program_id!==v.programId||link.data.cohort_id!==v.cohortId||link.data.completed_at!==null||link.data.entry_artifact_version_id!==null||link.data.exit_artifact_version_id!==null)throw new AuthorizationError("FORBIDDEN");
  const current=await db.rpc("can_read_project_program_link",{target_link:link.data.id});if(current.error||current.data!==true)throw new AuthorizationError("FORBIDDEN");
  return link.data;
 }catch(error){if(error instanceof ProjectArtifactDependencyError)throw new ProjectArtifactDependencyError();throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");}
}
