import "server-only";
import {z} from "zod";
import {createServerSupabaseClient} from "@/lib/db/server";
import {AuthorizationError,defineScopedRolePolicy,getAuthorizationContext,requireAdminScope,requireScopedRole} from "@/lib/auth/authorization";
import {createTeamSchema,createdTeamSchema} from "./create-schema";

export class TeamDependencyError extends Error {
 readonly code="DEPENDENCY_NOT_MET";
 constructor(){super("Required Team creation dependency is unavailable.");this.name="TeamDependencyError";}
}
const cohortRow=z.object({id:z.uuid(),program_id:z.uuid()});
async function cohort(id:string){
 const client=await createServerSupabaseClient();const result=await client.from("cohorts").select("id,program_id").eq("id",id).maybeSingle();
 const row=cohortRow.safeParse(result.data);return result.error||!row.success||row.data.id!==id?null:row.data;
}
const masterPolicy=defineScopedRolePolicy({role:"MASTER",scopeType:"cohort",access:"educational"},async id=>{
 const row=await cohort(id);return row?{id,scope:{type:"cohort",id},access:"educational",resourcePolicyAllows:true}:null;
});
const adminPolicy=defineScopedRolePolicy({role:"ADMIN",scopeType:"organization",access:"operational"},async id=>{
 const row=await cohort(id);if(!row)return null;
 const client=await createServerSupabaseClient();const result=await client.from("programs").select("id,organization_id").eq("id",row.program_id).maybeSingle();
 const program=z.object({id:z.uuid(),organization_id:z.uuid()}).safeParse(result.data);
 return result.error||!program.success||program.data.id!==row.program_id?null:{id,scope:{type:"organization",id:program.data.organization_id},access:"operational",resourcePolicyAllows:true};
});
/** One identity-bound RPC commits all required resources, or none. */
export async function createTeam(input:unknown){
 try{
  const before=await getAuthorizationContext();
  if(!before.assignments.some(a=>a.roleCode==="ADMIN"||a.roleCode==="MASTER"))throw new AuthorizationError("FORBIDDEN");
  const parsed=createTeamSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;
  try{await requireScopedRole(masterPolicy,v.cohortId);}catch(error){
   if(!(error instanceof AuthorizationError)||error.code!=="FORBIDDEN")throw error;
   await requireAdminScope(adminPolicy,v.cohortId);
  }
  if(v.projectId!==undefined)throw new TeamDependencyError();
  const client=await createServerSupabaseClient();const {data,error}=await client.rpc("create_team",{
   target_cohort:v.cohortId,team_name:v.name,team_description:v.description??null,lead_user:v.teamLeadUserId??null,target_project:null,
  });
  if(error){
   if(error.code==="0A000")throw new TeamDependencyError();
   throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","23505","23502","22P02"].includes(error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
  }
  const result=createdTeamSchema.safeParse(data);if(!result.success)throw new AuthorizationError("FORBIDDEN");
  const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  return result.data;
 }catch(error){
  if(error instanceof TeamDependencyError)throw new TeamDependencyError();
  throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");
 }
}
