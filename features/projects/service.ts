import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {createDevelopmentProjectSchema} from "./create-schema";
import {developmentProjectSchema} from "./schema";
/** Server-only entry point. The identity-bound database transaction revalidates
 * every scope; caller role or owner claims never establish authority. */
export async function createDevelopmentProject(input:unknown){
 try{
  const before=await getAuthorizationContext();
  const parsed=createDevelopmentProjectSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  if(v.projectType==="team"){
   if(!before.assignments.some(a=>a.roleCode==="ADMIN"||a.roleCode==="MASTER"))throw new AuthorizationError("FORBIDDEN");
   const authority=await db.rpc("can_manage_team",{target_team:v.ownerTeamId});
   if(authority.error||authority.data!==true)throw new AuthorizationError("FORBIDDEN");
  }else{
   if(v.ownerUserId!=null&&v.ownerUserId!==before.userId)throw new AuthorizationError("FORBIDDEN");
   const access=await getWorkspaceAccess(v.primaryWorkspaceId);if(!access.canCreate)throw new AuthorizationError("FORBIDDEN");
  }
  const latest=await getAuthorizationContext();if(latest.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  const result=await db.rpc("create_development_project",{project_name:v.name,kind:v.projectType,target_workspace:v.primaryWorkspaceId,
   project_description:v.description??null,target_owner_user:v.projectType==="team"?null:before.userId,target_owner_team:v.projectType==="team"?v.ownerTeamId:null});
  if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","22P02"].includes(result.error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
  const project=developmentProjectSchema.safeParse(result.data);const after=await getAuthorizationContext();
  if(!project.success||after.userId!==before.userId||project.data.project_type!==v.projectType||project.data.primary_workspace_id!==v.primaryWorkspaceId||project.data.status!=="active"||
   (v.projectType==="team"?project.data.owner_team_id!==v.ownerTeamId||project.data.owner_user_id!==null:project.data.owner_user_id!==before.userId||project.data.owner_team_id!==null))throw new AuthorizationError("FORBIDDEN");
  return project.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");}
}
