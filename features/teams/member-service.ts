import {scheduleCommittedNotificationEmails} from '@/features/notifications/email-delivery';
import "server-only";
import {z} from "zod";
import {createServerSupabaseClient} from "@/lib/db/server";
import {AuthorizationError,defineScopedRolePolicy,getAuthorizationContext,requireAdminScope,requireScopedRole} from "@/lib/auth/authorization";
import {addTeamMemberSchema,addedTeamMemberSchema} from "./add-member-schema";
import {removeTeamMemberSchema,removedTeamMemberSchema} from "./remove-member-schema";
import {moveTeamMemberSchema,movedTeamMemberSchema} from "./move-member-schema";
import {archiveTeamIdSchema,archivedTeamSchema} from "./archive-schema";
import {assignTeamLeadSchema,assignedTeamLeadSchema} from "./assign-lead-schema";
const teamSchema=z.object({id:z.uuid(),cohort_id:z.uuid()});
async function team(id:string){
 const db=await createServerSupabaseClient();const r=await db.from("teams").select("id,cohort_id").eq("id",id).maybeSingle();
 const row=teamSchema.safeParse(r.data);return r.error||!row.success||row.data.id!==id?null:row.data;
}
const cohortMasterPolicy=defineScopedRolePolicy({role:"MASTER",scopeType:"cohort",access:"educational"},async id=>{
 const row=await team(id);return row?{id,scope:{type:"cohort",id:row.cohort_id},access:"educational",resourcePolicyAllows:true}:null;
});
const teamMasterPolicy=defineScopedRolePolicy({role:"MASTER",scopeType:"team",access:"educational"},async id=>{
 const row=await team(id);return row?{id,scope:{type:"team",id},access:"educational",resourcePolicyAllows:true}:null;
});
const adminPolicy=defineScopedRolePolicy({role:"ADMIN",scopeType:"organization",access:"operational"},async id=>{
 const row=await team(id);if(!row)return null;
 const db=await createServerSupabaseClient();const c=await db.from("cohorts").select("id,program_id").eq("id",row.cohort_id).maybeSingle();
 const cohort=z.object({id:z.uuid(),program_id:z.uuid()}).safeParse(c.data);if(c.error||!cohort.success||cohort.data.id!==row.cohort_id)return null;
 const p=await db.from("programs").select("id,organization_id").eq("id",cohort.data.program_id).maybeSingle();
 const program=z.object({id:z.uuid(),organization_id:z.uuid()}).safeParse(p.data);
 return p.error||!program.success||program.data.id!==cohort.data.program_id?null:{id,scope:{type:"organization",id:program.data.organization_id},access:"operational",resourcePolicyAllows:true};
});
async function authorizeMembershipMutation(teamId:string){
  try{await requireScopedRole(cohortMasterPolicy,teamId);}catch(error){
   if(!(error instanceof AuthorizationError)||error.code!=="FORBIDDEN")throw error;
   try{await requireScopedRole(teamMasterPolicy,teamId);}catch(teamError){
    if(!(teamError instanceof AuthorizationError)||teamError.code!=="FORBIDDEN")throw teamError;
    await requireAdminScope(adminPolicy,teamId);
   }
  }
 }
/** One verified actor, one scope-checked transaction; caller userId is target only. */
export async function addTeamMember(input:unknown){
 try{
  const before=await getAuthorizationContext();
  if(!before.assignments.some(a=>a.roleCode==="ADMIN"||a.roleCode==="MASTER"))throw new AuthorizationError("FORBIDDEN");
  const parsed=addTeamMemberSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;
  await authorizeMembershipMutation(v.teamId);
  const db=await createServerSupabaseClient();const {data,error}=await db.rpc("add_team_member",{target_team:v.teamId,target_user:v.userId,kind:v.membershipRole});
  if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","23505","23502","22P02"].includes(error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
  const result=addedTeamMemberSchema.safeParse(data);const after=await getAuthorizationContext();
  if(!result.success||result.data.teamId!==v.teamId||after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  await scheduleCommittedNotificationEmails({membershipId:result.data.membershipId,membershipType:'MEMBER_ADDED'});
  return result.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");}
}

/** Active membership and Chat revocation commit together; history is retained. */
export async function removeTeamMember(input:unknown){
 try{
  const before=await getAuthorizationContext();
  if(!before.assignments.some(a=>a.roleCode==="ADMIN"||a.roleCode==="MASTER"))throw new AuthorizationError("FORBIDDEN");
  const parsed=removeTeamMemberSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;await authorizeMembershipMutation(v.teamId);
  const db=await createServerSupabaseClient();const {data,error}=await db.rpc("remove_team_member",{target_team:v.teamId,target_user:v.userId,removal_reason:v.reason??null});
  if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","23505","23502","22P02"].includes(error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
  const result=removedTeamMemberSchema.safeParse(data);const after=await getAuthorizationContext();
  if(!result.success||result.data.teamId!==v.teamId||after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  await scheduleCommittedNotificationEmails({membershipId:result.data.membershipId,membershipType:'MEMBER_REMOVED'});
  return result.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");}
}

async function authorizeMasterTeam(teamId:string){
 try{await requireScopedRole(cohortMasterPolicy,teamId);}catch(error){
  if(!(error instanceof AuthorizationError)||error.code!=="FORBIDDEN")throw error;
  await requireScopedRole(teamMasterPolicy,teamId);
 }
}
/** Both scopes must be authorized through Master, or both through Admin. */
export async function moveTeamMember(input:unknown){
 try{
  const before=await getAuthorizationContext();
  if(!before.assignments.some(a=>a.roleCode==="ADMIN"||a.roleCode==="MASTER"))throw new AuthorizationError("FORBIDDEN");
  const parsed=moveTeamMemberSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;
  try{await authorizeMasterTeam(v.fromTeamId);await authorizeMasterTeam(v.toTeamId);}catch(error){
   if(!(error instanceof AuthorizationError)||error.code!=="FORBIDDEN")throw error;
   await requireAdminScope(adminPolicy,v.fromTeamId);await requireAdminScope(adminPolicy,v.toTeamId);
  }
  const db=await createServerSupabaseClient();const {data,error}=await db.rpc("move_team_member",{target_user:v.userId,source_team:v.fromTeamId,destination_team:v.toTeamId,move_reason:v.reason??null});
  if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","23505","23502","22P02"].includes(error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
  const result=movedTeamMemberSchema.safeParse(data);const after=await getAuthorizationContext();
  if(!result.success||result.data.fromTeamId!==v.fromTeamId||result.data.toTeamId!==v.toTeamId||result.data.sourceMembershipId===result.data.targetMembershipId||after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  await scheduleCommittedNotificationEmails({membershipId:result.data.targetMembershipId,membershipType:'MEMBER_MOVED'});
  return result.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");}
}

/** Synchronize an existing active membership; Lead never becomes platform authority. */
export async function assignTeamLead(input:unknown){
 try{
  const before=await getAuthorizationContext();
  if(!before.assignments.some(a=>a.roleCode==="ADMIN"||a.roleCode==="MASTER"))throw new AuthorizationError("FORBIDDEN");
  const parsed=assignTeamLeadSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;await authorizeMembershipMutation(v.teamId);
  const db=await createServerSupabaseClient();const {data,error}=await db.rpc("assign_team_lead",{target_team:v.teamId,target_user:v.userId});
  if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","23505","23502","22P02"].includes(error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
  const result=assignedTeamLeadSchema.safeParse(data);const after=await getAuthorizationContext();
  if(!result.success||result.data.teamId!==v.teamId||result.data.userId!==v.userId||after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  return result.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");}
}

/** Archive through the same authoritative scoped authorization and one transaction. */
export async function archiveTeam(teamId:unknown){
 try{
  const before=await getAuthorizationContext();
  if(!before.assignments.some(a=>a.roleCode==="ADMIN"||a.roleCode==="MASTER"))throw new AuthorizationError("FORBIDDEN");
  const parsed=archiveTeamIdSchema.safeParse(teamId);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  await authorizeMembershipMutation(parsed.data);
  const db=await createServerSupabaseClient();const {data,error}=await db.rpc("archive_team",{target_team:parsed.data});
  if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","23505","23502","22P02"].includes(error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
  const result=archivedTeamSchema.safeParse(data);const after=await getAuthorizationContext();
  if(!result.success||result.data.teamId!==parsed.data||after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
  return result.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==="AUTH_REQUIRED"||error.code==="VALIDATION_ERROR")?error.code:"FORBIDDEN");}
}
