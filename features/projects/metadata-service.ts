import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {updateProjectMetadataSchema} from "./metadata-schema";
import {developmentProjectSchema} from "./schema";
export async function updateProjectMetadata(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=updateProjectMetadataSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");const v=parsed.data;
 const db=await createServerSupabaseClient();const loaded=await db.rpc("get_development_project_metadata_for_edit",{target_project:v.projectId});const before=developmentProjectSchema.safeParse(loaded.data);
 if(loaded.error||!before.success||before.data.id!==v.projectId)throw new AuthorizationError("FORBIDDEN");const p=before.data;
 if(p.archived_at!==null||!["active","paused"].includes(p.status))throw new AuthorizationError("FORBIDDEN");
 const access=await getWorkspaceAccess(p.primary_workspace_id);if(!access.canEdit)throw new AuthorizationError("FORBIDDEN");
 const changes: {name?:string;description?:string|null;status?:"active"|"paused"|"completed";current_stage?:string|null}={};
 if(v.name!==undefined)changes.name=v.name;if(v.description!==undefined)changes.description=v.description;if(v.status!==undefined)changes.status=v.status;if(v.currentStage!==undefined)changes.current_stage=v.currentStage;
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const r=await db.rpc("update_project_metadata",{target_project:p.id,changes});if(r.error)throw new AuthorizationError(r.error.code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","22P02"].includes(r.error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
 const after=developmentProjectSchema.safeParse(r.data);
 if(!after.success||(await getAuthorizationContext()).userId!==actor.userId||["id","owner_user_id","owner_team_id","primary_workspace_id","project_type","created_at","archived_at","confidentiality_level","required_workspace_type"].some(key=>after.data[key as keyof typeof after.data]!==p[key as keyof typeof p]))throw new AuthorizationError("FORBIDDEN");
 return after.data;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");}}
