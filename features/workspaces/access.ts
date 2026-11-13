import "server-only";
import {z} from "zod";
import {getAuthorizationContext,AuthorizationError,type AuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {workspaceSchema,type Workspace} from "./schema";
export type WorkspaceAccess=Readonly<{
 canView:boolean;canCreate:boolean;canEdit:boolean;canComment:boolean;canShare:boolean;
 canReview:boolean;canApprove:boolean;canManageMembers:boolean;canAccessChat:boolean;
}>;
async function resolve(w:Workspace,c:AuthorizationContext){
 if(w.status!=="active"||w.visibility!=="private")throw new AuthorizationError("FORBIDDEN");
 let canEdit=true;let canAccessChat=false;
 if(w.workspace_type==="TEAM"){
  if(w.team_id===null||w.cohort_id===null)throw new AuthorizationError("FORBIDDEN");
  const db=await createServerSupabaseClient();const r=await db.rpc("get_team_workspace_access",{target_workspace:w.id});
  const role=z.enum(["member","team_lead","mentor"]).safeParse(r.data);
  if(r.error||!role.success)throw new AuthorizationError("FORBIDDEN");
  canEdit=role.data!=="mentor";
  const chat=await db.rpc("team_workspace_has_chat_access",{target_workspace:w.id});
  if(chat.error||typeof chat.data!=="boolean")throw new AuthorizationError("FORBIDDEN");
  canAccessChat=chat.data;
 }else{
  if(w.owner_user_id!==c.userId)throw new AuthorizationError("FORBIDDEN");
  switch(w.workspace_type){
   case "PERSONAL":break;
   case "MASTER":case "CASE_STUDY":
    if(w.cohort_id===null||!c.assignments.some(a=>a.roleCode==="MASTER"&&a.cohort_id===w.cohort_id))throw new AuthorizationError("FORBIDDEN");break;
   case "SHARED":throw new AuthorizationError("FORBIDDEN");
  }
 }
 return Object.freeze({canView:true,canCreate:canEdit,canEdit,canComment:false,canShare:false,canReview:false,canApprove:false,canManageMembers:false,canAccessChat});
}
/** Returns capabilities only, never resource metadata. Reuse for future operations. */
export async function getWorkspaceAccess(workspaceId:unknown):Promise<WorkspaceAccess>{
 const id=z.uuid().safeParse(workspaceId);if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");
 try{
  const before=await getAuthorizationContext();const client=await createServerSupabaseClient();
  const load=async()=>{const r=await client.from("workspaces").select("*").eq("id",id.data).maybeSingle();const w=workspaceSchema.safeParse(r.data);if(r.error||!w.success||w.data.id!==id.data)throw new AuthorizationError("FORBIDDEN");return w.data;};
  await resolve(await load(),before);
  const current=await getAuthorizationContext();
  // Re-read through RLS after refreshed identity/scope, rather than reusing a stale row.
  if(current.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  return await resolve(await load(),current);
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&error.code==="AUTH_REQUIRED"?"AUTH_REQUIRED":"FORBIDDEN");}
}
