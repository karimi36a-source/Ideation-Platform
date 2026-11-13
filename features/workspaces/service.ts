import "server-only";
import {z} from "zod";
import {getWorkspaceAccess} from "./access";
import {requireActivePlatformUser} from "@/features/users/service";
import {createServerSupabaseClient} from "@/lib/db/server";
import {AuthorizationError,getAuthorizationContext,defineScopedRolePolicy,requireScopedRole} from "@/lib/auth/authorization";
import {workspaceSchema} from "./schema";
import {AuthenticationRequiredError} from "@/lib/auth/errors";
/** Explicit authenticated provisioning hook; no client ownership argument. */
async function provisionPersonalWorkspace(){
 const before=await requireActivePlatformUser();
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("create_personal_workspace");
 if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":"FORBIDDEN");
 const parsed=workspaceSchema.safeParse(data);const after=await requireActivePlatformUser();
 if(!parsed.success||before.id!==after.id||parsed.data.owner_user_id!==before.id||parsed.data.workspace_type!=="PERSONAL"||parsed.data.status!=="active"||parsed.data.visibility!=="private")throw new AuthorizationError("FORBIDDEN");
 return parsed.data;
}
export async function createPersonalWorkspace(){
 try{return await provisionPersonalWorkspace();}catch(error){
  if(error instanceof AuthenticationRequiredError)throw new AuthorizationError("AUTH_REQUIRED");
  throw safeRetrievalError(error);
 }
}

/** Metadata retrieval always passes the centralized resolver before and after reading. */
async function retrieveWorkspace(workspaceId:unknown){
 const access=await getWorkspaceAccess(workspaceId);if(!access.canView)throw new AuthorizationError("FORBIDDEN");
 const before=await getAuthorizationContext();const client=await createServerSupabaseClient();
 const r=await client.from("workspaces").select("*").eq("id",workspaceId as string).maybeSingle();
 const parsed=workspaceSchema.safeParse(r.data);
 if(r.error||!parsed.success||parsed.data.id!==workspaceId)throw new AuthorizationError("FORBIDDEN");
 if(!(await getWorkspaceAccess(workspaceId)).canView)throw new AuthorizationError("FORBIDDEN");
 const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
 return parsed.data;
}
/** RLS filters candidates; resolver-authorized fresh rows are the only returned data. */
async function retrieveMyWorkspaces(){
 const before=await getAuthorizationContext();const client=await createServerSupabaseClient();
 const r=await client.from("workspaces").select("id").order("created_at").order("id");
 const candidates=z.array(z.object({id:z.uuid()})).safeParse(r.data);
 if(r.error||!candidates.success)throw new AuthorizationError("FORBIDDEN");
 const rows=[];
 for(const candidate of candidates.data){
  try{rows.push(await getWorkspace(candidate.id));}
  catch(error){if(!(error instanceof AuthorizationError)||error.code!=="FORBIDDEN")throw error;}
 }
 const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
 return rows;
}

function safeRetrievalError(error:unknown){
 return new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");
}
export async function getWorkspace(workspaceId:unknown){
 try{return await retrieveWorkspace(workspaceId);}catch(error){throw safeRetrievalError(error);}
}
export async function listMyWorkspaces(){
 try{return await retrieveMyWorkspaces();}catch(error){throw safeRetrievalError(error);}
}

const masterCohortPolicy=defineScopedRolePolicy({role:"MASTER",scopeType:"cohort",access:"educational"},async id=>{
 const client=await createServerSupabaseClient();const r=await client.from("cohorts").select("id").eq("id",id).maybeSingle();
 const row=z.object({id:z.uuid()}).safeParse(r.data);
 return r.error||!row.success||row.data.id!==id?null:{id,scope:{type:"cohort",id},access:"educational",resourcePolicyAllows:true};
});
/** Current verified Master only; no target-owner argument or global scope. */
export async function createMasterWorkspace(cohortId:unknown){
 try{
  const gate=await requireScopedRole(masterCohortPolicy,cohortId);
  const client=await createServerSupabaseClient();const r=await client.rpc("create_master_workspace",{target_cohort:gate.resource.id});
  const row=workspaceSchema.safeParse(r.data);
  if(r.error||!row.success||row.data.workspace_type!=="MASTER"||row.data.owner_user_id!==gate.context.userId||row.data.cohort_id!==gate.resource.id||row.data.status!=="active"||row.data.visibility!=="private")throw new AuthorizationError("FORBIDDEN");
  if(!(await getWorkspaceAccess(row.data.id)).canView)throw new AuthorizationError("FORBIDDEN");
  const current=await getAuthorizationContext();if(current.userId!==gate.context.userId)throw new AuthorizationError("FORBIDDEN");
  return row.data;
 }catch(error){throw safeRetrievalError(error);}
}
